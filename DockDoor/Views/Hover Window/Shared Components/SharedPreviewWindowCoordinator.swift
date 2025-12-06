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

    var pinnedWindows: [String: NSWindow] = [:]

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

        // Hide search window
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

        // Recheck indicator hover state since the preview window is hiding
        DockObserver.activeInstance?.recheckIndicatorHoverState()
    }

    @MainActor
    private func performShowView(_ view: some View,
                                 mouseLocation: CGPoint?,
                                 mouseScreen: NSScreen,
                                 dockItemElement: AXUIElement?,
                                 dockPositionOverride: DockPosition? = nil)
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
        } else {
            position = centerWindowOnScreen(size: newHoverWindowSize, screen: mouseScreen)
        }

        let finalFrame = CGRect(origin: position, size: newHoverWindowSize)
        applyWindowFrame(finalFrame, animated: true)
        previousHoverWindowOrigin = position
    }

    @MainActor
    private func updateContentViewSizeAndPosition(mouseLocation: CGPoint? = nil, mouseScreen: NSScreen, dockItemElement: AXUIElement?,
                                                  animated: Bool, centerOnScreen: Bool = false,
                                                  centeredHoverWindowState: PreviewStateCoordinator.WindowState? = nil,
                                                  embeddedContentType: EmbeddedContentType = .none,
                                                  dockPositionOverride: DockPosition? = nil)
    {
        windowSwitcherCoordinator.setShowing(centeredHoverWindowState, toState: centerOnScreen)

        // Defer showing the search window until after the hover window frame is applied

        let updateAvailable = (NSApp.delegate as? AppDelegate)?.updaterState.anUpdateIsAvailable ?? false

        let hoverView = WindowPreviewHoverContainer(appName: appName, onWindowTap: onWindowTap,
                                                    dockPosition: dockPositionOverride ?? DockUtils.getDockPosition(), mouseLocation: mouseLocation,
                                                    bestGuessMonitor: mouseScreen, dockItemElement: dockItemElement,
                                                    windowSwitcherCoordinator: windowSwitcherCoordinator,
                                                    mockPreviewActive: false,
                                                    updateAvailable: updateAvailable,
                                                    embeddedContentType: embeddedContentType)
        let newHostingView = NSHostingView(rootView: hoverView)

        if let oldContentView = contentView {
            oldContentView.removeFromSuperview()
        }
        contentView = newHostingView

        let newHoverWindowSize = newHostingView.fittingSize
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
            } else {
                position = centerWindowOnScreen(size: newHoverWindowSize, screen: mouseScreen)
            }
        }
        let finalFrame = CGRect(origin: position, size: newHoverWindowSize)
        applyWindowFrame(finalFrame, animated: animated)
        previousHoverWindowOrigin = position

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
            fullPreviewWindow?.level = .floating
            fullPreviewWindow?.isOpaque = false
            fullPreviewWindow?.backgroundColor = .clear
            fullPreviewWindow?.hasShadow = true
            fullPreviewWindow?.collectionBehavior = [.canJoinAllSpaces, .transient, .fullScreenAuxiliary]
            fullPreviewWindow?.hidesOnDeactivate = false
            fullPreviewWindow?.becomesKeyOnlyIfNeeded = true
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
        CGPoint(
            x: screen.frame.midX - (size.width / 2),
            y: screen.frame.midY - (size.height / 2)
        )
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

    @MainActor
    private func applyWindowFrame(_ frame: CGRect, animated: Bool) {
        let shouldAnimate = animated && Defaults[.showAnimations]

        if shouldAnimate {
            // Window is appearing for the first time, apply slide animation
            let dockPosition = DockUtils.getDockPosition()
            let animationOffset: CGFloat = 7.0
            var startFrame = frame

            switch dockPosition {
            case .bottom:
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
        initialIndex: Int? = nil
    ) {
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
            performShowView(viewToShow, mouseLocation: mouseLocation, mouseScreen: screen, dockItemElement: dockItemElement, dockPositionOverride: dockPositionOverride)
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
                initialIndex: initialIndex
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
                                   dockPositionOverride: DockPosition? = nil, initialIndex: Int? = nil)
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
            let currentDockPosition = DockUtils.getDockPosition()

            windowSwitcherCoordinator.setWindows(windows, dockPosition: currentDockPosition, bestGuessMonitor: screen)

            // Set initial index for window switcher
            if let initialIndex {
                windowSwitcherCoordinator.setIndex(to: initialIndex, shouldScroll: false)
            }

            self.onWindowTap = onWindowTap

            updateContentViewSizeAndPosition(mouseLocation: mouseLocation, mouseScreen: screen, dockItemElement: dockItemElement, animated: !shouldCenterOnScreen,
                                             centerOnScreen: shouldCenterOnScreen, centeredHoverWindowState: centeredHoverWindowState,
                                             embeddedContentType: embeddedContentType, dockPositionOverride: dockPositionOverride)
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

        if coordinator.windowSwitcherActive, coordinator.hasActiveSearch {
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

        switch action {
        case .quit:
            window.quit(force: NSEvent.modifierFlags.contains(.option))
            hideWindow()

        case .close:
            window.close()
            coordinator.removeWindow(at: originalIndex)

        case .minimize:
            var updatedWindow = window
            if updatedWindow.toggleMinimize() != nil {
                coordinator.updateWindow(at: originalIndex, with: updatedWindow)
            }

        case .toggleFullScreen:
            var updatedWindow = window
            updatedWindow.toggleFullScreen()
            hideWindow()

        case .hide:
            var updatedWindow = window
            if updatedWindow.toggleHidden() != nil {
                coordinator.updateWindow(at: originalIndex, with: updatedWindow)
            }

        case .openNewWindow:
            WindowUtil.openNewWindow(app: window.app)
            hideWindow()
        }
    }

    func showWindow(appName: String, windows: [WindowInfo], mouseLocation: CGPoint? = nil, mouseScreen: NSScreen? = nil,
                    dockItemElement: AXUIElement?,
                    overrideDelay: Bool = false, centeredHoverWindowState: PreviewStateCoordinator.WindowState? = nil,
                    onWindowTap: (() -> Void)? = nil, bundleIdentifier: String? = nil,
                    bypassDockMouseValidation: Bool = false,
                    dockPositionOverride: DockPosition? = nil, initialIndex: Int? = nil)
    {
        let delay = overrideDelay ? 0 : Defaults[.hoverWindowOpenDelay]

        let workItem = { [weak self] in
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
                self?.performDisplay(appName: appName, windows: windows, mouseLocation: mouseLocation, mouseScreen: mouseScreen, dockItemElement: dockItemElement, centeredHoverWindowState: centeredHoverWindowState, onWindowTap: onWindowTap, bundleIdentifier: bundleIdentifier, dockPositionOverride: dockPositionOverride, initialIndex: initialIndex)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
}
