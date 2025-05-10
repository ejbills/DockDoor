import Defaults
import SwiftUI

class ScreenCenteredFloatingWindowCoordinator: ObservableObject {
    @Published var currIndex: Int = 0
    @Published var windowSwitcherActive: Bool = false
    @Published var fullWindowPreviewActive: Bool = false

    enum WindowState {
        case windowSwitcher
        case fullWindowPreview
        case both
    }

    func setShowing(_ state: WindowState? = .both, toState: Bool) {
        switch state {
        case .windowSwitcher:
            windowSwitcherActive = toState
        case .fullWindowPreview:
            fullWindowPreviewActive = toState
        case .both:
            windowSwitcherActive = toState
            fullWindowPreviewActive = toState
        case .none:
            return
        }
    }

    func setIndex(to: Int) {
        withAnimation(.snappy(duration: 0.125)) {
            self.currIndex = to
        }
    }
}

final class SharedPreviewWindowCoordinator: NSPanel {
    static let shared = SharedPreviewWindowCoordinator()

    let windowSwitcherCoordinator = ScreenCenteredFloatingWindowCoordinator()
    private let dockManager = DockAutoHideManager()

    private var appName: String = ""
    private var windows: [WindowInfo] = []
    private var onWindowTap: (() -> Void)?
    private var fullPreviewWindow: NSPanel?

    var windowSize: CGSize = getWindowSize()

    private var previousHoverWindowOrigin: CGPoint?

    private let debounceDelay: TimeInterval = 0.1
    private var debounceWorkItem: DispatchWorkItem?
    private var lastShowTime: Date?
    private var pulseWorkItem: DispatchWorkItem?

    private var lastMouseLocation: NSPoint?
    private var lastMouseScreen: NSScreen?

    private var hoverView: WindowPreviewHoverContainer?
    private var hostingView: NSHostingView<WindowPreviewHoverContainer>?

    private init() {
        let styleMask: NSWindow.StyleMask = [.nonactivatingPanel, .fullSizeContentView, .borderless]
        super.init(contentRect: .zero, styleMask: styleMask, backing: .buffered, defer: false)
        setupWindow()
    }

    deinit {
        dockManager.cleanup()
        cancelPulseWorkItem()
    }

    // Setup window properties
    private func setupWindow() {
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isReleasedWhenClosed = false
        isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces, .transient, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
    }

    // Hide the window and reset its state
    func hideWindow() {
        DispatchQueue.main.async { [weak self] in
            guard let self, isVisible else { return }

            // End any active drag operations
            DragPreviewCoordinator.shared.endDragging()

            // Stop position monitoring
            DockObserver.shared.stopPositionMonitoring()

            hideFullPreviewWindow()
            contentView = nil
            hoverView = nil
            hostingView = nil
            appName = ""
            windows.removeAll()
            windowSwitcherCoordinator.setIndex(to: 0)
            windowSwitcherCoordinator.setShowing(.both, toState: false)
            dockManager.restoreDockState()
            orderOut(nil)
        }
    }

    func cancelDebounceWorkItem() {
        DispatchQueue.main.async { [weak self] in
            self?.debounceWorkItem?.cancel()
        }
    }

    // Update the content view size and position
    private func updateContentViewSizeAndPosition(mouseLocation: CGPoint?, mouseScreen: NSScreen,
                                                  iconRect: CGRect?, animated: Bool = true, centerOnScreen: Bool = false,
                                                  centeredHoverWindowState: ScreenCenteredFloatingWindowCoordinator.WindowState? = nil)
    {
        lastMouseLocation = mouseLocation
        lastMouseScreen = mouseScreen

        windowSwitcherCoordinator.setShowing(centeredHoverWindowState, toState: centerOnScreen)

        // Update or create the hover view
        if hoverView == nil {
            hoverView = WindowPreviewHoverContainer(
                appName: appName,
                windows: windows,
                onWindowTap: onWindowTap,
                dockPosition: DockUtils.getDockPosition(),
                mouseLocation: mouseLocation,
                bestGuessMonitor: mouseScreen,
                windowSwitcherCoordinator: windowSwitcherCoordinator
            )
        }

        // Create hosting view if needed
        if hostingView == nil, let hoverView {
            hostingView = NSHostingView(rootView: hoverView)
            contentView = hostingView
        }

        // Update window frame
        guard let hostingView else { return }

        let newHoverWindowSize = hostingView.fittingSize
        let position: CGPoint
        if centerOnScreen {
            position = centerWindowOnScreen(size: newHoverWindowSize, screen: mouseScreen)
        } else {
            guard let unwrappedIconRect = iconRect else {
                fatalError("iconRect should not be nil when centerOnScreen is false")
            }
            position = calculateWindowPosition(mouseLocation: mouseLocation, windowSize: newHoverWindowSize, screen: mouseScreen, iconRect: unwrappedIconRect)
        }

        let finalFrame = CGRect(origin: position, size: newHoverWindowSize)
        applyWindowFrame(finalFrame, animated: animated)
        previousHoverWindowOrigin = position
    }

    // Show full preview window for a given WindowInfo
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
        fullPreviewWindow?.contentView = hostingView

        fullPreviewWindow?.setFrame(flippedIconRect, display: true)
        fullPreviewWindow?.makeKeyAndOrderFront(nil)
    }

    func hideFullPreviewWindow() {
        fullPreviewWindow?.orderOut(nil)
        fullPreviewWindow = nil
    }

    // Center window on screen
    private func centerWindowOnScreen(size: CGSize, screen: NSScreen) -> CGPoint {
        CGPoint(
            x: screen.frame.midX - (size.width / 2),
            y: screen.frame.midY - (size.height / 2)
        )
    }

    // Calculate window position based on the given dock icon frame and dock position
    private func calculateWindowPosition(mouseLocation: CGPoint?, windowSize: CGSize, screen: NSScreen, iconRect: CGRect) -> CGPoint {
        guard let mouseLocation else { return .zero }
        let screenFrame = screen.frame
        let dockPosition = DockUtils.getDockPosition()
        // Flip the coordinate space from the accessibility API (origin is bottom-left)
        let flippedIconRect = CGRect(
            origin: DockObserver.cgPointFromNSPoint(iconRect.origin, forScreen: screen),
            size: iconRect.size
        )
        var xPosition: CGFloat
        var yPosition: CGFloat
        switch dockPosition {
        case .bottom:
            // Horizontally center the preview to the hovered dock icon
            xPosition = flippedIconRect.midX - (windowSize.width / 2)
            // Position the preview just above the dock icon
            yPosition = flippedIconRect.minY
        case .left:
            // Vertically center the preview to the hovered dock icon
            xPosition = flippedIconRect.maxX
            yPosition = flippedIconRect.midY - (windowSize.height / 2) - flippedIconRect.height
        case .right:
            // Vertically center the preview to the hovered dock icon
            xPosition = screenFrame.maxX - flippedIconRect.width - windowSize.width
            yPosition = flippedIconRect.minY - (windowSize.height / 2)
        default:
            xPosition = mouseLocation.x - (windowSize.width / 2)
            yPosition = mouseLocation.y - (windowSize.height / 2)
        }
        // Apply buffer
        let bufferFromDock = Defaults[.bufferFromDock]
        switch dockPosition {
        case .left:
            xPosition += bufferFromDock
        case .right:
            xPosition -= bufferFromDock
        case .bottom:
            yPosition += bufferFromDock
        default:
            break
        }
        // Ensure window stays within screen bounds
        xPosition = max(screenFrame.minX, min(xPosition, screenFrame.maxX - windowSize.width))
        yPosition = max(screenFrame.minY, min(yPosition, screenFrame.maxY - windowSize.height))
        return CGPoint(x: xPosition, y: yPosition)
    }

    // Apply window frame with optional animation
    private func applyWindowFrame(_ frame: CGRect, animated: Bool) {
        let shouldAnimate = animated && frame != self.frame && Defaults[.showAnimations]

        if shouldAnimate {
            let distanceThreshold: CGFloat = 250
            let distance = previousHoverWindowOrigin.map { frame.origin.distance(to: $0) } ?? distanceThreshold + 1
            if distance > distanceThreshold {
                let dockPosition = DockUtils.getDockPosition()
                let animationOffset: CGFloat = 7.0 // Distance to animate
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

                // Setup initial frame
                setFrame(startFrame, display: true)
                orderFront(nil)

                let fadeAnimation = CABasicAnimation(keyPath: "opacity")
                fadeAnimation.fromValue = 0.65
                fadeAnimation.toValue = 1.0
                fadeAnimation.duration = 0.175
                fadeAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

                contentView?.layer?.add(fadeAnimation, forKey: "opacity")
                contentView?.layer?.opacity = 1.0

                // Animate the frame
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.175
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    self.animator().setFrame(frame, display: true)
                }
            } else {
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.15
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    self.animator().setFrame(frame, display: true)
                }, completionHandler: nil)
            }
        } else {
            setFrame(frame, display: true)
        }
    }

    // Show window with debounce logic
    func showWindow(appName: String, windows: [WindowInfo], mouseLocation: CGPoint? = nil, mouseScreen: NSScreen? = nil, iconRect: CGRect?,
                    overrideDelay: Bool = false, centeredHoverWindowState: ScreenCenteredFloatingWindowCoordinator.WindowState? = nil,
                    onWindowTap: (() -> Void)? = nil)
    {
        let now = Date()
        let naturalDelay = if Defaults[.lateralMovement] {
            Defaults[.hoverWindowOpenDelay] == 0 ? 0.2 : Defaults[.hoverWindowOpenDelay]
        } else {
            Defaults[.hoverWindowOpenDelay]
        }
        let delay = overrideDelay ? 0.0 : naturalDelay

        debounceWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            // prevent preview from showing if mouse has moved significantly from original position
            if let mouseLocation, mouseLocation.distance(to: NSEvent.mouseLocation) > 100 {
                return
            }

            self?.performShowWindow(appName: appName, windows: windows, mouseLocation: mouseLocation, mouseScreen: mouseScreen,
                                    iconRect: iconRect, centeredHoverWindowState: centeredHoverWindowState, onWindowTap: onWindowTap)
        }

        if let lastShowTime, now.timeIntervalSince(lastShowTime) < debounceDelay {
            debounceWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + debounceDelay, execute: workItem)
        } else {
            if delay == 0.0 {
                performShowWindow(appName: appName, windows: windows, mouseLocation: mouseLocation, mouseScreen: mouseScreen,
                                  iconRect: iconRect, centeredHoverWindowState: centeredHoverWindowState, onWindowTap: onWindowTap)
            } else {
                debounceWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
            }
        }

        lastShowTime = now
    }

    // Perform the actual window showing
    private func performShowWindow(appName: String, windows: [WindowInfo], mouseLocation: CGPoint?, mouseScreen: NSScreen?,
                                   iconRect: CGRect?, centeredHoverWindowState: ScreenCenteredFloatingWindowCoordinator.WindowState? = nil,
                                   onWindowTap: (() -> Void)?)
    {
        // ensure view isn't transparent
        alphaValue = 1.0
        guard !windows.isEmpty else { return }

        dockManager.preventDockHiding(centeredHoverWindowState != nil)

        let shouldCenterOnScreen = centeredHoverWindowState != .none

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            let screen = mouseScreen ?? NSScreen.main!

            hideFullPreviewWindow() // clean up any lingering fullscreen previews before presenting a new one

            // If in full window preview mode, show the full preview window and return early
            if centeredHoverWindowState == .fullWindowPreview,
               let windowInfo = windows.first,
               let windowPosition = try? windowInfo.axElement.position(),
               let windowScreen = windowPosition.screen()
            {
                showFullPreviewWindow(for: windowInfo, on: windowScreen)
            } else {
                // Update stored properties
                self.appName = appName
                self.windows = windows
                self.onWindowTap = onWindowTap

                // If window is already visible, update the existing view
                if isVisible {
                    hoverView = WindowPreviewHoverContainer(
                        appName: appName,
                        windows: windows,
                        onWindowTap: onWindowTap,
                        dockPosition: DockUtils.getDockPosition(),
                        mouseLocation: mouseLocation,
                        bestGuessMonitor: screen,
                        windowSwitcherCoordinator: windowSwitcherCoordinator
                    )

                    if let hoverView {
                        hostingView = NSHostingView(rootView: hoverView)
                        contentView = hostingView
                    }
                }

                updateContentViewSizeAndPosition(
                    mouseLocation: mouseLocation,
                    mouseScreen: screen,
                    iconRect: iconRect,
                    animated: !shouldCenterOnScreen,
                    centerOnScreen: shouldCenterOnScreen,
                    centeredHoverWindowState: centeredHoverWindowState
                )

                // Start position monitoring after window is shown
                DockObserver.shared.startPositionMonitoring()
            }

            makeKeyAndOrderFront(nil)
        }
    }

    // Cycle through windows
    func cycleWindows(goBackwards: Bool) {
        guard !windows.isEmpty else { return }

        let currentIndex = windowSwitcherCoordinator.currIndex
        let newIndex = (currentIndex + (goBackwards ? -1 : 1) + windows.count) % windows.count
        windowSwitcherCoordinator.setIndex(to: newIndex)
    }

    // Select and bring to front the current window
    func selectAndBringToFrontCurrentWindow() {
        hideWindow()

        guard !windows.isEmpty else { return }
        let selectedWindow = windows[windowSwitcherCoordinator.currIndex]
        WindowUtil.bringWindowToFront(windowInfo: selectedWindow)
    }

    func updatePosition(iconRect: CGRect) {
        guard let lastMouseScreen else { return }

        cancelPulseWorkItem()
        updateContentViewSizeAndPosition(mouseLocation: lastMouseLocation,
                                         mouseScreen: lastMouseScreen,
                                         iconRect: iconRect,
                                         animated: true,
                                         centerOnScreen: false)
    }

    private func cancelPulseWorkItem() {
        pulseWorkItem?.cancel()
        pulseWorkItem = nil
    }
}
