import ApplicationServices
import Cocoa
import Defaults

/// Implements GNOME-style "intellihide" on top of the native macOS Dock.
///
/// The core idea is simple:
/// - sample the focused window repeatedly
/// - find the display that currently owns the Dock
/// - hide the Dock only when that focused window overlaps the Dock area
///
/// On top of the steady-state overlap logic, the manager also has a short-lived
/// force-hide mode for transitions like drag/resize and title-bar double-click,
/// so the Dock disappears before the final window frame settles.
final class DockIntellihideManager {
    /// Minimal focused-window state used by the polling loop.
    private struct WindowSample: Equatable {
        let pid: pid_t
        let windowID: CGWindowID?
        let frame: CGRect
        let isFullscreen: Bool
    }

    private let pollInterval: TimeInterval = 0.15
    private let transitionHideDuration: TimeInterval = 0.75
    private let titleBarHideDuration: TimeInterval = 1.1
    private let fallbackDockThickness: CGFloat = 72
    private let releasePadding: CGFloat = 2
    private let bottomDockVisualPadding: CGFloat = 2
    private let sideDockVisualPadding: CGFloat = 2
    private let minimumFrameDeltaToDetectTransition: CGFloat = 2
    private let titleBarDetectionHeight: CGFloat = 80

    private var evaluationTimer: Timer?
    private var defaultsObserver: Defaults.Observation?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var screenObserver: NSObjectProtocol?
    private var eventTap: CFMachPort?
    private var eventTapRunLoopSource: CFRunLoopSource?
    private var unmanagedEventTapUserInfo: Unmanaged<EventTapUserInfo>?

    /// Tracks the user's original Dock preference so disabling the feature
    /// restores the Dock to the state macOS had before we started changing it.
    private var originalAutoHideState: Bool?
    private var lastAppliedAutoHideState: Bool?
    private var lastSample: WindowSample?
    private var forceHideUntil: Date?
    /// Cached geometry prevents the hide/show boundary from drifting while the
    /// Dock is actively animating in or out.
    private var cachedDockThickness: [String: CGFloat] = [:]
    private var cachedDockFrame: CGRect?

    private final class EventTapUserInfo {
        let manager: DockIntellihideManager

        init(manager: DockIntellihideManager) {
            self.manager = manager
        }
    }

    private static let eventTapCallback: CGEventTapCallBack = { proxy, type, event, refcon in
        guard let refcon else { return Unmanaged.passUnretained(event) }
        let manager = Unmanaged<EventTapUserInfo>.fromOpaque(refcon).takeUnretainedValue().manager
        return manager.handleEventTap(proxy: proxy, type: type, event: event)
    }

    init() {
        setupObservers()
        reconfigure()
    }

    deinit {
        defaultsObserver = nil
        workspaceObservers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        workspaceObservers.removeAll()

        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }

        stopEvaluating()
        stopMonitoringTitleBarClicks()
        restoreOriginalDockState()
    }

    func refreshNow() {
        DispatchQueue.main.async { [weak self] in
            self?.evaluateDockVisibility()
        }
    }

    /// Re-evaluate when the environment changes in a way that can move the Dock
    /// or change which window should control it.
    private func setupObservers() {
        defaultsObserver = Defaults.observe(keys: .enableDockIntellihide) { [weak self] in
            DispatchQueue.main.async {
                self?.reconfigure()
            }
        }

        let workspaceNotificationCenter = NSWorkspace.shared.notificationCenter
        let workspaceNames: [Notification.Name] = [
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.activeSpaceDidChangeNotification,
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
        ]

        for name in workspaceNames {
            let observer = workspaceNotificationCenter.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.refreshNow()
            }
            workspaceObservers.append(observer)
        }

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshNow()
        }
    }

    /// Starts or tears down the whole feature when the setting changes.
    private func reconfigure() {
        if Defaults[.enableDockIntellihide] {
            if originalAutoHideState == nil {
                originalAutoHideState = CoreDockGetAutoHideEnabled()
            }
            startMonitoringTitleBarClicks()
            startEvaluating()
            refreshNow()
        } else {
            stopEvaluating()
            stopMonitoringTitleBarClicks()
            lastSample = nil
            forceHideUntil = nil
            restoreOriginalDockState()
        }
    }

    private func startEvaluating() {
        guard evaluationTimer == nil else { return }

        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.evaluateDockVisibility()
        }
        evaluationTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopEvaluating() {
        evaluationTimer?.invalidate()
        evaluationTimer = nil
    }

    /// Watches for global mouse downs so we can detect title-bar double-clicks
    /// early enough to hide the Dock before zoom/fullscreen finishes.
    private func startMonitoringTitleBarClicks() {
        guard eventTap == nil else { return }

        let eventMask = CGEventMask(1 << CGEventType.leftMouseDown.rawValue)
        let userInfo = EventTapUserInfo(manager: self)
        unmanagedEventTapUserInfo = Unmanaged.passRetained(userInfo)

        guard let newEventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: Self.eventTapCallback,
            userInfo: unmanagedEventTapUserInfo?.toOpaque()
        ) else {
            unmanagedEventTapUserInfo?.release()
            unmanagedEventTapUserInfo = nil
            return
        }

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newEventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: newEventTap, enable: true)

        eventTap = newEventTap
        eventTapRunLoopSource = runLoopSource
    }

    private func stopMonitoringTitleBarClicks() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            if let eventTapRunLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), eventTapRunLoopSource, .commonModes)
            }
            CFMachPortInvalidate(eventTap)
        }

        if let unmanagedEventTapUserInfo {
            unmanagedEventTapUserInfo.release()
        }

        eventTap = nil
        eventTapRunLoopSource = nil
        unmanagedEventTapUserInfo = nil
    }

    private func restoreOriginalDockState() {
        guard let originalAutoHideState else { return }
        applyAutoHide(originalAutoHideState, force: true)
        self.originalAutoHideState = nil
    }

    /// Main decision loop.
    ///
    /// The order matters:
    /// 1. reject apps that should never control the Dock
    /// 2. get the frontmost focused window
    /// 3. resolve the screen currently showing the Dock
    /// 4. build a stable Dock overlap region on that screen
    /// 5. either force-hide for an active transition or apply normal overlap
    ///    rules
    private func evaluateDockVisibility() {
        guard Defaults[.enableDockIntellihide] else { return }

        guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
              frontmostApp.activationPolicy == .regular,
              frontmostApp.bundleIdentifier != Bundle.main.bundleIdentifier,
              frontmostApp.bundleIdentifier != "com.apple.dock"
        else {
            lastSample = nil
            forceHideUntil = nil
            applyAutoHide(false)
            return
        }

        if WindowUtil.isAppInFullscreen(frontmostApp) {
            applyAutoHide(true)
            return
        }

        guard let sample = currentSample(for: frontmostApp) else {
            lastSample = nil
            forceHideUntil = nil
            applyAutoHide(false)
            return
        }

        guard let windowScreen = screen(for: sample.frame),
              let dockScreen = dockScreen()
        else {
            applyAutoHide(false)
            return
        }

        guard windowScreen.uniqueIdentifier() == dockScreen.uniqueIdentifier() else {
            forceHideUntil = nil
            applyAutoHide(false)
            return
        }

        let dockPosition = DockUtils.getDockPosition()
        let dockFrame = resolvedDockFrame(preferCached: lastAppliedAutoHideState == true || forceHideUntil != nil)
        let dockRegion = stabilizedDockRegion(for: dockScreen, position: dockPosition, dockFrame: dockFrame)
        let evaluationRegion = releaseRegion(for: dockRegion, position: dockPosition)
        if shouldForceHideTransition(from: lastSample, to: sample, dockInfluenceRegion: evaluationRegion) {
            forceHideUntil = Date().addingTimeInterval(transitionHideDuration)
        }

        lastSample = sample

        // Temporary force-hide keeps the Dock out of the way while an in-flight
        // move/resize/fullscreen transition completes.
        if let forceHideUntil, forceHideUntil > Date() {
            applyAutoHide(true)
            return
        }
        forceHideUntil = nil

        // Once the Dock is already hidden, use a slightly expanded release
        // region so it does not flap at the exact overlap boundary.
        let shouldHide = if lastAppliedAutoHideState == true {
            sample.frame.intersects(evaluationRegion)
        } else {
            sample.frame.intersects(dockRegion)
        }

        applyAutoHide(shouldHide)
    }

    /// Pulls the focused AX window for the active app. This is intentionally
    /// lightweight because it runs on every poll.
    private func currentSample(for app: NSRunningApplication) -> WindowSample? {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        guard let window = try? appElement.focusedWindow(),
              let position = try? window.position(),
              let size = try? window.size()
        else {
            return nil
        }

        let frame = CGRect(origin: position, size: size)
        guard !frame.isNull, !frame.isEmpty else { return nil }

        return WindowSample(
            pid: app.processIdentifier,
            windowID: try? window.cgWindowId(),
            frame: frame,
            isFullscreen: (try? window.isFullscreen()) ?? false
        )
    }

    /// Detects a meaningful in-flight move or resize close to the Dock. We only
    /// force-hide when the same window changed enough to matter and either the
    /// old or new frame touches the Dock influence region.
    private func shouldForceHideTransition(from oldSample: WindowSample?, to newSample: WindowSample, dockInfluenceRegion: CGRect) -> Bool {
        guard let oldSample else { return false }
        guard oldSample.pid == newSample.pid else { return false }

        if let oldWindowID = oldSample.windowID, let newWindowID = newSample.windowID, oldWindowID != newWindowID {
            return false
        }

        if oldSample.isFullscreen != newSample.isFullscreen {
            return true
        }

        let deltaX = abs(oldSample.frame.origin.x - newSample.frame.origin.x)
        let deltaY = abs(oldSample.frame.origin.y - newSample.frame.origin.y)
        let deltaWidth = abs(oldSample.frame.size.width - newSample.frame.size.width)
        let deltaHeight = abs(oldSample.frame.size.height - newSample.frame.size.height)

        let hasMeaningfulFrameChange = deltaX > minimumFrameDeltaToDetectTransition ||
            deltaY > minimumFrameDeltaToDetectTransition ||
            deltaWidth > minimumFrameDeltaToDetectTransition ||
            deltaHeight > minimumFrameDeltaToDetectTransition

        guard hasMeaningfulFrameChange else { return false }

        return oldSample.frame.intersects(dockInfluenceRegion) || newSample.frame.intersects(dockInfluenceRegion)
    }

    /// Converts a window frame to the most likely screen in AX coordinate space.
    private func screen(for frame: CGRect) -> NSScreen? {
        if let containingScreen = NSScreen.screens.first(where: { axScreenFrame(for: $0).contains(frame.center) }) {
            return containingScreen
        }

        return NSScreen.screens.max { lhs, rhs in
            axScreenFrame(for: lhs).intersection(frame).area < axScreenFrame(for: rhs).intersection(frame).area
        }
    }

    /// Finds the display where macOS is currently drawing the Dock. This is the
    /// only display that should influence the intellihide decision.
    private func dockScreen() -> NSScreen? {
        if let dockFrame = resolvedDockFrame(preferCached: lastAppliedAutoHideState == true || forceHideUntil != nil) {
            return screen(for: dockFrame)
        }

        let position = DockUtils.getDockPosition()
        let screenWithInset = NSScreen.screens.max { lhs, rhs in
            measuredDockThickness(for: lhs, position: position) < measuredDockThickness(for: rhs, position: position)
        }

        if let screenWithInset, measuredDockThickness(for: screenWithInset, position: position) > 0 {
            return screenWithInset
        }

        return NSScreen.main
    }

    /// Builds a live Dock frame by unioning the AX frames of the Dock items.
    /// This is more precise than relying only on visibleFrame insets.
    private func currentDockFrame() -> CGRect? {
        guard let dockApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            return nil
        }

        let dockElement = AXUIElementCreateApplication(dockApp.processIdentifier)
        guard let children = try? dockElement.children(),
              let dockList = children.first(where: { (try? $0.role()) == kAXListRole }),
              let dockItems = try? dockList.children()
        else {
            return nil
        }

        let itemFrames = dockItems.compactMap { item -> CGRect? in
            guard let position = try? item.position(),
                  let size = try? item.size(),
                  size.width > 0,
                  size.height > 0
            else {
                return nil
            }

            return CGRect(origin: position, size: size)
        }

        guard !itemFrames.isEmpty else { return nil }
        return itemFrames.reduce(into: itemFrames[0]) { partialResult, frame in
            partialResult = partialResult.union(frame)
        }
    }

    /// Fallback Dock-region builder used when the live Dock frame is not
    /// available. It derives a reserved edge band from visibleFrame insets.
    private func stabilizedDockRegion(for screen: NSScreen, position: DockPosition, dockFrame: CGRect?) -> CGRect {
        if let dockFrame {
            return stabilizedDockRegion(for: screen, position: position, dockFrame: dockFrame)
        }

        let measuredThickness = measuredDockThickness(for: screen, position: position)
        let cacheKey = "\(screen.uniqueIdentifier())-\(position.storageKey)"
        let thickness = resolvedDockThickness(measuredThickness: measuredThickness, cacheKey: cacheKey) + visualPadding(for: position)
        let screenFrame = axScreenFrame(for: screen)

        switch position {
        case .left:
            return CGRect(x: screenFrame.minX, y: screenFrame.minY, width: thickness, height: screenFrame.height)
        case .right:
            return CGRect(x: screenFrame.maxX - thickness, y: screenFrame.minY, width: thickness, height: screenFrame.height)
        case .top:
            return CGRect(x: screenFrame.minX, y: screenFrame.minY, width: screenFrame.width, height: thickness)
        case .bottom, .unknown, .cmdTab, .cli:
            return CGRect(x: screenFrame.minX, y: screenFrame.maxY - thickness, width: screenFrame.width, height: thickness)
        }
    }

    /// Preferred Dock-region builder. It turns the live Dock frame into the
    /// full edge band that should hide the Dock when a window enters it.
    private func stabilizedDockRegion(for screen: NSScreen, position: DockPosition, dockFrame: CGRect) -> CGRect {
        let screenFrame = axScreenFrame(for: screen)
        let padding = visualPadding(for: position)

        switch position {
        case .left:
            return CGRect(
                x: screenFrame.minX,
                y: screenFrame.minY,
                width: max(dockFrame.maxX - screenFrame.minX + padding, fallbackDockThickness),
                height: screenFrame.height
            )
        case .right:
            let minX = max(dockFrame.minX - padding, screenFrame.minX)
            return CGRect(
                x: minX,
                y: screenFrame.minY,
                width: max(screenFrame.maxX - minX, fallbackDockThickness),
                height: screenFrame.height
            )
        case .top:
            return CGRect(
                x: screenFrame.minX,
                y: screenFrame.minY,
                width: screenFrame.width,
                height: max(dockFrame.maxY - screenFrame.minY + padding, fallbackDockThickness)
            )
        case .bottom, .unknown, .cmdTab, .cli:
            let minY = max(dockFrame.minY - padding, screenFrame.minY)
            return CGRect(
                x: screenFrame.minX,
                y: minY,
                width: screenFrame.width,
                height: max(screenFrame.maxY - minY, fallbackDockThickness)
            )
        }
    }

    /// Measures how much of the screen edge is currently reserved by the Dock.
    private func measuredDockThickness(for screen: NSScreen, position: DockPosition) -> CGFloat {
        switch position {
        case .left:
            screen.visibleFrame.minX - screen.frame.minX
        case .right:
            screen.frame.maxX - screen.visibleFrame.maxX
        case .top:
            screen.frame.maxY - screen.visibleFrame.maxY
        case .bottom, .unknown, .cmdTab, .cli:
            screen.visibleFrame.minY - screen.frame.minY
        }
    }

    /// While the Dock is hidden or force-hidden, prefer the last stable frame
    /// over a live frame that may be collapsing during animation.
    private func resolvedDockFrame(preferCached: Bool) -> CGRect? {
        if preferCached, let cachedDockFrame {
            return cachedDockFrame
        }

        if let liveDockFrame = currentDockFrame() {
            cachedDockFrame = liveDockFrame
            return liveDockFrame
        }

        return cachedDockFrame
    }

    private func resolvedDockThickness(measuredThickness: CGFloat, cacheKey: String) -> CGFloat {
        if measuredThickness > 0 {
            cachedDockThickness[cacheKey] = measuredThickness
            return measuredThickness
        }

        if let cachedThickness = cachedDockThickness[cacheKey] {
            return cachedThickness
        }

        return fallbackDockThickness
    }

    /// Small hysteresis used only for re-showing the Dock so a window sitting
    /// exactly on the edge does not make the Dock bounce.
    private func releaseRegion(for dockRegion: CGRect, position: DockPosition) -> CGRect {
        switch position {
        case .left, .right:
            dockRegion.insetBy(dx: -releasePadding, dy: 0)
        case .top, .bottom, .unknown, .cmdTab, .cli:
            dockRegion.insetBy(dx: 0, dy: -releasePadding)
        }
    }

    private func visualPadding(for position: DockPosition) -> CGFloat {
        switch position {
        case .left, .right:
            sideDockVisualPadding
        case .top, .bottom, .unknown, .cmdTab, .cli:
            bottomDockVisualPadding
        }
    }

    private func handleEventTap(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput, let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: true)
            return Unmanaged.passUnretained(event)
        }

        guard type == .leftMouseDown else { return Unmanaged.passUnretained(event) }

        handleGlobalTitleBarMouseDown(event: event)
        return Unmanaged.passUnretained(event)
    }

    /// Only a title-bar double-click should trigger the early fullscreen/zoom
    /// hide path. Ordinary clicks inside app content must not affect the Dock.
    private func handleGlobalTitleBarMouseDown(event: CGEvent) {
        guard event.getIntegerValueField(.mouseEventClickState) >= 2 else { return }

        guard Defaults[.enableDockIntellihide],
              let frontmostApp = NSWorkspace.shared.frontmostApplication,
              frontmostApp.activationPolicy == .regular,
              frontmostApp.bundleIdentifier != Bundle.main.bundleIdentifier,
              let sample = currentSample(for: frontmostApp)
        else {
            return
        }

        if titleBarRegion(for: sample.frame).contains(event.location) {
            forceHideUntil = Date().addingTimeInterval(titleBarHideDuration)
            applyAutoHide(true)
        }
    }

    /// Approximate title-bar hit testing from the focused AX window frame.
    private func titleBarRegion(for frame: CGRect) -> CGRect {
        let height = min(titleBarDetectionHeight, frame.height)
        return CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: height)
    }

    /// Writes the Dock autohide state only when it actually changes.
    private func applyAutoHide(_ enabled: Bool, force: Bool = false) {
        if !force, lastAppliedAutoHideState == enabled {
            return
        }

        let currentState = CoreDockGetAutoHideEnabled()
        if force || currentState != enabled {
            CoreDockSetAutoHideEnabled(enabled)
        }

        lastAppliedAutoHideState = enabled
    }

    /// Accessibility reports points in a top-left-origin global space, so we
    /// normalize AppKit screens into that same space before doing overlap math.
    private func axScreenFrame(for screen: NSScreen) -> CGRect {
        let globalMaxY = NSScreen.screens.map(\.frame.maxY).max() ?? NSScreen.main?.frame.maxY ?? 0
        return CGRect(
            x: screen.frame.minX,
            y: globalMaxY - screen.frame.maxY,
            width: screen.frame.width,
            height: screen.frame.height
        )
    }
}

private extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }

    var area: CGFloat {
        width * height
    }
}

private extension DockPosition {
    var storageKey: String {
        switch self {
        case .top:
            "top"
        case .bottom:
            "bottom"
        case .left:
            "left"
        case .right:
            "right"
        case .cmdTab:
            "cmdTab"
        case .cli:
            "cli"
        case .unknown:
            "unknown"
        }
    }
}
