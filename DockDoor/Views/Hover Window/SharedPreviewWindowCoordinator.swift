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
        withAnimation(.easeInOut) {
            self.currIndex = to
        }
    }
}

final class SharedPreviewWindowCoordinator: NSWindow {
    static let shared = SharedPreviewWindowCoordinator()

    let windowSwitcherCoordinator = ScreenCenteredFloatingWindowCoordinator()
    private let dockManager = DockAutoHideManager()

    private var appName: String = ""
    private var windows: [WindowInfo] = []
    private var onWindowTap: (() -> Void)?
    private var hostingView: NSHostingView<WindowPreviewHoverContainer>?
    private var fullPreviewWindow: NSWindow?

    var windowSize: CGSize = getWindowSize()

    private var previousHoverWindowOrigin: CGPoint?

    private let debounceDelay: TimeInterval = 0.1
    private var debounceWorkItem: DispatchWorkItem?
    private var lastShowTime: Date?

    private init() {
        super.init(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        setupWindow()
    }

    deinit {
        dockManager.cleanup()
    }

    // Setup window properties
    private func setupWindow() {
        level = NSWindow.Level(rawValue: 19)
        isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces]
        backgroundColor = .clear
        hasShadow = true
    }

    // Hide the window and reset its state
    func hideWindow() {
        DispatchQueue.main.async { [weak self] in
            guard let self, isVisible else { return }

            hideFullPreviewWindow()
            contentView = nil
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
    private func updateContentViewSizeAndPosition(mouseLocation: CGPoint? = nil, mouseScreen: NSScreen,
                                                  iconRect: CGRect?, animated: Bool, centerOnScreen: Bool = false,
                                                  centeredHoverWindowState: ScreenCenteredFloatingWindowCoordinator.WindowState? = nil)
    {
        guard hostingView != nil else { return }
        windowSwitcherCoordinator.setShowing(centeredHoverWindowState, toState: centerOnScreen)
        // Reset the hosting view
        let hoverView = WindowPreviewHoverContainer(appName: appName, windows: windows, onWindowTap: onWindowTap,
                                                    dockPosition: DockUtils.getDockPosition(), mouseLocation: mouseLocation,
                                                    bestGuessMonitor: mouseScreen, windowSwitcherCoordinator: windowSwitcherCoordinator)
        let newHostingView = NSHostingView(rootView: hoverView)
        contentView = newHostingView
        hostingView = newHostingView
        let newHoverWindowSize = newHostingView.fittingSize
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
            fullPreviewWindow = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
            fullPreviewWindow?.level = NSWindow.Level(rawValue: 18)
            fullPreviewWindow?.isOpaque = false
            fullPreviewWindow?.backgroundColor = .clear
            fullPreviewWindow?.hasShadow = true
        }

        let padding: CGFloat = 40
        let maxSize = CGSize(
            width: screen.visibleFrame.width - padding * 2,
            height: screen.visibleFrame.height - padding * 2
        )

        let previewView = FullSizePreviewView(windowInfo: windowInfo, maxSize: maxSize)
        let hostingView = NSHostingView(rootView: previewView)
        fullPreviewWindow?.contentView = hostingView

        let centerPoint = centerWindowOnScreen(size: maxSize, screen: screen)
        fullPreviewWindow?.setFrame(CGRect(origin: centerPoint, size: maxSize), display: true)
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

        var xPosition: CGFloat
        var yPosition: CGFloat

        switch dockPosition {
        case .bottom:
            xPosition = mouseLocation.x - (windowSize.width / 2)
            yPosition = screenFrame.minY + iconRect.height
        case .left, .right:
            if dockPosition == .left {
                xPosition = screenFrame.minX + iconRect.width
            } else { // .right
                xPosition = screenFrame.maxX - iconRect.width - windowSize.width
            }
            yPosition = mouseLocation.y - (windowSize.height / 2)
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
        let shouldAnimate = animated && frame != self.frame

        if shouldAnimate {
            let distanceThreshold: CGFloat = 1800
            let distance = previousHoverWindowOrigin.map { frame.origin.distance(to: $0) } ?? distanceThreshold + 1

            if distance > distanceThreshold || !Defaults[.showAnimations] {
                setFrame(frame, display: true)
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
        let naturalDelay = Defaults[.lateralMovement] ? 0.25 : Defaults[.hoverWindowOpenDelay]
        let delay = overrideDelay ? 0.0 : naturalDelay

        debounceWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
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
        dockManager.preventDockHiding(centeredHoverWindowState != nil)

        // ensure view isn't transparent
        alphaValue = 1.0

        let shouldCenterOnScreen = centeredHoverWindowState != .none

        guard !windows.isEmpty else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            let screen = mouseScreen ?? NSScreen.main!

            hideFullPreviewWindow() // clean up any lingering fullscreen previews before presenting a new one

            // If in full window preview mode, show the full preview window and return early
            if centeredHoverWindowState == .fullWindowPreview, let windowInfo = windows.first {
                showFullPreviewWindow(for: windowInfo, on: screen)
            } else {
                self.appName = appName
                self.windows = windows
                self.onWindowTap = onWindowTap

                updateHostingView(appName: appName, windows: windows, onWindowTap: onWindowTap, screen: screen, mouseLocation: mouseLocation)

                updateContentViewSizeAndPosition(mouseLocation: mouseLocation, mouseScreen: screen, iconRect: iconRect, animated: true,
                                                 centerOnScreen: shouldCenterOnScreen, centeredHoverWindowState: centeredHoverWindowState)
            }

            makeKeyAndOrderFront(nil)
        }
    }

    // Update or create the hosting view
    private func updateHostingView(appName: String, windows: [WindowInfo], onWindowTap: (() -> Void)?, screen: NSScreen, mouseLocation: CGPoint? = nil) {
        let hoverView = WindowPreviewHoverContainer(appName: appName, windows: windows, onWindowTap: onWindowTap,
                                                    dockPosition: DockUtils.getDockPosition(), mouseLocation: mouseLocation,
                                                    bestGuessMonitor: screen, windowSwitcherCoordinator: windowSwitcherCoordinator)

        if let existingHostingView = hostingView {
            existingHostingView.rootView = hoverView
        } else {
            let newHostingView = NSHostingView(rootView: hoverView)
            contentView = newHostingView
            hostingView = newHostingView
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
        guard !windows.isEmpty else { return }
        let selectedWindow = windows[windowSwitcherCoordinator.currIndex]
        WindowUtil.bringWindowToFront(windowInfo: selectedWindow)
        hideWindow()
    }
}
