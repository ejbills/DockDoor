import Cocoa
import Defaults
import SwiftUI

/// Manages the active app indicator that shows a line next to the currently active app in the dock.
/// Supports bottom, left, and right dock positions.
final class ActiveAppIndicatorCoordinator {
    static var shared: ActiveAppIndicatorCoordinator?

    private var indicatorWindow: ActiveAppIndicatorWindow?
    private var workspaceObserver: NSObjectProtocol?
    private var positionSettingsObserver: Defaults.Observation?
    private var screenParametersObserver: NSObjectProtocol?

    private var dockLayoutObserver: AXObserver?
    private var observedDockList: AXUIElement?

    private var currentActiveApp: NSRunningApplication?

    private var delayedUpdateTimer: Timer?
    private let delayedUpdateInterval: TimeInterval = 0.6

    private static let animationDuration: TimeInterval = 0.25

    // Dock state tracking
    private var lastKnownDockPosition: DockPosition
    private var lastKnownDockSize: CGFloat
    private var isDockCurrentlyVisible: Bool = true

    init() {
        lastKnownDockPosition = DockUtils.getDockPosition()
        lastKnownDockSize = DockUtils.getDockSize()

        ActiveAppIndicatorCoordinator.shared = self
        setupObservers()
        showIndicator()
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

        setupDockLayoutObserver()
    }

    private func setupDockLayoutObserver() {
        guard let dockApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
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
        guard AXObserverCreate(dockPID, { _, _, _, refcon in
            guard let refcon else { return }
            let coordinator = Unmanaged<ActiveAppIndicatorCoordinator>.fromOpaque(refcon).takeUnretainedValue()
            DispatchQueue.main.async {
                coordinator.handleDockLayoutChanged()
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

    private func handleDockLayoutChanged() {
        hideIndicatorIfDockChangedScreens()
        scheduleDelayedUpdate()
    }

    func handleSpaceChanged() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.updateDockVisibilityState()
        }
    }

    private func updateDockVisibilityState() {
        let isVisible = DockObserver.isDockVisible()

        guard isVisible != isDockCurrentlyVisible else { return }
        isDockCurrentlyVisible = isVisible

        if isVisible {
            if let app = currentActiveApp {
                updateIndicatorPosition(for: app, widenFromCenter: true)
            }
        } else {
            animateHideIndicator()
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
        delayedUpdateTimer?.invalidate()
        positionSettingsObserver?.invalidate()
        hideIndicator()
    }

    private func handleScreenParametersChanged() {
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

        updateDockVisibilityState()
    }

    // MARK: - Dock Item Change Notifications

    func notifyDockItemsChanged() {
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

        guard app.bundleIdentifier != "com.apple.dock" else {
            if Defaults[.activeAppIndicatorStyle] == .runningAppDots {
                updateRunningAppDots()
            } else {
                animateHideIndicator()
            }
            return
        }

        isDockCurrentlyVisible = DockObserver.isDockVisible()

        let isNewApp = previousApp?.bundleIdentifier != app.bundleIdentifier
        updateIndicatorPosition(for: app, widenFromCenter: isNewApp)
        scheduleDelayedUpdate()
    }

    private func updateIndicatorPosition(for app: NSRunningApplication, widenFromCenter: Bool = false) {
        guard isDockCurrentlyVisible else {
            indicatorWindow?.orderOut(self)
            return
        }

        guard let indicatorWindow else {
            return
        }

        if Defaults[.activeAppIndicatorStyle] == .runningAppDots {
            updateRunningAppDots()
            return
        }

        guard let dockItemFrame = ActiveAppIndicatorDockDetection.getDockItemFrame(for: app) else {
            indicatorWindow.orderOut(self)
            return
        }

        let dockPosition = DockUtils.getDockPosition()

        guard ActiveAppIndicatorPositioning.isSupported(dockPosition) else {
            indicatorWindow.orderOut(self)
            return
        }

        guard let targetFrame = ActiveAppIndicatorDockDetection.calculateIndicatorFrame(
            relativeTo: dockItemFrame,
            dockPosition: dockPosition
        ) else {
            indicatorWindow.orderOut(nil)
            return
        }

        if widenFromCenter {
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
        guard let indicatorWindow, isDockCurrentlyVisible else {
            indicatorWindow?.orderOut(self)
            return
        }

        let dockPosition = DockUtils.getDockPosition()
        guard ActiveAppIndicatorPositioning.isSupported(dockPosition) else {
            indicatorWindow.orderOut(self)
            return
        }

        let items = ActiveAppIndicatorDockDetection.getRunningAppDockItems()
        guard let firstItem = items.first,
              let screen = CGPoint(
                  x: firstItem.frame.midX,
                  y: firstItem.frame.midY
              ).screen()
        else {
            indicatorWindow.orderOut(self)
            return
        }

        let metrics = ActiveAppIndicatorDockDetection.dotMetrics(
            dockSize: DockUtils.getDockSize(on: screen),
            dockPosition: dockPosition
        )
        let panelThickness = metrics.dotSize
        let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let windowedPIDs = Self.pidsWithVisibleWindows()

        var panelFrame: CGRect
        switch dockPosition {
        case .bottom:
            let minX = items.map(\.frame.minX).min()!
            let maxX = items.map(\.frame.maxX).max()!
            let y = firstItem.frame.minY - panelThickness - 2 + metrics.offset
            panelFrame = CGRect(x: minX, y: y, width: maxX - minX, height: panelThickness)
        case .left:
            let minY = items.map(\.frame.minY).min()!
            let maxY = items.map(\.frame.maxY).max()!
            let x = firstItem.frame.minX - panelThickness - 2 - metrics.offset
            panelFrame = CGRect(x: x, y: minY, width: panelThickness, height: maxY - minY)
        case .right:
            let minY = items.map(\.frame.minY).min()!
            let maxY = items.map(\.frame.maxY).max()!
            let x = firstItem.frame.maxX + 2 + metrics.offset
            panelFrame = CGRect(x: x, y: minY, width: panelThickness, height: maxY - minY)
        default:
            indicatorWindow.orderOut(self)
            return
        }

        let dots: [DockAppDot] = items.map { item in
            let pid = item.app.processIdentifier
            let hasWindows = windowedPIDs.contains(pid)
                || !WindowUtil.readCachedWindows(for: pid).isEmpty
            let center = switch dockPosition {
            case .bottom:
                CGPoint(x: item.frame.midX - panelFrame.minX, y: panelFrame.height / 2)
            default:
                CGPoint(x: panelFrame.width / 2, y: panelFrame.maxY - item.frame.midY)
            }
            return DockAppDot(
                id: pid,
                center: center,
                size: metrics.dotSize,
                hasWindows: hasWindows,
                isFrontmost: pid == frontmostPID
            )
        }

        panelFrame.origin.x += Defaults[.activeAppIndicatorShift]

        indicatorWindow.updateDots(dots)
        indicatorWindow.setFrame(panelFrame, display: true)
        indicatorWindow.alphaValue = 1
        indicatorWindow.orderFront(self)
    }

    private static func pidsWithVisibleWindows() -> Set<pid_t> {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.excludeDesktopElements],
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

        guard Defaults[.activeAppIndicatorStyle] == .bar else {
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
