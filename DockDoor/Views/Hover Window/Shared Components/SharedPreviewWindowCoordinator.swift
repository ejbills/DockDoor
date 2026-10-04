import Defaults
import Sparkle
import SwiftUI

enum ArrowDirection {
    case left, right, up, down
}

enum EmbeddedContentType: Equatable {
    case media(bundleIdentifier: String)
    case calendar(bundleIdentifier: String)
    case none
}

final class SharedPreviewWindowCoordinator: NSPanel {
    weak static var activeInstance: SharedPreviewWindowCoordinator?

    let windowSwitcherCoordinator = PreviewStateCoordinator()
    private let dockManager = DockAutoHideManager()
    private var searchWindow: SearchWindow?

    private var appName: String = ""
    var currentlyDisplayedPID: pid_t?
    var mouseIsWithinPreviewWindow: Bool = false
    private var onWindowTap: (() -> Void)?
    private var fullPreviewWindow: NSPanel?
    private var activeFullPreviewHoverID: UUID?
    private var pendingShowWorkItem: DispatchWorkItem?
    private var pendingShow: (id: UUID, pid: pid_t?, stageManagerProtection: Bool, freshWindows: [WindowInfo]?)?

    var windowSize: CGSize = getWindowSize()

    private var previousHoverWindowOrigin: CGPoint?

    private var anchoredDockItem: (element: AXUIElement, iconRect: CGRect)?
    private var panelAnchor: (screen: NSScreen, origin: (CGSize) -> CGPoint)?

    private(set) var hasScreenRecordingPermission: Bool = PermissionsChecker.hasScreenRecordingPermission()

    var pinnedWindows: [String: (window: NSWindow, info: PinnedWindowInfo)] = [:]

    struct TapSnapshot {
        var isVisible = false
        var frame: CGRect = .zero
        var fullPreviewFrame: CGRect?
        var searchFrame: CGRect?
        var isSearchFocused = false
    }

    private let tapSnapshotLock = NSLock()
    private var currentTapSnapshot = TapSnapshot()

    /// Window state for event tap callbacks, which run off the main thread.
    var tapSnapshot: TapSnapshot {
        tapSnapshotLock.lock()
        defer { tapSnapshotLock.unlock() }
        return currentTapSnapshot
    }

    @objc private func publishTapSnapshot() {
        let snapshot = TapSnapshot(
            isVisible: isVisible,
            frame: frame,
            fullPreviewFrame: fullPreviewWindow.flatMap { $0.isVisible ? $0.frame : nil },
            searchFrame: searchWindowFrame,
            isSearchFocused: isSearchWindowFocused
        )
        tapSnapshotLock.lock()
        currentTapSnapshot = snapshot
        tapSnapshotLock.unlock()
    }

    init() {
        let styleMask: NSWindow.StyleMask = [.nonactivatingPanel, .fullSizeContentView, .borderless]
        super.init(contentRect: .zero, styleMask: styleMask, backing: .buffered, defer: false)
        SharedPreviewWindowCoordinator.activeInstance = self
        setupWindow()
        setupSearchWindow()
        setupFrameRefreshObserver()
        for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification, NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification, NSWindow.didExposeNotification] {
            NotificationCenter.default.addObserver(self, selector: #selector(publishTapSnapshot), name: name, object: nil)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(panelDidResize), name: NSWindow.didResizeNotification, object: self)
    }

    deinit {
        if SharedPreviewWindowCoordinator.activeInstance === self {
            SharedPreviewWindowCoordinator.activeInstance = nil
        }
        dockManager.cleanup()
    }

    private func setupWindow() {
        level = Defaults[.raisedWindowLevel] ? .statusBar : .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces, .transient, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        animationBehavior = .none
    }

    private func setupSearchWindow() {
        if Defaults[.enableWindowSwitcherSearch] {
            if searchWindow == nil {
                searchWindow = SearchWindow(previewCoordinator: windowSwitcherCoordinator)
            }
        } else {
            searchWindow?.hideSearch()
            searchWindow = nil
        }
    }

    private func setupFrameRefreshObserver() {
        windowSwitcherCoordinator.onFrameRefreshNeeded = { [weak self] in
            self?.refreshPanelFrameToFitContent()
        }
    }

    func updateSearchWindow(with text: String) {
        guard Defaults[.enableWindowSwitcherSearch] else { return }
        if searchWindow == nil { setupSearchWindow() }
        if searchWindow?.isFocused != true {
            searchWindow?.updateSearchText(text)
        }
    }

    func focusSearchWindow() {
        guard Defaults[.enableWindowSwitcherSearch] else { return }
        if searchWindow == nil { setupSearchWindow() }
        guard let searchWindow else { return }
        searchWindow.showSearch(relativeTo: self)
        searchWindow.focusSearchField()
        publishTapSnapshot()
    }

    var isSearchWindowFocused: Bool {
        searchWindow?.isFocused ?? false
    }

    var searchWindowFrame: NSRect? {
        guard let searchWindow, searchWindow.isVisible else { return nil }
        return searchWindow.frame
    }

    func containsQuartzPoint(_ point: CGPoint) -> Bool {
        let snapshot = tapSnapshot
        guard snapshot.isVisible else { return false }

        let screen = NSScreen.screenFromQuartzPoint(point)
        let appKitPoint = DockObserver.nsPointFromCGPoint(point, forScreen: screen)
        let hitSlop: CGFloat = 2

        return [snapshot.frame, snapshot.fullPreviewFrame, snapshot.searchFrame]
            .compactMap { $0 }
            .contains { $0.insetBy(dx: -hitSlop, dy: -hitSlop).contains(appKitPoint) }
    }

    private func isCalendarApp(bundleIdentifier: String?) -> Bool {
        guard let bundleId = bundleIdentifier else { return false }
        return bundleId == calendarAppIdentifier
    }

    @MainActor private func getEmbeddedContentType(for bundleIdentifier: String?) -> EmbeddedContentType {
        guard let bundleId = bundleIdentifier else { return .none }

        if isMediaApp(bundleId) {
            return .media(bundleIdentifier: bundleId)
        } else if isCalendarApp(bundleIdentifier: bundleId) {
            return .calendar(bundleIdentifier: bundleId)
        }

        return .none
    }

    func cancelPendingShow() {
        pendingShowWorkItem?.cancel()
        pendingShowWorkItem = nil
        pendingShow = nil
    }

    func restoreDockAutoHideState() {
        dockManager.restoreDockState()
    }

    func hideWindow(cancelPendingShow shouldCancelPendingShow: Bool = true) {
        if shouldCancelPendingShow {
            cancelPendingShow()
        }

        // Always restore dock auto-hide state, even if the preview isn't visible.
        restoreDockAutoHideState()
        hideFullPreviewWindow()

        guard isVisible else { return }

        DragPreviewCoordinator.shared.endDragging()

        searchWindow?.hideSearch()

        if let currentContent = contentView {
            currentContent.removeFromSuperview()
        }
        contentView = nil
        appName = ""
        currentlyDisplayedPID = nil
        mouseIsWithinPreviewWindow = false
        anchoredDockItem = nil
        panelAnchor = nil

        let currentDockPos = DockUtils.getDockPosition()
        let currentScreen = NSScreen.main ?? NSScreen.screens.first!
        windowSwitcherCoordinator.setWindows([], dockPosition: currentDockPos, bestGuessMonitor: currentScreen)
        windowSwitcherCoordinator.setShowing(.both, toState: false)
        orderOut(nil)
        publishTapSnapshot()
    }

    /// Merges fresh windows if currently displaying the expected app.
    @MainActor
    @discardableResult
    func mergeWindowsIfNeeded(_ pid: pid_t? = nil, windows: [WindowInfo], dockPosition: DockPosition, bestGuessMonitor: NSScreen, stageManagerProtection: Bool) -> Bool {
        guard WindowUtil.isCurrentStageManagerProtection(stageManagerProtection) else { return false }
        if let pid, pendingShow?.pid == pid, pendingShow?.stageManagerProtection == stageManagerProtection {
            pendingShow?.freshWindows = windows
            return true
        }
        guard windowSwitcherCoordinator.stageManagerProtectionEnabled == stageManagerProtection,
              windowSwitcherCoordinator.windowSwitcherActive || currentlyDisplayedPID == pid
        else { return false }
        windowSwitcherCoordinator.mergeWindows(windows, dockPosition: dockPosition, bestGuessMonitor: bestGuessMonitor)
        return true
    }

    /// Refreshes the panel frame to match SwiftUI content's intrinsic size after window count changes.
    @MainActor
    private func refreshPanelFrameToFitContent() {
        guard let hostingView = contentView else { return }

        hostingView.layoutSubtreeIfNeeded()

        guard let panelAnchor else { return }
        let visibleFrame = panelAnchor.screen.visibleFrame
        let fittingSize = hostingView.fittingSize
        let newSize = CGSize(width: min(fittingSize.width, visibleFrame.width), height: min(fittingSize.height, visibleFrame.height))
        guard let newOrigin = anchoredOrigin(for: newSize) else { return }
        let targetFrame = CGRect(origin: newOrigin, size: newSize)
        guard targetFrame != frame else { return }

        let searchFrame = searchWindow.flatMap { $0.isVisible ? $0.targetFrame(relativeTo: targetFrame, on: self.screen ?? panelAnchor.screen) : nil }
        animateWithUserPreference {
            self.animator().setFrame(targetFrame, display: true)
            if let searchFrame { self.searchWindow?.animator().setFrame(searchFrame, display: true) }
        }
    }

    private func anchoredOrigin(for size: CGSize) -> CGPoint? {
        guard let panelAnchor else { return nil }
        let screenFrame = panelAnchor.screen.frame
        var origin = panelAnchor.origin(size)
        origin.x = max(screenFrame.minX, min(origin.x, screenFrame.maxX - size.width))
        origin.y = max(screenFrame.minY, min(origin.y, screenFrame.maxY - size.height))
        return origin
    }

    @objc private func panelDidResize() {
        guard let origin = anchoredOrigin(for: frame.size),
              abs(origin.x - frame.minX) > 0.5 || abs(origin.y - frame.minY) > 0.5
        else { return }
        setFrameOrigin(origin)
        if let searchWindow, searchWindow.isVisible {
            searchWindow.showSearch(relativeTo: self)
        }
    }

    @MainActor
    private func performShowView(_ view: some View,
                                 mouseLocation: CGPoint?,
                                 mouseScreen: NSScreen,
                                 dockItemElement: AXUIElement?,
                                 dockIconRect: CGRect?,
                                 dockPositionOverride: DockPosition? = nil,
                                 dockItemFrameOverride: CGRect? = nil)
    {
        let hostingView = NSHostingView(rootView: view)

        if let oldContentView = contentView {
            oldContentView.removeFromSuperview()
        }
        contentView = hostingView

        let newHoverWindowSize = hostingView.fittingSize
        let isDockIconAnchored = dockItemElement != nil && dockIconRect != nil

        let origin: (CGSize) -> CGPoint = if isDockIconAnchored, let dockIconRect {
            { [unowned self] in calculateWindowPosition(mouseLocation: mouseLocation, windowSize: $0, screen: mouseScreen, dockIconRect: dockIconRect, dockPositionOverride: dockPositionOverride) }
        } else if let dockItemFrameOverride {
            { [unowned self] in calculateWindowPositionFromFrame(mouseLocation: mouseLocation, windowSize: $0, screen: mouseScreen, dockItemFrame: dockItemFrameOverride, dockPositionOverride: dockPositionOverride) }
        } else {
            { [unowned self] in centerWindowOnScreen(size: $0, screen: mouseScreen) }
        }
        let position = origin(newHoverWindowSize)

        // Prevent rendering if position calculation failed for cmd-tab
        if isDockIconAnchored, dockPositionOverride == .cmdTab, position == .zero {
            if let oldContentView = contentView {
                oldContentView.removeFromSuperview()
            }
            contentView = nil
            return
        }

        let finalFrame = CGRect(origin: position, size: newHoverWindowSize)
        panelAnchor = nil
        applyWindowFrame(finalFrame, animated: true, dockPositionOverride: dockPositionOverride)
        previousHoverWindowOrigin = position
        panelAnchor = (mouseScreen, origin)
    }

    @MainActor
    private func updateContentViewSizeAndPosition(mouseLocation: CGPoint? = nil, mouseScreen: NSScreen, dockItemElement: AXUIElement?,
                                                  dockIconRect: CGRect? = nil,
                                                  animated: Bool, centerOnScreen: Bool = false,
                                                  centeredHoverWindowState: PreviewStateCoordinator.WindowState? = nil,
                                                  embeddedContentType: EmbeddedContentType = .none,
                                                  dockPositionOverride: DockPosition? = nil,
                                                  dockItemFrameOverride: CGRect? = nil,
                                                  renderStartTime: CFAbsoluteTime? = nil)
    {
        var elapsed = renderStartTime.map { (CFAbsoluteTimeGetCurrent() - $0) * 1000 } ?? 0
        DebugLogger.log("PreviewRender", details: "updateContentView start (+\(String(format: "%.1f", elapsed))ms)")

        windowSwitcherCoordinator.setShowing(centeredHoverWindowState, toState: centerOnScreen)

        // Defer showing the search window until after the hover window frame is applied

        let updateAvailable = (NSApp.delegate as? AppDelegate)?.updaterState.anUpdateIsAvailable ?? false

        elapsed = renderStartTime.map { (CFAbsoluteTimeGetCurrent() - $0) * 1000 } ?? 0

        let hoverView = WindowPreviewHoverContainer(appName: appName,
                                                    onWindowTap: onWindowTap,
                                                    dockPosition: dockPositionOverride ?? DockUtils.getDockPosition(),
                                                    mouseLocation: mouseLocation,
                                                    bestGuessMonitor: mouseScreen,
                                                    dockItemElement: dockItemElement,
                                                    dockItemFrameOverride: dockItemFrameOverride,
                                                    windowSwitcherCoordinator: windowSwitcherCoordinator,
                                                    mockPreviewActive: false,
                                                    updateAvailable: updateAvailable,
                                                    embeddedContentType: embeddedContentType,
                                                    hasScreenRecordingPermission: hasScreenRecordingPermission)
        let newHostingView = NSHostingView(rootView: hoverView)

        if let oldContentView = contentView {
            oldContentView.removeFromSuperview()
        }
        contentView = newHostingView

        elapsed = renderStartTime.map { (CFAbsoluteTimeGetCurrent() - $0) * 1000 } ?? 0
        DebugLogger.log("PreviewRender", details: "calculating fittingSize (+\(String(format: "%.1f", elapsed))ms)")

        let newHoverWindowSize: CGSize
        do {
            let expectedContentSize = windowSwitcherCoordinator.expectedContentSize
            let targetSize: CGSize
            if windowSwitcherCoordinator.windowSwitcherActive,
               windowSwitcherCoordinator.expectedContentSizeIsExact,
               expectedContentSize != .zero
            {
                targetSize = expectedContentSize

                elapsed = renderStartTime.map { (CFAbsoluteTimeGetCurrent() - $0) * 1000 } ?? 0
                DebugLogger.log("PreviewRender", details: "using predicted size, fittingSize skipped: \(targetSize) (+\(String(format: "%.1f", elapsed))ms)")
            } else {
                let fittingSize = newHostingView.fittingSize

                elapsed = renderStartTime.map { (CFAbsoluteTimeGetCurrent() - $0) * 1000 } ?? 0
                DebugLogger.log("PreviewRender", details: "fittingSize done: \(fittingSize) (+\(String(format: "%.1f", elapsed))ms)")

                targetSize = expectedContentSize == .zero
                    ? fittingSize
                    : CGSize(
                        width: max(fittingSize.width, expectedContentSize.width),
                        height: max(fittingSize.height, expectedContentSize.height)
                    )
            }
            newHoverWindowSize = CGSize(
                width: min(targetSize.width, mouseScreen.visibleFrame.width),
                height: min(targetSize.height, mouseScreen.visibleFrame.height)
            )
        }

        let isDockIconAnchored = !centerOnScreen && dockItemElement != nil && dockIconRect != nil

        let origin: (CGSize) -> CGPoint = if centerOnScreen {
            { [unowned self] in centerWindowOnScreen(size: $0, screen: mouseScreen) }
        } else if isDockIconAnchored, let dockIconRect {
            { [unowned self] in calculateWindowPosition(mouseLocation: mouseLocation, windowSize: $0, screen: mouseScreen, dockIconRect: dockIconRect, dockPositionOverride: dockPositionOverride) }
        } else if let dockItemFrameOverride {
            { [unowned self] in calculateWindowPositionFromFrame(mouseLocation: mouseLocation, windowSize: $0, screen: mouseScreen, dockItemFrame: dockItemFrameOverride, dockPositionOverride: dockPositionOverride) }
        } else if let mouseLocation, dockPositionOverride == .cli {
            { [unowned self] in calculateWindowPositionFromMouse(mouseLocation: mouseLocation, windowSize: $0, screen: mouseScreen) }
        } else {
            { [unowned self] in centerWindowOnScreen(size: $0, screen: mouseScreen) }
        }
        let position = origin(newHoverWindowSize)

        // Prevent rendering if position calculation failed for cmd-tab
        if isDockIconAnchored, dockPositionOverride == .cmdTab, position == .zero {
            if let oldContentView = contentView {
                oldContentView.removeFromSuperview()
            }
            contentView = nil
            return
        }

        let finalFrame = CGRect(origin: position, size: newHoverWindowSize)

        panelAnchor = nil
        setFrame(finalFrame, display: false)
        applyWindowFrame(finalFrame, animated: animated, dockPositionOverride: dockPositionOverride)
        previousHoverWindowOrigin = position
        panelAnchor = (mouseScreen, origin)

        elapsed = renderStartTime.map { (CFAbsoluteTimeGetCurrent() - $0) * 1000 } ?? 0
        DebugLogger.log("PreviewRender", details: "window frame applied, render complete (+\(String(format: "%.1f", elapsed))ms)")

        // Now that the main panel has a valid frame, position the search window (if active)
        if windowSwitcherCoordinator.windowSwitcherActive, Defaults[.enableWindowSwitcherSearch] {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if searchWindow == nil { setupSearchWindow() }
                searchWindow?.showSearch(relativeTo: self)
                publishTapSnapshot()
            }
        }
    }

    func beginFullPreviewHover() -> UUID? {
        guard isVisible, !windowSwitcherCoordinator.windowSwitcherActive else { return nil }
        hideFullPreviewWindow()
        let hoverID = UUID()
        activeFullPreviewHoverID = hoverID
        return hoverID
    }

    func cancelFullPreviewHover(_ hoverID: UUID) {
        guard activeFullPreviewHoverID == hoverID else { return }
        hideFullPreviewWindow()
    }

    func isFullPreviewHoverActive(_ hoverID: UUID?) -> Bool {
        isVisible && hoverID != nil && activeFullPreviewHoverID == hoverID
    }

    @MainActor
    private func showFullPreviewWindow(for windowInfo: WindowInfo, on screen: NSScreen) {
        if fullPreviewWindow == nil {
            let styleMask: NSWindow.StyleMask = [.nonactivatingPanel, .fullSizeContentView, .borderless]
            fullPreviewWindow = NSPanel(contentRect: .zero, styleMask: styleMask, backing: .buffered, defer: false)
            fullPreviewWindow?.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue - 1)
            fullPreviewWindow?.isOpaque = false
            fullPreviewWindow?.backgroundColor = .clear
            fullPreviewWindow?.hasShadow = true
            fullPreviewWindow?.collectionBehavior = [.canJoinAllSpaces, .transient, .fullScreenAuxiliary]
            fullPreviewWindow?.hidesOnDeactivate = false
            fullPreviewWindow?.becomesKeyOnlyIfNeeded = true
            fullPreviewWindow?.animationBehavior = .none
        }

        let windowSize = (try? windowInfo.axElement.size()) ?? CGSize(width: screen.frame.width, height: screen.frame.height)
        let axPosition = (try? windowInfo.axElement.position()) ?? CGPoint(x: screen.frame.midX, y: screen.frame.midY)

        let convertedPosition = DockObserver.cgPointFromNSPoint(axPosition, forScreen: screen)
        let adjustedPosition = CGPoint(x: convertedPosition.x, y: convertedPosition.y - windowSize.height)

        let flippedIconRect = CGRect(origin: adjustedPosition, size: windowSize)

        let previewView = FullSizePreviewView(windowInfo: windowInfo, windowSize: windowSize, previewStateCoordinator: windowSwitcherCoordinator)
        let hostingView = NSHostingView(rootView: previewView)

        if let oldFullPreviewContent = fullPreviewWindow?.contentView {
            oldFullPreviewContent.removeFromSuperview()
        }
        fullPreviewWindow?.contentView = hostingView

        fullPreviewWindow?.setFrame(flippedIconRect, display: true)
        fullPreviewWindow?.makeKeyAndOrderFront(nil)
        publishTapSnapshot()
    }

    @MainActor
    func hideFullPreviewWindow() {
        activeFullPreviewHoverID = nil
        fullPreviewWindow?.orderOut(nil)
        if let currentFullPreviewContent = fullPreviewWindow?.contentView {
            currentFullPreviewContent.removeFromSuperview()
        }
        fullPreviewWindow?.contentView = nil
        fullPreviewWindow = nil
        publishTapSnapshot()
    }

    private func centerWindowOnScreen(size: CGSize, screen: NSScreen) -> CGPoint {
        let switcherOffsetConfigured = Defaults[.enableShiftWindowSwitcherPlacement]

        let horizontalOffset = switcherOffsetConfigured ? screen.frame.width * (Defaults[.windowSwitcherHorizontalOffsetPercent] / 100.0) : 0
        let verticalOffset = switcherOffsetConfigured ? screen.frame.height * (Defaults[.windowSwitcherVerticalOffsetPercent] / 100.0) : 0

        let xPosition = screen.frame.midX - (size.width / 2) + horizontalOffset
        let yPosition: CGFloat = if switcherOffsetConfigured, Defaults[.windowSwitcherAnchorToTop] {
            // Anchor from top: start at top of screen and apply offset downward (negative offset moves down)
            screen.frame.maxY - size.height + verticalOffset
        } else {
            // Center vertically with offset
            screen.frame.midY - (size.height / 2) + verticalOffset
        }

        return CGPoint(x: xPosition, y: yPosition)
    }

    private func calculateWindowPositionFromMouse(mouseLocation: CGPoint, windowSize: CGSize, screen: NSScreen) -> CGPoint {
        let screenFrame = screen.frame
        let buffer: CGFloat = 10

        var xPosition = mouseLocation.x - (windowSize.width / 2)
        var yPosition = mouseLocation.y + buffer

        xPosition = max(screenFrame.minX, min(xPosition, screenFrame.maxX - windowSize.width))
        yPosition = max(screenFrame.minY, min(yPosition, screenFrame.maxY - windowSize.height))

        return CGPoint(x: xPosition, y: yPosition)
    }

    private func calculateWindowPosition(mouseLocation: CGPoint?, windowSize: CGSize, screen: NSScreen, dockIconRect: CGRect, dockPositionOverride: DockPosition? = nil) -> CGPoint {
        guard let mouseLocation else { return .zero }
        let screenFrame = screen.frame
        let dockPosition = dockPositionOverride ?? DockUtils.getDockPosition()

        // Use the anchored icon rect when anchoring is enabled, otherwise use the freshly captured rect
        let iconRect = (Defaults[.anchorDockPreviewPosition] ? anchoredDockItem?.iconRect : nil) ?? dockIconRect
        let flippedIconRect = CGRect(
            origin: DockObserver.cgPointFromNSPoint(iconRect.origin, forScreen: screen),
            size: iconRect.size
        )

        var xPosition: CGFloat
        var yPosition: CGFloat

        switch dockPosition {
        case .bottom, .cmdTab:
            xPosition = flippedIconRect.midX - (windowSize.width / 2)
            yPosition = flippedIconRect.minY
        case .left:
            xPosition = flippedIconRect.maxX
            yPosition = flippedIconRect.midY - (windowSize.height / 2) - flippedIconRect.height
        case .right:
            xPosition = flippedIconRect.minX - windowSize.width
            yPosition = flippedIconRect.midY - (windowSize.height / 2) - flippedIconRect.height
        default:
            xPosition = mouseLocation.x - (windowSize.width / 2)
            yPosition = mouseLocation.y - (windowSize.height / 2)
        }

        let bufferFromDock = Defaults[.bufferFromDock]
        switch dockPosition {
        case .left:
            xPosition += bufferFromDock
        case .right:
            xPosition -= bufferFromDock
        case .bottom:
            yPosition += bufferFromDock
        case .cmdTab:
            yPosition += 5
        default:
            break
        }

        xPosition = max(screenFrame.minX, min(xPosition, screenFrame.maxX - windowSize.width))
        yPosition = max(screenFrame.minY, min(yPosition, screenFrame.maxY - windowSize.height))

        return CGPoint(x: xPosition, y: yPosition)
    }

    private func calculateWindowPositionFromFrame(mouseLocation: CGPoint?, windowSize: CGSize, screen: NSScreen, dockItemFrame: CGRect, dockPositionOverride: DockPosition? = nil) -> CGPoint {
        let screenFrame = screen.frame
        let dockPosition = dockPositionOverride ?? DockUtils.getDockPosition()
        let flippedIconRect = dockItemFrame

        var xPosition: CGFloat
        var yPosition: CGFloat

        switch dockPosition {
        case .bottom, .cmdTab, .cli:
            xPosition = flippedIconRect.midX - (windowSize.width / 2)
            yPosition = flippedIconRect.maxY
        case .left:
            xPosition = flippedIconRect.maxX
            yPosition = flippedIconRect.midY - (windowSize.height / 2)
        case .right:
            xPosition = flippedIconRect.minX - windowSize.width
            yPosition = flippedIconRect.midY - (windowSize.height / 2)
        default:
            if let mouseLocation {
                xPosition = mouseLocation.x - (windowSize.width / 2)
                yPosition = mouseLocation.y - (windowSize.height / 2)
            } else {
                xPosition = flippedIconRect.midX - (windowSize.width / 2)
                yPosition = flippedIconRect.maxY
            }
        }

        let bufferFromDock = Defaults[.bufferFromDock]
        switch dockPosition {
        case .left:
            xPosition += bufferFromDock
        case .right:
            xPosition -= bufferFromDock
        case .bottom, .cli:
            yPosition += bufferFromDock
        case .cmdTab:
            yPosition += 5
        default:
            break
        }

        xPosition = max(screenFrame.minX, min(xPosition, screenFrame.maxX - windowSize.width))
        yPosition = max(screenFrame.minY, min(yPosition, screenFrame.maxY - windowSize.height))

        return CGPoint(x: xPosition, y: yPosition)
    }

    @MainActor
    private func applyWindowFrame(_ frame: CGRect, animated: Bool, dockPositionOverride: DockPosition? = nil) {
        let shouldAnimate = animated && Defaults[.showAnimations]

        setFrame(frame, display: true)
        alphaValue = 1.0
        makeKeyAndOrderFront(nil)
        publishTapSnapshot()

        if shouldAnimate, let layer = contentView?.layer {
            let animationOffset: CGFloat = 7.0
            let downward: CGFloat = contentView?.superview?.isFlipped == true ? animationOffset : -animationOffset
            let offset = switch dockPositionOverride ?? DockUtils.getDockPosition() {
            case .left: CGSize(width: -animationOffset, height: 0)
            case .right: CGSize(width: animationOffset, height: 0)
            default: CGSize(width: 0, height: downward)
            }

            let slide = CABasicAnimation(keyPath: "transform.translation")
            slide.fromValue = NSValue(size: offset)
            slide.toValue = NSValue(size: .zero)
            slide.isAdditive = true
            slide.duration = 0.175
            slide.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            layer.add(slide, forKey: "slideIn")
        }
    }

    @MainActor
    private func performDisplay(
        appName: String,
        windows: [WindowInfo],
        mouseLocation: CGPoint?,
        mouseScreen: NSScreen?,
        dockItemElement: AXUIElement?,
        centeredHoverWindowState: PreviewStateCoordinator.WindowState?,
        onWindowTap: (() -> Void)?,
        bundleIdentifier: String?,
        dockPositionOverride: DockPosition? = nil,
        initialIndex: Int? = nil,
        dockItemFrameOverride: CGRect? = nil,
        renderStartTime: CFAbsoluteTime? = nil,
        stageManagerProtection: Bool,
        hasFreshWindows: Bool
    ) {
        guard WindowUtil.isCurrentStageManagerProtection(stageManagerProtection) else { return }
        windowSwitcherCoordinator.setStageManagerProtection(stageManagerProtection)
        let elapsed = renderStartTime.map { (CFAbsoluteTimeGetCurrent() - $0) * 1000 } ?? 0
        DebugLogger.log("PreviewRender", details: "performDisplay start (+\(String(format: "%.1f", elapsed))ms)")

        var dockIconRect: CGRect?
        if let dockItemElement,
           let pos = try? dockItemElement.position(),
           let size = try? dockItemElement.size()
        {
            dockIconRect = CGRect(origin: pos, size: size)
        }

        let screen = mouseScreen ?? NSScreen.main!
        var finalEmbeddedContentType: EmbeddedContentType = .none
        var useBigStandaloneViewInstead = false
        var viewForBigStandalone: AnyView?
        let widgetsAreFiltered = WindowUtil.matchesAppFilters(
            bundleIdentifier: bundleIdentifier,
            appName: appName,
            filters: Defaults[.widgetAppFilters]
        )

        if let bundleId = bundleIdentifier, !widgetsAreFiltered {
            let actualAppContentType = getEmbeddedContentType(for: bundleId)

            switch actualAppContentType {
            case let .media(mediaBundleId):
                if Defaults[.showSpecialAppControls], Defaults[.enableMediaWidget] {
                    let hasValidWindows = windows.contains { !$0.isMinimized && !$0.isHidden }
                    let shouldUseBigControlsForNoValidWindows = Defaults[.showBigControlsWhenNoValidWindows] &&
                        (windows.isEmpty || !hasValidWindows)

                    if Defaults[.useEmbeddedMediaControls], !shouldUseBigControlsForNoValidWindows {
                        finalEmbeddedContentType = .media(bundleIdentifier: mediaBundleId)
                    } else {
                        useBigStandaloneViewInstead = true
                        viewForBigStandalone = AnyView(MediaControlsView(
                            appName: appName,
                            bundleIdentifier: mediaBundleId,
                            dockPosition: dockPositionOverride ?? DockUtils.getDockPosition(),
                            bestGuessMonitor: screen,
                            dockItemElement: dockItemElement,
                            isEmbeddedMode: false
                        ))
                    }
                }
            case let .calendar(calendarBundleId):
                if Defaults[.showSpecialAppControls], Defaults[.enableCalendarWidget] {
                    let hasValidWindows = windows.contains { !$0.isMinimized && !$0.isHidden }
                    let shouldUseBigControlsForNoValidWindows = Defaults[.showBigControlsWhenNoValidWindows] &&
                        (windows.isEmpty || !hasValidWindows)

                    if Defaults[.useEmbeddedMediaControls], !shouldUseBigControlsForNoValidWindows {
                        finalEmbeddedContentType = .calendar(bundleIdentifier: calendarBundleId)
                    } else {
                        useBigStandaloneViewInstead = true
                        viewForBigStandalone = AnyView(CalendarView(
                            appName: appName,
                            bundleIdentifier: calendarBundleId,
                            dockPosition: dockPositionOverride ?? DockUtils.getDockPosition(),
                            bestGuessMonitor: screen,
                            dockItemElement: dockItemElement,
                            isEmbeddedMode: false
                        ))
                    }
                }
            case .none:
                break
            }
        }

        if let dockItemElement {
            let newPID = windows.first?.app.processIdentifier ?? (try? dockItemElement.pid())
            if newPID != currentlyDisplayedPID {
                anchoredDockItem = nil
            } else if anchoredDockItem?.element == dockItemElement, isVisible {
                if hasFreshWindows {
                    windowSwitcherCoordinator.mergeWindows(windows, dockPosition: dockPositionOverride ?? DockUtils.getDockPosition(), bestGuessMonitor: screen)
                }
                return
            }
            currentlyDisplayedPID = newPID
            if let dockIconRect {
                anchoredDockItem = (element: dockItemElement, iconRect: dockIconRect)
            }
        }

        if useBigStandaloneViewInstead, let viewToShow = viewForBigStandalone {
            performShowView(viewToShow, mouseLocation: mouseLocation, mouseScreen: screen, dockItemElement: dockItemElement, dockIconRect: dockIconRect, dockPositionOverride: dockPositionOverride, dockItemFrameOverride: dockItemFrameOverride)
        } else {
            performShowWindow(
                appName: appName,
                windows: windows,
                mouseLocation: mouseLocation,
                mouseScreen: screen,
                dockItemElement: dockItemElement,
                dockIconRect: dockIconRect,
                centeredHoverWindowState: centeredHoverWindowState,
                onWindowTap: onWindowTap,
                embeddedContentType: finalEmbeddedContentType,
                dockPositionOverride: dockPositionOverride,
                initialIndex: initialIndex,
                dockItemFrameOverride: dockItemFrameOverride,
                renderStartTime: renderStartTime
            )
        }

        dockManager.preventDockHiding(centeredHoverWindowState != nil)
    }

    @MainActor
    private func performShowWindow(appName: String, windows: [WindowInfo], mouseLocation: CGPoint?,
                                   mouseScreen: NSScreen?, dockItemElement: AXUIElement?,
                                   dockIconRect: CGRect?,
                                   centeredHoverWindowState: PreviewStateCoordinator.WindowState? = nil,
                                   onWindowTap: (() -> Void)?,
                                   embeddedContentType: EmbeddedContentType = .none,
                                   dockPositionOverride: DockPosition? = nil, initialIndex: Int? = nil,
                                   dockItemFrameOverride: CGRect? = nil,
                                   renderStartTime: CFAbsoluteTime? = nil)
    {
        guard !windows.isEmpty else { return }

        let shouldCenterOnScreen = centeredHoverWindowState != .none

        let screen = mouseScreen ?? NSScreen.main!
        if centeredHoverWindowState == .fullWindowPreview {
            guard let windowInfo = windows.first,
                  let windowPosition = try? windowInfo.axElement.position(),
                  let windowScreen = windowPosition.screen() else { return }
            showFullPreviewWindow(for: windowInfo, on: windowScreen)
        } else {
            hideFullPreviewWindow()
            self.appName = appName
            let activeDockPosition = dockPositionOverride ?? DockUtils.getDockPosition()

            windowSwitcherCoordinator.hasEmbeddedContent = embeddedContentType != .none
            windowSwitcherCoordinator.setWindows(windows, dockPosition: activeDockPosition, bestGuessMonitor: screen)

            if let initialIndex {
                windowSwitcherCoordinator.setIndex(to: initialIndex, shouldScroll: false)
            } else {
                windowSwitcherCoordinator.currIndex = -1
            }

            self.onWindowTap = onWindowTap

            updateContentViewSizeAndPosition(mouseLocation: mouseLocation, mouseScreen: screen, dockItemElement: dockItemElement, dockIconRect: dockIconRect, animated: !shouldCenterOnScreen,
                                             centerOnScreen: shouldCenterOnScreen, centeredHoverWindowState: centeredHoverWindowState,
                                             embeddedContentType: embeddedContentType, dockPositionOverride: dockPositionOverride,
                                             dockItemFrameOverride: dockItemFrameOverride, renderStartTime: renderStartTime)
        }
    }

    @MainActor
    func cycleWindows(goBackwards: Bool) {
        windowSwitcherCoordinator.setStageManagerProtection(WindowUtil.stageManagerProtectionEnabled())
        let coordinator = windowSwitcherCoordinator
        guard !coordinator.windows.isEmpty else { return }

        if coordinator.windowSwitcherActive, coordinator.hasActiveSearch {
            return
        }

        if goBackwards {
            coordinator.cycleBackward()
        } else {
            coordinator.cycleForward()
        }
    }

    @MainActor
    func selectAndBringToFrontCurrentWindow() {
        let coordinator = windowSwitcherCoordinator
        let currentIndex = coordinator.currIndex

        guard currentIndex >= 0, currentIndex < coordinator.windows.count else {
            hideWindow()
            return
        }

        let selectedWindow = coordinator.windows[currentIndex]
        selectedWindow.bringToFront()
        selectedWindow.warpMouseToCenterIfNeeded()

        if selectedWindow.isWindowlessApp, Defaults[.openNewWindowForWindowlessApps] {
            WindowUtil.activateAndOpenNewWindow(app: selectedWindow.app)
        }

        hideWindow()
    }

    @MainActor
    func navigateWithArrowKey(direction: ArrowDirection) {
        windowSwitcherCoordinator.setStageManagerProtection(WindowUtil.stageManagerProtectionEnabled())
        let coordinator = windowSwitcherCoordinator
        guard !coordinator.windows.isEmpty else { return }

        coordinator.hasMovedSinceOpen = false
        coordinator.initialHoverLocation = nil

        let threshold = Defaults[.windowSwitcherCompactThreshold]
        let forcedCompact = Defaults[.disableImagePreview] || !hasScreenRecordingPermission
        let isListViewMode = coordinator.windowSwitcherActive
            && (forcedCompact || (threshold > 0 && coordinator.windows.count >= threshold))

        // Handle list view navigation (up/down only, with filtering support)
        if isListViewMode {
            let filteredIndices = coordinator.filteredWindowIndices()
            let indicesToUse = coordinator.hasActiveSearch ? filteredIndices : Array(coordinator.windows.indices)
            guard !indicesToUse.isEmpty else { return }

            let currentPos = indicesToUse.firstIndex(of: coordinator.currIndex) ?? 0
            let newPos: Int = switch direction {
            case .up, .left:
                currentPos > 0 ? currentPos - 1 : indicesToUse.count - 1
            case .down, .right:
                (currentPos + 1) % indicesToUse.count
            }
            coordinator.setIndex(to: indicesToUse[newPos])
            return
        }

        // Handle filtered navigation when search is active
        if coordinator.windowSwitcherActive, coordinator.hasActiveSearch {
            coordinator.navigateFiltered(direction: direction)
            return
        }

        if coordinator.currIndex < 0 {
            coordinator.setIndex(to: 0)
            return
        }

        let dockPosition = DockUtils.getDockPosition()
        let newIndex = WindowPreviewHoverContainer.navigateWindowSwitcher(
            from: coordinator.currIndex,
            direction: direction,
            totalItems: coordinator.windows.count,
            dockPosition: dockPosition,
            isWindowSwitcherActive: coordinator.windowSwitcherActive
        )
        coordinator.setIndex(to: newIndex)
    }

    @MainActor
    @discardableResult
    func performActionOnCurrentWindow(action: WindowAction) -> Bool {
        let coordinator = windowSwitcherCoordinator
        guard coordinator.currIndex >= 0, coordinator.currIndex < coordinator.windows.count else {
            return false
        }

        let window = coordinator.windows[coordinator.currIndex]
        let originalIndex = coordinator.currIndex

        let result = action.perform(on: window, keepPreviewOnQuit: true)

        switch result {
        case .dismissed:
            hideWindow()
            return false
        case let .windowUpdated(updatedWindow):
            coordinator.updateWindow(at: originalIndex, with: updatedWindow)
        case .windowRemoved:
            coordinator.removeWindow(at: originalIndex)
        case let .appWindowsRemoved(pid):
            for i in stride(from: coordinator.windows.count - 1, through: 0, by: -1) {
                if coordinator.windows[i].app.processIdentifier == pid {
                    coordinator.removeWindow(at: i)
                }
            }
        case .noChange:
            break
        }
        return true
    }

    func showFolderWidget(
        folderURL: URL,
        folderName: String,
        mouseLocation: CGPoint? = nil,
        mouseScreen: NSScreen? = nil,
        dockItemElement: AXUIElement?
    ) {
        let shouldSkipDelay = Defaults[.useDelayOnlyForInitialOpen] && isVisible
        let delay = shouldSkipDelay ? 0 : Defaults[.hoverWindowOpenDelay]

        pendingShowWorkItem?.cancel()
        pendingShow = nil
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }

            if let dockItemElement {
                guard let currentDockItem = DockObserver.activeInstance?.getHoveredDockItemElement(),
                      currentDockItem == dockItemElement
                else { return }
            }

            Task { @MainActor [weak self] in
                guard let self else { return }

                let screen = mouseScreen ?? NSScreen.main!
                let activeDockPosition = DockUtils.getDockPosition()
                appName = folderName
                currentlyDisplayedPID = nil
                onWindowTap = nil
                hideFullPreviewWindow()
                searchWindow?.hideSearch()
                windowSwitcherCoordinator.setWindows([], dockPosition: activeDockPosition, bestGuessMonitor: screen)
                windowSwitcherCoordinator.setShowing(.both, toState: false)

                var dockIconRect: CGRect?
                if let dockItemElement,
                   let position = try? dockItemElement.position(),
                   let size = try? dockItemElement.size()
                {
                    let rect = CGRect(origin: position, size: size)
                    dockIconRect = rect
                    anchoredDockItem = (element: dockItemElement, iconRect: rect)
                } else {
                    anchoredDockItem = nil
                }

                let view = FolderWidgetContainerView(
                    folderURL: folderURL,
                    folderName: folderName,
                    bestGuessMonitor: screen,
                    dockPosition: activeDockPosition,
                    dockItemElement: dockItemElement,
                    backgroundAppearance: BackgroundAppearance.resolve()
                )

                performShowView(
                    view,
                    mouseLocation: mouseLocation,
                    mouseScreen: screen,
                    dockItemElement: dockItemElement,
                    dockIconRect: dockIconRect,
                    dockPositionOverride: activeDockPosition
                )

                dockManager.preventDockHiding(false)
            }
        }

        pendingShowWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    func showWindow(appName: String, windows: [WindowInfo], mouseLocation: CGPoint? = nil, mouseScreen: NSScreen? = nil,
                    dockItemElement: AXUIElement?,
                    overrideDelay: Bool = false, centeredHoverWindowState: PreviewStateCoordinator.WindowState? = nil,
                    onWindowTap: (() -> Void)? = nil, bundleIdentifier: String? = nil,
                    bypassDockMouseValidation: Bool = false,
                    dockPositionOverride: DockPosition? = nil, initialIndex: Int? = nil,
                    dockItemFrameOverride: CGRect? = nil, fullPreviewHoverID: UUID? = nil,
                    stageManagerProtection: Bool? = nil)
    {
        let stageManagerProtection = stageManagerProtection ?? WindowUtil.stageManagerProtectionEnabled()
        guard WindowUtil.isCurrentStageManagerProtection(stageManagerProtection) else { return }
        let renderStartTime = CFAbsoluteTimeGetCurrent()
        DebugLogger.log("PreviewRender", details: "showWindow called: \(windows.count) windows for \(appName)")

        if centeredHoverWindowState == .fullWindowPreview, !isFullPreviewHoverActive(fullPreviewHoverID) {
            return
        }

        let shouldSkipDelay = overrideDelay || (Defaults[.useDelayOnlyForInitialOpen] && isVisible)
        let delay = shouldSkipDelay ? 0 : Defaults[.hoverWindowOpenDelay]

        pendingShowWorkItem?.cancel()
        let pendingShowID = UUID()
        pendingShow = (pendingShowID, centeredHoverWindowState == nil ? windows.first?.app.processIdentifier : nil, stageManagerProtection, nil)
        let workItem = DispatchWorkItem { [weak self, renderStartTime] in
            guard let self else { return }

            // Check if mouse entered the preview window and we're trying to show a different app
            if mouseIsWithinPreviewWindow,
               let currentPID = currentlyDisplayedPID,
               let expectedBundleId = bundleIdentifier,
               let expectedApp = NSRunningApplication.runningApplications(withBundleIdentifier: expectedBundleId).first,
               currentPID != expectedApp.processIdentifier
            {
                return
            }

            // Final validation: ensure mouse is still over the expected dock item
            if !bypassDockMouseValidation {
                if let expectedBundleId = bundleIdentifier {
                    guard let currentDockItemStatus = DockObserver.activeInstance?.getDockItemAppStatusUnderMouse() else {
                        return
                    }
                    let matches: Bool = switch currentDockItemStatus.status {
                    case let .success(app):
                        app.bundleIdentifier == expectedBundleId
                    case let .notRunning(bundleId):
                        bundleId == expectedBundleId
                    case .notFound:
                        false
                    }
                    guard matches else {
                        return
                    }
                }
            }

            Task { @MainActor [weak self] in
                guard let self else { return }
                if centeredHoverWindowState == .fullWindowPreview, !isFullPreviewHoverActive(fullPreviewHoverID) {
                    return
                }
                var windowsToShow = windows
                var hasFreshWindows = false
                if pendingShow?.id == pendingShowID {
                    hasFreshWindows = pendingShow?.freshWindows != nil
                    windowsToShow = pendingShow?.freshWindows ?? windows
                    pendingShow = nil
                }
                performDisplay(appName: appName, windows: windowsToShow, mouseLocation: mouseLocation, mouseScreen: mouseScreen, dockItemElement: dockItemElement, centeredHoverWindowState: centeredHoverWindowState, onWindowTap: onWindowTap, bundleIdentifier: bundleIdentifier, dockPositionOverride: dockPositionOverride, initialIndex: initialIndex, dockItemFrameOverride: dockItemFrameOverride, renderStartTime: renderStartTime, stageManagerProtection: stageManagerProtection, hasFreshWindows: hasFreshWindows)
            }
        }
        pendingShowWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
}
