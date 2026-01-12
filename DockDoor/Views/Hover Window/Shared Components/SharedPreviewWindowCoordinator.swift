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

    var windowSize: CGSize = getWindowSize()

    private var previousHoverWindowOrigin: CGPoint?
    private var currentDockPosition: DockPosition = .bottom

    private(set) var hasScreenRecordingPermission: Bool = PermissionsChecker.hasScreenRecordingPermission()

    var pinnedWindows: [String: (window: NSWindow, info: PinnedWindowInfo)] = [:]

    init() {
        let styleMask: NSWindow.StyleMask = [.nonactivatingPanel, .fullSizeContentView, .borderless]
        super.init(contentRect: .zero, styleMask: styleMask, backing: .buffered, defer: false)
        SharedPreviewWindowCoordinator.activeInstance = self
        setupWindow()
        setupSearchWindow()
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
    }

    var isSearchWindowFocused: Bool {
        searchWindow?.isFocused ?? false
    }

    private func isMediaApp(bundleIdentifier: String?) -> Bool {
        guard let bundleId = bundleIdentifier else { return false }
        return bundleId == spotifyAppIdentifier || bundleId == appleMusicAppIdentifier
    }

    private func isCalendarApp(bundleIdentifier: String?) -> Bool {
        guard let bundleId = bundleIdentifier else { return false }
        return bundleId == calendarAppIdentifier
    }

    private func getEmbeddedContentType(for bundleIdentifier: String?) -> EmbeddedContentType {
        guard let bundleId = bundleIdentifier else { return .none }

        if isMediaApp(bundleIdentifier: bundleId) {
            return .media(bundleIdentifier: bundleId)
        } else if isCalendarApp(bundleIdentifier: bundleId) {
            return .calendar(bundleIdentifier: bundleId)
        }

        return .none
    }

    func hideWindow() {
        guard isVisible else { return }

        DragPreviewCoordinator.shared.endDragging()
        hideFullPreviewWindow()

        searchWindow?.hideSearch()

        if let currentContent = contentView {
            currentContent.removeFromSuperview()
        }
        contentView = nil
        appName = ""
        currentlyDisplayedPID = nil
        mouseIsWithinPreviewWindow = false

        let currentDockPos = DockUtils.getDockPosition()
        let currentScreen = NSScreen.main ?? NSScreen.screens.first!
        windowSwitcherCoordinator.setWindows([], dockPosition: currentDockPos, bestGuessMonitor: currentScreen)
        windowSwitcherCoordinator.setShowing(.both, toState: false)
        dockManager.restoreDockState()
        orderOut(nil)
    }

    /// Merges fresh windows only if the preview is visible and showing the expected app.
    @MainActor
    @discardableResult
    func mergeWindowsIfShowing(for pid: pid_t, windows: [WindowInfo], dockPosition: DockPosition, bestGuessMonitor: NSScreen) -> Bool {
        guard isVisible, currentlyDisplayedPID == pid else { return false }
        let previousWindowCount = windowSwitcherCoordinator.windows.count
        windowSwitcherCoordinator.mergeWindows(windows, dockPosition: dockPosition, bestGuessMonitor: bestGuessMonitor)

        if windowSwitcherCoordinator.windows.count != previousWindowCount {
            refreshPanelFrameToFitContent()
        }
        return true
    }

    /// Refreshes the panel frame to match SwiftUI content's intrinsic size after window count changes.
    @MainActor
    private func refreshPanelFrameToFitContent() {
        guard let hostingView = contentView else { return }

        hostingView.layoutSubtreeIfNeeded()
        let newSize = hostingView.fittingSize
        guard newSize != frame.size else { return }

        let screen = NSScreen.screenContainingMouse(NSEvent.mouseLocation)
        let screenFrame = screen.frame

        let wasClampedToTop = frame.maxY >= screenFrame.maxY - 1
        let wasClampedToBottom = frame.minY <= screenFrame.minY + 1

        // Anchor based on dock position; if clamped to screen edge, keep that edge fixed
        var newOrigin = switch currentDockPosition {
        case .left:
            if wasClampedToTop {
                CGPoint(x: frame.minX, y: frame.maxY - newSize.height)
            } else if wasClampedToBottom {
                CGPoint(x: frame.minX, y: frame.minY)
            } else {
                CGPoint(x: frame.minX, y: frame.midY - newSize.height / 2)
            }
        case .right:
            if wasClampedToTop {
                CGPoint(x: frame.maxX - newSize.width, y: frame.maxY - newSize.height)
            } else if wasClampedToBottom {
                CGPoint(x: frame.maxX - newSize.width, y: frame.minY)
            } else {
                CGPoint(x: frame.maxX - newSize.width, y: frame.midY - newSize.height / 2)
            }
        case .bottom, .cmdTab:
            CGPoint(x: frame.midX - newSize.width / 2, y: frame.minY)
        default:
            CGPoint(x: frame.midX - newSize.width / 2, y: frame.midY - newSize.height / 2)
        }

        newOrigin.x = max(screenFrame.minX, min(newOrigin.x, screenFrame.maxX - newSize.width))
        newOrigin.y = max(screenFrame.minY, min(newOrigin.y, screenFrame.maxY - newSize.height))

        animateWithUserPreference {
            self.animator().setFrame(CGRect(origin: newOrigin, size: newSize), display: true)
        }
    }

    @MainActor
    private func performShowView(_ view: some View,
                                 mouseLocation: CGPoint?,
                                 mouseScreen: NSScreen,
                                 dockItemElement: AXUIElement?,
                                 dockPositionOverride: DockPosition? = nil,
                                 dockItemFrameOverride: CGRect? = nil)
    {
        let hostingView = NSHostingView(rootView: view)

        if let oldContentView = contentView {
            oldContentView.removeFromSuperview()
        }
        contentView = hostingView

        let newHoverWindowSize = hostingView.fittingSize
        let position: CGPoint

        if let validDockItemElement = dockItemElement {
            position = calculateWindowPosition(mouseLocation: mouseLocation,
                                               windowSize: newHoverWindowSize,
                                               screen: mouseScreen,
                                               dockItemElement: validDockItemElement,
                                               dockPositionOverride: dockPositionOverride)

            // Prevent rendering if position calculation failed for cmd-tab
            if dockPositionOverride == .cmdTab, position == .zero {
                if let oldContentView = contentView {
                    oldContentView.removeFromSuperview()
                }
                contentView = nil
                return
            }
        } else if let frameOverride = dockItemFrameOverride {
            position = calculateWindowPositionFromFrame(mouseLocation: mouseLocation,
                                                        windowSize: newHoverWindowSize,
                                                        screen: mouseScreen,
                                                        dockItemFrame: frameOverride,
                                                        dockPositionOverride: dockPositionOverride)
        } else {
            position = centerWindowOnScreen(size: newHoverWindowSize, screen: mouseScreen)
        }

        let finalFrame = CGRect(origin: position, size: newHoverWindowSize)
        applyWindowFrame(finalFrame, animated: true, dockPositionOverride: dockPositionOverride)
        previousHoverWindowOrigin = position
    }

    @MainActor
    private func updateContentViewSizeAndPosition(mouseLocation: CGPoint? = nil, mouseScreen: NSScreen, dockItemElement: AXUIElement?,
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

        let newHoverWindowSize = newHostingView.fittingSize

        elapsed = renderStartTime.map { (CFAbsoluteTimeGetCurrent() - $0) * 1000 } ?? 0
        DebugLogger.log("PreviewRender", details: "fittingSize done: \(newHoverWindowSize) (+\(String(format: "%.1f", elapsed))ms)")

        let position: CGPoint
        if centerOnScreen {
            position = centerWindowOnScreen(size: newHoverWindowSize, screen: mouseScreen)
        } else {
            if let validDockItemElement = dockItemElement {
                position = calculateWindowPosition(mouseLocation: mouseLocation, windowSize: newHoverWindowSize, screen: mouseScreen, dockItemElement: validDockItemElement, dockPositionOverride: dockPositionOverride)

                // Prevent rendering if position calculation failed for cmd-tab
                if dockPositionOverride == .cmdTab, position == .zero {
                    if let oldContentView = contentView {
                        oldContentView.removeFromSuperview()
                    }
                    contentView = nil
                    return
                }
            } else if let frameOverride = dockItemFrameOverride {
                position = calculateWindowPositionFromFrame(mouseLocation: mouseLocation, windowSize: newHoverWindowSize, screen: mouseScreen, dockItemFrame: frameOverride, dockPositionOverride: dockPositionOverride)
            } else if let mouseLocation, dockPositionOverride == .cli {
                position = calculateWindowPositionFromMouse(mouseLocation: mouseLocation, windowSize: newHoverWindowSize, screen: mouseScreen)
            } else {
                position = centerWindowOnScreen(size: newHoverWindowSize, screen: mouseScreen)
            }
        }
        let finalFrame = CGRect(origin: position, size: newHoverWindowSize)
        applyWindowFrame(finalFrame, animated: animated, dockPositionOverride: dockPositionOverride)
        previousHoverWindowOrigin = position

        elapsed = renderStartTime.map { (CFAbsoluteTimeGetCurrent() - $0) * 1000 } ?? 0
        DebugLogger.log("PreviewRender", details: "window frame applied, render complete (+\(String(format: "%.1f", elapsed))ms)")

        // Now that the main panel has a valid frame, position the search window (if active)
        if windowSwitcherCoordinator.windowSwitcherActive, Defaults[.enableWindowSwitcherSearch] {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if searchWindow == nil { setupSearchWindow() }
                searchWindow?.showSearch(relativeTo: self)
            }
        }
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

        let previewView = FullSizePreviewView(windowInfo: windowInfo, windowSize: windowSize)
        let hostingView = NSHostingView(rootView: previewView)

        if let oldFullPreviewContent = fullPreviewWindow?.contentView {
            oldFullPreviewContent.removeFromSuperview()
        }
        fullPreviewWindow?.contentView = hostingView

        fullPreviewWindow?.setFrame(flippedIconRect, display: true)
        fullPreviewWindow?.makeKeyAndOrderFront(nil)
    }

    @MainActor
    func hideFullPreviewWindow() {
        fullPreviewWindow?.orderOut(nil)
        if let currentFullPreviewContent = fullPreviewWindow?.contentView {
            currentFullPreviewContent.removeFromSuperview()
        }
        fullPreviewWindow?.contentView = nil
        fullPreviewWindow = nil
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

    private func calculateWindowPosition(mouseLocation: CGPoint?, windowSize: CGSize, screen: NSScreen, dockItemElement: AXUIElement, dockPositionOverride: DockPosition? = nil) -> CGPoint {
        guard let mouseLocation else { return .zero }
        let screenFrame = screen.frame
        let dockPosition = dockPositionOverride ?? DockUtils.getDockPosition()

        do {
            guard let currentPosition = try dockItemElement.position(),
                  let currentSize = try dockItemElement.size()
            else {
                return .zero
            }
            let currentIconRect = CGRect(origin: currentPosition, size: currentSize)
            let flippedIconRect = CGRect(
                origin: DockObserver.cgPointFromNSPoint(currentIconRect.origin, forScreen: screen),
                size: currentIconRect.size
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
                xPosition = screenFrame.maxX - flippedIconRect.width - windowSize.width
                yPosition = flippedIconRect.minY - (windowSize.height / 2)
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

        } catch {
            return .zero
        }
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

        if shouldAnimate {
            // Window is appearing for the first time, apply slide animation
            let dockPosition = dockPositionOverride ?? DockUtils.getDockPosition()
            let animationOffset: CGFloat = 7.0
            var startFrame = frame

            switch dockPosition {
            case .bottom, .cli:
                startFrame.origin.y -= animationOffset
            case .left:
                startFrame.origin.x -= animationOffset
            case .right:
                startFrame.origin.x += animationOffset
            default:
                startFrame.origin.y -= animationOffset
            }

            setFrame(startFrame, display: true)
            orderFront(nil)

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.175
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.animator().setFrame(frame, display: true)
            }
        } else {
            setFrame(frame, display: true)
        }

        alphaValue = 1.0
        makeKeyAndOrderFront(nil)
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
        renderStartTime: CFAbsoluteTime? = nil
    ) {
        let elapsed = renderStartTime.map { (CFAbsoluteTimeGetCurrent() - $0) * 1000 } ?? 0
        DebugLogger.log("PreviewRender", details: "performDisplay start (+\(String(format: "%.1f", elapsed))ms)")

        let screen = mouseScreen ?? NSScreen.main!
        var finalEmbeddedContentType: EmbeddedContentType = .none
        var useBigStandaloneViewInstead = false
        var viewForBigStandalone: AnyView?

        if let bundleId = bundleIdentifier {
            let actualAppContentType = getEmbeddedContentType(for: bundleId)

            switch actualAppContentType {
            case let .media(mediaBundleId):
                if Defaults[.showSpecialAppControls] {
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
                if Defaults[.showSpecialAppControls] {
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
            currentlyDisplayedPID = try? dockItemElement.pid()
        }

        if useBigStandaloneViewInstead, let viewToShow = viewForBigStandalone {
            performShowView(viewToShow, mouseLocation: mouseLocation, mouseScreen: screen, dockItemElement: dockItemElement, dockPositionOverride: dockPositionOverride, dockItemFrameOverride: dockItemFrameOverride)
        } else {
            performShowWindow(
                appName: appName,
                windows: windows,
                mouseLocation: mouseLocation,
                mouseScreen: screen,
                dockItemElement: dockItemElement,
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
        hideFullPreviewWindow()

        if centeredHoverWindowState == .fullWindowPreview,
           let windowInfo = windows.first,
           let windowPosition = try? windowInfo.axElement.position(),
           let windowScreen = windowPosition.screen()
        {
            showFullPreviewWindow(for: windowInfo, on: windowScreen)
        } else {
            self.appName = appName
            let activeDockPosition = dockPositionOverride ?? DockUtils.getDockPosition()
            currentDockPosition = activeDockPosition

            windowSwitcherCoordinator.setWindows(windows, dockPosition: activeDockPosition, bestGuessMonitor: screen)

            if let initialIndex {
                windowSwitcherCoordinator.setIndex(to: initialIndex, shouldScroll: false)
            } else {
                windowSwitcherCoordinator.currIndex = -1
            }

            self.onWindowTap = onWindowTap

            updateContentViewSizeAndPosition(mouseLocation: mouseLocation, mouseScreen: screen, dockItemElement: dockItemElement, animated: !shouldCenterOnScreen,
                                             centerOnScreen: shouldCenterOnScreen, centeredHoverWindowState: centeredHoverWindowState,
                                             embeddedContentType: embeddedContentType, dockPositionOverride: dockPositionOverride,
                                             dockItemFrameOverride: dockItemFrameOverride, renderStartTime: renderStartTime)
        }
    }

    @MainActor
    func cycleWindows(goBackwards: Bool) {
        let coordinator = windowSwitcherCoordinator
        guard !coordinator.windows.isEmpty else { return }

        if coordinator.windowSwitcherActive, coordinator.hasActiveSearch {
            return
        }

        let windowsCount = coordinator.windows.count
        var newIndex = coordinator.currIndex

        if !coordinator.windowSwitcherActive, coordinator.currIndex < 0 {
            newIndex = goBackwards ? (windowsCount - 1) : 0
            if windowsCount == 0 { newIndex = -1 }
        } else if windowsCount > 0 {
            let dockPosition = DockUtils.getDockPosition()
            let isHorizontalFlow = dockPosition.isHorizontalFlow || coordinator.windowSwitcherActive

            let direction: ArrowDirection = if isHorizontalFlow {
                goBackwards ? .left : .right
            } else {
                goBackwards ? .up : .down
            }

            newIndex = WindowPreviewHoverContainer.navigateWindowSwitcher(
                from: coordinator.currIndex,
                direction: direction,
                totalItems: windowsCount,
                dockPosition: dockPosition,
                isWindowSwitcherActive: coordinator.windowSwitcherActive
            )
        } else {
            newIndex = -1
        }
        coordinator.setIndex(to: newIndex)
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
        hideWindow()
    }

    @MainActor
    func navigateWithArrowKey(direction: ArrowDirection) {
        let coordinator = windowSwitcherCoordinator
        guard !coordinator.windows.isEmpty else { return }

        coordinator.hasMovedSinceOpen = false
        coordinator.initialHoverLocation = nil

        let threshold = Defaults[.windowSwitcherCompactThreshold]
        let isListViewMode = coordinator.windowSwitcherActive && threshold > 0 && coordinator.windows.count >= threshold

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

        // Handle filtered navigation when search is active (grid view)
        if coordinator.windowSwitcherActive, coordinator.hasActiveSearch {
            let filteredIndices = coordinator.filteredWindowIndices()
            guard !filteredIndices.isEmpty else { return }

            guard let currentFilteredPos = filteredIndices.firstIndex(of: coordinator.currIndex) else {
                coordinator.setIndex(to: filteredIndices.first ?? 0)
                return
            }

            let newFilteredPos = WindowPreviewHoverContainer.navigateWindowSwitcher(
                from: currentFilteredPos,
                direction: direction,
                totalItems: filteredIndices.count,
                dockPosition: .bottom,
                isWindowSwitcherActive: true
            )

            coordinator.setIndex(to: filteredIndices[newFilteredPos])
            return
        }

        let windowsCount = coordinator.windows.count
        var newIndex = coordinator.currIndex

        if !coordinator.windowSwitcherActive, coordinator.currIndex < 0 {
            newIndex = windowsCount > 0 ? 0 : -1
        } else {
            let dockPosition = DockUtils.getDockPosition()

            newIndex = WindowPreviewHoverContainer.navigateWindowSwitcher(
                from: coordinator.currIndex,
                direction: direction,
                totalItems: windowsCount,
                dockPosition: dockPosition,
                isWindowSwitcherActive: coordinator.windowSwitcherActive
            )
        }
        coordinator.setIndex(to: newIndex)
    }

    @MainActor
    func performActionOnCurrentWindow(action: WindowAction) {
        let coordinator = windowSwitcherCoordinator
        guard coordinator.currIndex >= 0, coordinator.currIndex < coordinator.windows.count else {
            return
        }

        let window = coordinator.windows[coordinator.currIndex]
        let originalIndex = coordinator.currIndex

        let result = action.perform(on: window, keepPreviewOnQuit: false)

        switch result {
        case .dismissed:
            hideWindow()
        case let .windowUpdated(updatedWindow):
            coordinator.updateWindow(at: originalIndex, with: updatedWindow)
        case .windowRemoved:
            coordinator.removeWindow(at: originalIndex)
        case .appWindowsRemoved, .noChange:
            break
        }
    }

    func showWindow(appName: String, windows: [WindowInfo], mouseLocation: CGPoint? = nil, mouseScreen: NSScreen? = nil,
                    dockItemElement: AXUIElement?,
                    overrideDelay: Bool = false, centeredHoverWindowState: PreviewStateCoordinator.WindowState? = nil,
                    onWindowTap: (() -> Void)? = nil, bundleIdentifier: String? = nil,
                    bypassDockMouseValidation: Bool = false,
                    dockPositionOverride: DockPosition? = nil, initialIndex: Int? = nil,
                    dockItemFrameOverride: CGRect? = nil)
    {
        let renderStartTime = CFAbsoluteTimeGetCurrent()
        DebugLogger.log("PreviewRender", details: "showWindow called: \(windows.count) windows for \(appName)")

        let shouldSkipDelay = overrideDelay || (Defaults[.useDelayOnlyForInitialOpen] && isVisible)
        let delay = shouldSkipDelay ? 0 : Defaults[.hoverWindowOpenDelay]

        let workItem = { [weak self, renderStartTime] in
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
                self?.performDisplay(appName: appName, windows: windows, mouseLocation: mouseLocation, mouseScreen: mouseScreen, dockItemElement: dockItemElement, centeredHoverWindowState: centeredHoverWindowState, onWindowTap: onWindowTap, bundleIdentifier: bundleIdentifier, dockPositionOverride: dockPositionOverride, initialIndex: initialIndex, dockItemFrameOverride: dockItemFrameOverride, renderStartTime: renderStartTime)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
}
