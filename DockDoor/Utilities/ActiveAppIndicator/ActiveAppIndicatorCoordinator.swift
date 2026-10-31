import Cocoa
import Defaults
import QuartzCore
import SwiftUI

/// Manages the active app indicator that shows a line next to the currently active app in the dock.
/// Supports bottom, left, and right dock positions.
final class ActiveAppIndicatorCoordinator {
    private struct TrackedDot {
        let pid: pid_t
        let element: AXUIElement
        var frame: CGRect
        let hasWindows: Bool
        let isFrontmost: Bool
    }

    static var shared: ActiveAppIndicatorCoordinator?

    private var indicatorWindow: ActiveAppIndicatorWindow?
    private var workspaceObserver: NSObjectProtocol?
    private var positionSettingsObserver: Defaults.Observation?
    private var screenParametersObserver: NSObjectProtocol?

    private var dockLayoutObserver: AXObserver?
    private var observedDockList: AXUIElement?
    private var lastDockListFrame: CGRect?

    private var hiddenDockMouseMonitor: Any?
    private var dockListCheckPending = false
    private var dockHidesInCurrentSpace = false

    private var currentActiveApp: NSRunningApplication?
    private var trackedDots: [TrackedDot] = []

    @available(macOS 14.0, *)
    private final class DisplayLinkTarget: NSObject {
        weak var coordinator: ActiveAppIndicatorCoordinator?

        @objc func refresh(_ link: CADisplayLink) {
            coordinator?.trackDockItem(presentationTime: link.targetTimestamp)
        }
    }

    private var displayLink: AnyObject?
    private var trackingSettingsObserver: Defaults.Observation?
    private var trackingTimer: Timer?
    private var trackedDockItem: AXUIElement?
    private var lastTrackedFrame: CGRect?
    private var motionPredictor = ActiveAppIndicatorMotionPredictor()
    private var predictionNeedsSettling = false
    private var nextDockItemLookup = Date.distantPast
    private var nextVisibilityCheck = Date.distantPast

    private var delayedUpdateTimer: Timer?
    private let delayedUpdateInterval: TimeInterval = 0.6

    private var layoutTrackingTimer: Timer?
    private var layoutTrackingDeadline: CFTimeInterval = 0
    private static let layoutTrackingDuration: CFTimeInterval = 0.6
    private static let layoutTrackingSettle: CFTimeInterval = 0.15
    private static let layoutTrackingInterval: TimeInterval = 1.0 / 60

    private static let animationDuration: TimeInterval = 0.25

    // Dock state tracking
    private var lastKnownDockPosition: DockPosition
    private var lastKnownDockSize: CGFloat
    private var isDockCurrentlyVisible: Bool = true

    private var showsRunningAppDots: Bool {
        Defaults[.activeAppIndicatorStyle] == .runningAppDots
    }

    init() {
        lastKnownDockPosition = DockUtils.getDockPosition()
        lastKnownDockSize = DockUtils.getDockSize()

        ActiveAppIndicatorCoordinator.shared = self
        setupObservers()
        showIndicator()
        updateTrackingMode()
    }

    deinit {
        cleanup()
        if ActiveAppIndicatorCoordinator.shared === self {
            ActiveAppIndicatorCoordinator.shared = nil
        }
    }

    // MARK: - Setup

    private func setupObservers() {
        // Observe frontmost app changes
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let app = notification.userInfo?[
                NSWorkspace.applicationUserInfoKey
            ] as? NSRunningApplication {
                self?.handleActiveAppChanged(app)
            }
        }

        // Observe all position-related settings with a single observer
        // Color is handled by @Default in the SwiftUI view automatically
        positionSettingsObserver = Defaults.observe(
            keys: .activeAppIndicatorAutoSize,
            .activeAppIndicatorAutoLength,
            .activeAppIndicatorHeight,
            .activeAppIndicatorOffset,
            .activeAppIndicatorLength,
            .activeAppIndicatorShift,
            .activeAppIndicatorStyle
        ) { [weak self] in
            DispatchQueue.main.async {
                guard let self, let app = self.currentActiveApp else { return }
                self.updateTrackingMode()
                self.updateIndicatorPosition(for: app)
            }
        }

        // Observe screen parameter changes (dock position/size changes)
        screenParametersObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenParametersChanged()
        }

        trackingSettingsObserver = Defaults.observe(.activeAppIndicatorFollowsMagnification) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.updateTrackingMode()
                if let app = self.currentActiveApp {
                    self.updateIndicatorPosition(for: app)
                }
            }
        }
        setupDockLayoutObserver()
    }

    private func updateTrackingMode() {
        stopTrackingDockItem()
        guard Defaults[.activeAppIndicatorFollowsMagnification], !showsRunningAppDots else { return }
        lastTrackedFrame = nil
        motionPredictor.reset()
        predictionNeedsSettling = false
        if #available(macOS 14.0, *), let indicatorWindow {
            let target = DisplayLinkTarget()
            target.coordinator = self
            let link = indicatorWindow.displayLink(target: target, selector: #selector(DisplayLinkTarget.refresh(_:)))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 120, maximum: 120, preferred: 120)
            link.add(to: .main, forMode: .common)
            displayLink = link
            return
        }
        let timer = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in
            self?.trackDockItem()
        }
        timer.tolerance = 0
        RunLoop.main.add(timer, forMode: .common)
        trackingTimer = timer
    }

    private func stopTrackingDockItem() {
        if #available(macOS 14.0, *) {
            (displayLink as? CADisplayLink)?.invalidate()
        }
        displayLink = nil
        trackingTimer?.invalidate()
        trackingTimer = nil
    }

    private func trackDockItem(presentationTime: TimeInterval? = nil) {
        guard let app = currentActiveApp, app.bundleIdentifier != dockAppIdentifier else { return }
        if Date() >= nextVisibilityCheck {
            nextVisibilityCheck = Date().addingTimeInterval(delayedUpdateInterval)
            updateDockVisibilityState(listFrame: currentDockListFrame())
        }
        guard isDockCurrentlyVisible else { return }

        if trackedDockItem == nil {
            guard Date() >= nextDockItemLookup else { return }
            nextDockItemLookup = Date().addingTimeInterval(delayedUpdateInterval)
            trackedDockItem = ActiveAppIndicatorDockDetection.getDockItem(for: app)
        }
        guard let item = trackedDockItem else { return }
        guard let frame = ActiveAppIndicatorDockDetection.frame(of: item) else {
            trackedDockItem = nil
            lastTrackedFrame = nil
            indicatorWindow?.orderOut(nil)
            return
        }
        guard frame != lastTrackedFrame || predictionNeedsSettling else { return }
        lastTrackedFrame = frame
        updateIndicatorPosition(for: app, liveFrame: frame, presentationTime: presentationTime)
    }

    private func setupDockLayoutObserver() {
        guard let dockApp = DockUtils.runningDock else {
            return
        }

        let dockPID = dockApp.processIdentifier
        let dockElement = AXUIElementCreateApplication(dockPID)

        guard let children = try? dockElement.children(),
              let dockList = children.first(where: { (try? $0.role()) == kAXListRole })
        else {
            return
        }

        var observer: AXObserver?
        guard AXObserverCreate(dockPID, { _, _, notification, refcon in
            guard let refcon else { return }
            let coordinator = Unmanaged<ActiveAppIndicatorCoordinator>.fromOpaque(refcon).takeUnretainedValue()
            let itemsChanged = (notification as String) != kAXSelectedChildrenChangedNotification
            DispatchQueue.main.async {
                coordinator.handleDockLayoutChanged(itemsChanged: itemsChanged)
            }
        }, &observer) == .success, let observer else {
            return
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        AXObserverAddNotification(observer, dockList, kAXUIElementDestroyedNotification as CFString, refcon)
        AXObserverAddNotification(observer, dockList, kAXCreatedNotification as CFString, refcon)
        AXObserverAddNotification(observer, dockList, kAXSelectedChildrenChangedNotification as CFString, refcon)

        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)

        dockLayoutObserver = observer
        observedDockList = dockList
    }

    private func handleDockLayoutChanged(itemsChanged: Bool) {
        if itemsChanged {
            trackedDockItem = nil
            lastTrackedFrame = nil
            nextDockItemLookup = .distantPast
        }
        let listMoved = followDockList()
        if itemsChanged || listMoved {
            trackDockLayout(refreshingDots: itemsChanged)
        }
        if !showsRunningAppDots {
            hideIndicatorIfDockChangedScreens()
            scheduleDelayedUpdate()
        } else if !itemsChanged, !listMoved {
            scheduleDelayedUpdate()
        }
    }

    func handleSpaceChanged() {
        dockHidesInCurrentSpace = false
        trackDockLayout(refreshingDots: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            updateDockVisibilityState(listFrame: currentDockListFrame())
        }
    }

    private func currentDockListFrame() -> CGRect? {
        if let observedDockList, let frame = ActiveAppIndicatorDockDetection.frame(of: observedDockList) {
            return frame
        }
        return ActiveAppIndicatorDockDetection.dockList().flatMap(ActiveAppIndicatorDockDetection.frame(of:))
    }

    @discardableResult
    private func updateDockVisibilityState(listFrame: CGRect?) -> Bool {
        lastDockListFrame = listFrame
        let autoHide = CoreDockGetAutoHideEnabled()
        let isVisible = !autoHide && ActiveAppIndicatorDockDetection.isDockShown(listFrame: listFrame)
        if !autoHide, !isVisible {
            dockHidesInCurrentSpace = true
        }
        updateHiddenDockMouseMonitor(enabled: dockHidesInCurrentSpace && !autoHide)

        guard isVisible != isDockCurrentlyVisible else { return false }
        isDockCurrentlyVisible = isVisible

        if isVisible {
            if let app = currentActiveApp {
                updateIndicatorPosition(for: app, widenFromCenter: true)
            }
        } else {
            animateHideIndicator()
        }
        return true
    }

    @discardableResult
    private func followDockList() -> Bool {
        let listFrame = currentDockListFrame()
        guard listFrame != lastDockListFrame else { return false }
        let visibilityChanged = updateDockVisibilityState(listFrame: listFrame)
        if !visibilityChanged, isDockCurrentlyVisible, showsRunningAppDots {
            repositionTrackedDots()
        }
        return true
    }

    private func updateHiddenDockMouseMonitor(enabled: Bool) {
        if enabled, hiddenDockMouseMonitor == nil {
            hiddenDockMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
                self?.scheduleDockListCheck()
            }
        } else if !enabled, let monitor = hiddenDockMouseMonitor {
            NSEvent.removeMonitor(monitor)
            hiddenDockMouseMonitor = nil
        }
    }

    private func scheduleDockListCheck() {
        guard !dockListCheckPending else { return }
        dockListCheckPending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }
            dockListCheckPending = false
            if followDockList() {
                trackDockLayout(refreshingDots: false)
            }
        }
    }

    private func trackDockLayout(refreshingDots: Bool = true) {
        layoutTrackingDeadline = max(layoutTrackingDeadline, CACurrentMediaTime() + Self.layoutTrackingDuration)
        if refreshingDots, showsRunningAppDots {
            updateRunningAppDots()
        }
        guard layoutTrackingTimer == nil else { return }
        layoutTrackingTimer = Timer.scheduledTimer(withTimeInterval: Self.layoutTrackingInterval, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            if followDockList() {
                layoutTrackingDeadline = max(layoutTrackingDeadline, CACurrentMediaTime() + Self.layoutTrackingSettle)
            }
            guard CACurrentMediaTime() >= layoutTrackingDeadline else { return }
            timer.invalidate()
            layoutTrackingTimer = nil
            if showsRunningAppDots {
                updateRunningAppDots()
            }
        }
    }

    private func cleanup() {
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        if let observer = screenParametersObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = dockLayoutObserver, let dockList = observedDockList {
            AXObserverRemoveNotification(observer, dockList, kAXUIElementDestroyedNotification as CFString)
            AXObserverRemoveNotification(observer, dockList, kAXCreatedNotification as CFString)
            AXObserverRemoveNotification(observer, dockList, kAXSelectedChildrenChangedNotification as CFString)
        }
        dockLayoutObserver = nil
        observedDockList = nil
        updateHiddenDockMouseMonitor(enabled: false)
        stopTrackingDockItem()
        trackingSettingsObserver?.invalidate()
        delayedUpdateTimer?.invalidate()
        layoutTrackingTimer?.invalidate()
        positionSettingsObserver?.invalidate()
        hideIndicator()
    }

    private func handleScreenParametersChanged() {
        updateTrackingMode()
        let newDockPosition = DockUtils.getDockPosition()
        let newDockSize = DockUtils.getDockSize()

        // Check if dock position changed
        if newDockPosition != lastKnownDockPosition {
            lastKnownDockPosition = newDockPosition
            notifyDockPositionChanged(newPosition: newDockPosition)
        }

        if newDockSize != lastKnownDockSize {
            lastKnownDockSize = newDockSize
            scheduleDelayedUpdate()
        }

        updateDockVisibilityState(listFrame: currentDockListFrame())
        trackDockLayout()
    }

    // MARK: - Dock Item Change Notifications

    func notifyDockItemsChanged() {
        if showsRunningAppDots {
            trackDockLayout()
        } else {
            scheduleDelayedUpdate()
        }
    }

    func notifyWindowsChanged() {
        scheduleDelayedUpdate()
    }

    private func scheduleDelayedUpdate() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            delayedUpdateTimer?.invalidate()
            delayedUpdateTimer = Timer.scheduledTimer(
                withTimeInterval: delayedUpdateInterval,
                repeats: false
            ) { [weak self] _ in
                guard let self else { return }
                delayedUpdateTimer = nil
                guard let app = currentActiveApp else { return }
                updateIndicatorPosition(for: app)
            }
        }
    }

    private func hideIndicatorIfDockChangedScreens() {
        guard Defaults[.activeAppIndicatorStyle] == .bar else { return }
        guard let indicatorWindow,
              indicatorWindow.isVisible,
              indicatorWindow.alphaValue > 0,
              let app = currentActiveApp,
              let currentScreen = CGPoint(
                  x: indicatorWindow.frame.midX,
                  y: indicatorWindow.frame.midY
              ).screen()
        else {
            return
        }

        let dockPosition = DockUtils.getDockPosition()
        guard ActiveAppIndicatorPositioning.isSupported(dockPosition),
              let dockItemFrame = ActiveAppIndicatorDockDetection.getDockItemFrame(for: app),
              let targetFrame = ActiveAppIndicatorDockDetection.calculateIndicatorFrame(
                  relativeTo: dockItemFrame,
                  dockPosition: dockPosition
              ),
              let targetScreen = CGPoint(
                  x: targetFrame.midX,
                  y: targetFrame.midY
              ).screen(),
              currentScreen.uniqueIdentifier() != targetScreen.uniqueIdentifier()
        else {
            return
        }

        indicatorWindow.alphaValue = 0
    }

    // MARK: - Dock Orientation Notifications

    /// Called when dock orientation changes
    private func notifyDockPositionChanged(newPosition: DockPosition) {
        // Hide indicator if dock moved to unsupported position
        if !ActiveAppIndicatorPositioning.isSupported(newPosition) {
            animateHideIndicator()
        } else if let app = currentActiveApp {
            // Dock moved to a supported position - reposition indicator
            updateIndicatorPosition(for: app)
        }
    }

    // MARK: - Visibility Management

    private func showIndicator() {
        if indicatorWindow == nil {
            indicatorWindow = ActiveAppIndicatorWindow()
        }
        // Update with current frontmost app
        if let frontmost = NSWorkspace.shared.frontmostApplication {
            handleActiveAppChanged(frontmost)
        }
    }

    private func hideIndicator() {
        indicatorWindow?.orderOut(self)
        indicatorWindow = nil
        currentActiveApp = nil
    }

    // MARK: - Active App Handling

    private func handleActiveAppChanged(_ app: NSRunningApplication) {
        let previousApp = currentActiveApp
        currentActiveApp = app
        motionPredictor.reset()
        predictionNeedsSettling = false
        trackedDockItem = nil
        lastTrackedFrame = nil
        nextDockItemLookup = .distantPast

        guard app.bundleIdentifier != dockAppIdentifier else {
            if showsRunningAppDots {
                updateRunningAppDots()
            } else {
                animateHideIndicator()
            }
            return
        }

        let visibilityChanged = updateDockVisibilityState(listFrame: currentDockListFrame())
        if !showsRunningAppDots {
            if !visibilityChanged {
                let isNewApp = previousApp?.bundleIdentifier != app.bundleIdentifier
                updateIndicatorPosition(for: app, widenFromCenter: isNewApp)
            }
            scheduleDelayedUpdate()
        }
        trackDockLayout(refreshingDots: !visibilityChanged)
    }

    private func updateIndicatorPosition(for app: NSRunningApplication, widenFromCenter: Bool = false, liveFrame: CGRect? = nil, presentationTime: TimeInterval? = nil) {
        guard isDockCurrentlyVisible else {
            indicatorWindow?.orderOut(self)
            return
        }

        guard let indicatorWindow else {
            return
        }

        if showsRunningAppDots {
            updateRunningAppDots()
            return
        }

        guard let dockItemFrame = liveFrame ?? ActiveAppIndicatorDockDetection.getDockItemFrame(for: app) else {
            indicatorWindow.orderOut(self)
            return
        }

        let dockPosition = DockUtils.getDockPosition()

        guard ActiveAppIndicatorPositioning.isSupported(dockPosition) else {
            indicatorWindow.orderOut(self)
            return
        }

        guard var targetFrame = ActiveAppIndicatorDockDetection.calculateIndicatorFrame(
            relativeTo: dockItemFrame,
            dockPosition: dockPosition
        ) else {
            indicatorWindow.orderOut(nil)
            return
        }

        if Defaults[.activeAppIndicatorFollowsMagnification] {
            if liveFrame != nil {
                let measuredFrame = targetFrame
                let now = CACurrentMediaTime()
                targetFrame = motionPredictor.project(
                    measuredFrame,
                    at: now,
                    presentationTime: presentationTime ?? (now + 1.0 / 120.0)
                )
                predictionNeedsSettling = targetFrame != measuredFrame
            } else {
                motionPredictor.reset()
                predictionNeedsSettling = false
            }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            indicatorWindow.setFrame(targetFrame, display: true)
            CATransaction.commit()
            indicatorWindow.alphaValue = 1
            if !indicatorWindow.isVisible {
                indicatorWindow.orderFront(self)
            }
        } else if widenFromCenter {
            let collapsed = ActiveAppIndicatorDockDetection.collapsedFrame(
                from: targetFrame,
                dockPosition: dockPosition
            )
            indicatorWindow.setFrame(collapsed, display: false)
            indicatorWindow.alphaValue = 1
            indicatorWindow.orderFront(self)

            NSAnimationContext.runAnimationGroup { context in
                context.duration = Self.animationDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                indicatorWindow.animator().setFrame(targetFrame, display: true)
            }
        } else if indicatorWindow.alphaValue == 0 {
            indicatorWindow.setFrame(targetFrame, display: false)
            indicatorWindow.alphaValue = 1
            indicatorWindow.orderFront(self)
        } else {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = Self.animationDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                indicatorWindow.animator().setFrame(targetFrame, display: true)
            }
            indicatorWindow.orderFront(self)
        }
    }

    private func updateRunningAppDots() {
        guard isDockCurrentlyVisible else {
            indicatorWindow?.orderOut(self)
            return
        }

        let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let windowedPIDs = Self.pidsWithVisibleWindows()
        trackedDots = ActiveAppIndicatorDockDetection.getRunningAppDockItems().map { item in
            let pid = item.app.processIdentifier
            return TrackedDot(
                pid: pid,
                element: item.element,
                frame: item.frame,
                hasWindows: windowedPIDs.contains(pid) || !WindowUtil.readCachedWindows(for: pid).isEmpty,
                isFrontmost: pid == frontmostPID
            )
        }
        layoutTrackedDots()
    }

    private func repositionTrackedDots() {
        trackedDots = trackedDots.compactMap { dot in
            guard let frame = ActiveAppIndicatorDockDetection.appKitFrame(of: dot.element) else { return nil }
            var dot = dot
            dot.frame = frame
            return dot
        }
        layoutTrackedDots()
    }

    private func layoutTrackedDots() {
        guard let indicatorWindow else { return }

        let dockPosition = DockUtils.getDockPosition()
        guard ActiveAppIndicatorPositioning.isSupported(dockPosition),
              let firstDot = trackedDots.first,
              let screen = CGPoint(
                  x: firstDot.frame.midX,
                  y: firstDot.frame.midY
              ).screen()
        else {
            indicatorWindow.orderOut(self)
            return
        }

        let metrics = ActiveAppIndicatorDockDetection.dotMetrics(
            dockSize: DockUtils.getDockSize(on: screen),
            dockPosition: dockPosition
        )
        guard let centerLine = ActiveAppIndicatorPositioning.calculateIndicatorFrame(
            for: firstDot.frame,
            dockPosition: dockPosition,
            indicatorThickness: metrics.thickness,
            indicatorOffset: metrics.offset,
            indicatorLength: 0
        ) else {
            indicatorWindow.orderOut(self)
            return
        }
        let dotSize = metrics.dotSize

        let shift = Defaults[.activeAppIndicatorShift]
        let dotCenters = trackedDots.map { dot in
            dockPosition == .bottom
                ? CGPoint(x: dot.frame.midX + shift, y: centerLine.midY)
                : CGPoint(x: centerLine.midX + shift, y: dot.frame.midY)
        }
        let panelFrame = (dockPosition == .bottom
            ? CGRect(x: screen.frame.minX, y: centerLine.midY - dotSize / 2, width: screen.frame.width, height: dotSize)
            : CGRect(x: centerLine.midX + shift - dotSize / 2, y: screen.frame.minY, width: dotSize, height: screen.frame.height)
        ).integral

        let dots: [DockAppDot] = zip(trackedDots, dotCenters).map { dot, center in
            DockAppDot(
                id: dot.pid,
                center: CGPoint(x: center.x - panelFrame.minX, y: panelFrame.maxY - center.y),
                size: dotSize,
                hasWindows: dot.hasWindows,
                isFrontmost: dot.isFrontmost
            )
        }

        let wasShowing = indicatorWindow.isVisible && indicatorWindow.frame.intersects(screen.frame)
        indicatorWindow.updateDots(dots)
        if indicatorWindow.frame != panelFrame {
            indicatorWindow.setFrame(panelFrame, display: true)
        }
        guard !wasShowing else { return }

        indicatorWindow.alphaValue = 0
        indicatorWindow.orderFront(self)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.animationDuration
            indicatorWindow.animator().alphaValue = 1
        }
    }

    private static func pidsWithVisibleWindows() -> Set<pid_t> {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return []
        }

        var pids = Set<pid_t>()
        for entry in windowList {
            guard let layer = entry[kCGWindowLayer as String] as? Int, layer == 0,
                  let pid = entry[kCGWindowOwnerPID as String] as? pid_t,
                  let bounds = entry[kCGWindowBounds as String] as? [String: CGFloat],
                  bounds["Width", default: 0] >= 64, bounds["Height", default: 0] >= 64
            else { continue }
            pids.insert(pid)
        }
        return pids
    }

    private func animateHideIndicator() {
        guard let indicatorWindow, indicatorWindow.isVisible else { return }

        guard !showsRunningAppDots else {
            indicatorWindow.orderOut(nil)
            return
        }

        if Defaults[.activeAppIndicatorFollowsMagnification], !showsRunningAppDots {
            indicatorWindow.orderOut(nil)
            return
        }
        let dockPosition = DockUtils.getDockPosition()
        let collapsed = ActiveAppIndicatorDockDetection.collapsedFrame(
            from: indicatorWindow.frame,
            dockPosition: dockPosition
        )

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Self.animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            indicatorWindow.animator().setFrame(collapsed, display: true)
        }, completionHandler: {
            indicatorWindow.orderOut(nil)
        })
    }
}
