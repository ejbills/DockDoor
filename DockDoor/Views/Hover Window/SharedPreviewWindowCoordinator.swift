import Defaults
import Sparkle
import SwiftUI

enum ArrowDirection {
    case left, right, up, down
}

final class SharedPreviewWindowCoordinator: NSPanel {
    weak static var activeInstance: SharedPreviewWindowCoordinator?

    let windowSwitcherCoordinator = PreviewStateCoordinator()
    private let dockManager = DockAutoHideManager()

    private var appName: String = ""
    private var onWindowTap: (() -> Void)?
    private var fullPreviewWindow: NSPanel?

    var windowSize: CGSize = getWindowSize()

    private var previousHoverWindowOrigin: CGPoint?

    private let debounceDelay: TimeInterval = 0.1
    private var debounceWorkItem: DispatchWorkItem?
    private var lastShowTime: Date?

    init() {
        let styleMask: NSWindow.StyleMask = [.nonactivatingPanel, .fullSizeContentView, .borderless]
        super.init(contentRect: .zero, styleMask: styleMask, backing: .buffered, defer: false)
        SharedPreviewWindowCoordinator.activeInstance = self
        setupWindow()
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

            DragPreviewCoordinator.shared.endDragging()

            hideFullPreviewWindow()

            if let currentContent = contentView {
                currentContent.removeFromSuperview()
            }
            contentView = nil

            appName = ""
            let defaultDockPosition = DockUtils.getDockPosition()
            let defaultScreen = NSScreen.main ?? NSScreen.screens.first!
            windowSwitcherCoordinator.setWindows([], dockPosition: defaultDockPosition, bestGuessMonitor: defaultScreen)
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

    private func updateContentViewSizeAndPosition(mouseLocation: CGPoint? = nil, mouseScreen: NSScreen, dockItemElement: AXUIElement?,
                                                  animated: Bool, centerOnScreen: Bool = false,
                                                  centeredHoverWindowState: PreviewStateCoordinator.WindowState? = nil)
    {
        windowSwitcherCoordinator.setShowing(centeredHoverWindowState, toState: centerOnScreen)

        let updateAvailable = (NSApp.delegate as? AppDelegate)?.updaterState.anUpdateIsAvailable ?? false

        let hoverView = WindowPreviewHoverContainer(appName: appName, onWindowTap: onWindowTap,
                                                    dockPosition: DockUtils.getDockPosition(), mouseLocation: mouseLocation,
                                                    bestGuessMonitor: mouseScreen, windowSwitcherCoordinator: windowSwitcherCoordinator,
                                                    mockPreviewActive: false,
                                                    updateAvailable: updateAvailable)
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
                position = calculateWindowPosition(mouseLocation: mouseLocation, windowSize: newHoverWindowSize, screen: mouseScreen, dockItemElement: validDockItemElement)
            } else {
                print("Warning: dockItemElement is nil when not centering on screen. Defaulting position to center of screen.")
                position = centerWindowOnScreen(size: newHoverWindowSize, screen: mouseScreen)
            }
        }
        let finalFrame = CGRect(origin: position, size: newHoverWindowSize)
        applyWindowFrame(finalFrame, animated: animated)
        previousHoverWindowOrigin = position
    }

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

    private func calculateWindowPosition(mouseLocation: CGPoint?, windowSize: CGSize, screen: NSScreen, dockItemElement: AXUIElement) -> CGPoint {
        guard let mouseLocation else { return .zero }
        let screenFrame = screen.frame
        let dockPosition = DockUtils.getDockPosition()

        do {
            guard let currentPosition = try dockItemElement.position(),
                  let currentSize = try dockItemElement.size()
            else {
                print("Failed to get current position/size")
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
            case .bottom:
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
            default:
                break
            }

            xPosition = max(screenFrame.minX, min(xPosition, screenFrame.maxX - windowSize.width))
            yPosition = max(screenFrame.minY, min(yPosition, screenFrame.maxY - windowSize.height))

            return CGPoint(x: xPosition, y: yPosition)

        } catch {
            print("Error fetching current dock item position/size: \(error)")
        }

        return CGPoint.zero
    }

    private func applyWindowFrame(_ frame: CGRect, animated: Bool) {
        let shouldAnimate = animated && frame != self.frame && Defaults[.showAnimations]

        if shouldAnimate {
            let distanceThreshold: CGFloat = 250
            let distance = previousHoverWindowOrigin.map { frame.origin.distance(to: $0) } ?? distanceThreshold + 1
            if distance > distanceThreshold {
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

                let fadeAnimation = CABasicAnimation(keyPath: "opacity")
                fadeAnimation.fromValue = 0.65
                fadeAnimation.toValue = 1.0
                fadeAnimation.duration = 0.175
                fadeAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

                contentView?.layer?.add(fadeAnimation, forKey: "opacity")
                contentView?.layer?.opacity = 1.0

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

    func showWindow(appName: String, windows: [WindowInfo], mouseLocation: CGPoint? = nil, mouseScreen: NSScreen? = nil,
                    dockItemElement: AXUIElement?,
                    overrideDelay: Bool = false, centeredHoverWindowState: PreviewStateCoordinator.WindowState? = nil,
                    onWindowTap: (() -> Void)? = nil)
    {
        let now = Date()
        let naturalDelay = Defaults[.lateralMovement] ? (Defaults[.hoverWindowOpenDelay] == 0 ? 0.2 : Defaults[.hoverWindowOpenDelay]) : Defaults[.hoverWindowOpenDelay]
        let delay = overrideDelay ? 0.0 : naturalDelay

        debounceWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            if let mouseLocation, mouseLocation.distance(to: NSEvent.mouseLocation) > 100 {
                return
            }

            self?.performShowWindow(appName: appName, windows: windows, mouseLocation: mouseLocation, mouseScreen: mouseScreen,
                                    dockItemElement: dockItemElement, centeredHoverWindowState: centeredHoverWindowState, onWindowTap: onWindowTap)
        }

        if let lastShowTime, now.timeIntervalSince(lastShowTime) < debounceDelay {
            debounceWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + debounceDelay, execute: workItem)
        } else {
            if delay == 0.0 {
                performShowWindow(appName: appName, windows: windows, mouseLocation: mouseLocation, mouseScreen: mouseScreen, dockItemElement: dockItemElement, centeredHoverWindowState: centeredHoverWindowState, onWindowTap: onWindowTap)
            } else {
                debounceWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
            }
        }

        lastShowTime = now
    }

    private func performShowWindow(appName: String, windows: [WindowInfo], mouseLocation: CGPoint?,
                                   mouseScreen: NSScreen?, dockItemElement: AXUIElement?,
                                   centeredHoverWindowState: PreviewStateCoordinator.WindowState? = nil,
                                   onWindowTap: (() -> Void)?)
    {
        guard !windows.isEmpty else { return }

        dockManager.preventDockHiding(centeredHoverWindowState != nil)
        let shouldCenterOnScreen = centeredHoverWindowState != .none

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let screen = mouseScreen ?? NSScreen.main!
            hideFullPreviewWindow()
            alphaValue = 1.0

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
                self.onWindowTap = onWindowTap

                updateContentViewSizeAndPosition(mouseLocation: mouseLocation, mouseScreen: screen, dockItemElement: dockItemElement, animated: !shouldCenterOnScreen,
                                                 centerOnScreen: shouldCenterOnScreen, centeredHoverWindowState: centeredHoverWindowState)
            }
            makeKeyAndOrderFront(nil)
        }
    }

    func cycleWindows(goBackwards: Bool) {
        guard !windowSwitcherCoordinator.windows.isEmpty else { return }

        let currentIndex = windowSwitcherCoordinator.currIndex
        let newIndex = (currentIndex + (goBackwards ? -1 : 1) + windowSwitcherCoordinator.windows.count) % windowSwitcherCoordinator.windows.count
        windowSwitcherCoordinator.setIndex(to: newIndex)
    }

    func selectAndBringToFrontCurrentWindow() {
        guard !windowSwitcherCoordinator.windows.isEmpty else {
            hideWindow()
            return
        }

        let selectedWindow = windowSwitcherCoordinator.windows[windowSwitcherCoordinator.currIndex]
        WindowUtil.bringWindowToFront(windowInfo: selectedWindow)
        hideWindow()
    }

    func navigateWithArrowKey(direction: ArrowDirection) {
        guard !windowSwitcherCoordinator.windows.isEmpty else { return }

        let goBackwards = switch direction {
        case .left, .up:
            true
        case .right, .down:
            false
        }
        cycleWindows(goBackwards: goBackwards)
    }
}
