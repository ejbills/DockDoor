import Defaults
import SwiftUI

struct WindowDismissalContainer: NSViewRepresentable {
    let appName: String
    let mouseLocation: CGPoint
    let bestGuessMonitor: NSScreen
    let dockPosition: DockPosition
    func makeNSView(context: Context) -> MouseTrackingNSView {
        let view = MouseTrackingNSView(appName: appName, mouseLocation: mouseLocation,
                                       bestGuessMonitor: bestGuessMonitor, dockPosition: dockPosition)
        view.resetOpacity()
        return view
    }

    func updateNSView(_ nsView: MouseTrackingNSView, context: Context) {
        nsView.resetOpacity()
    }
}

class MouseTrackingNSView: NSView {
    private let appName: String
    private let mouseLocation: CGPoint
    private let bestGuessMonitor: NSScreen
    private let dockPosition: DockPosition
    private var fadeOutTimer: Timer?
    private let fadeOutDuration: TimeInterval
    private var trackingTimer: Timer?

    private let baseDistanceThreshold: CGFloat = 600

    init(appName: String, mouseLocation: CGPoint, bestGuessMonitor: NSScreen, dockPosition: DockPosition, frame frameRect: NSRect = .zero) {
        self.appName = appName
        self.bestGuessMonitor = bestGuessMonitor
        self.mouseLocation = DockObserver.cgPointFromNSPoint(mouseLocation, forScreen: bestGuessMonitor)
        self.dockPosition = dockPosition
        fadeOutDuration = Defaults[.fadeOutDuration]
        super.init(frame: frameRect)
        setupTrackingArea()
        setupMouseMonitors()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupTrackingArea() {
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways, .inVisibleRect]
        let trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }

    private func setupMouseMonitors() {
        // The trackingTimer is used to track any lingering cases where the user does not interact with the window at all.
        // In such cases, we hide the window if it goes a decent distance from the initial location of the dock icon.
        // We use a timer to poll the mosue location as global and local mouse listeners are unreliable inside views.
        let dist = dockPosition == .bottom ? bestGuessMonitor.frame.height * 0.5 : bestGuessMonitor.frame.width * 0.5
        trackingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            checkMouseDistance(dist: dist)
        }
    }

    private func checkMouseDistance(dist: CGFloat) {
        let currentMousePosition = DockObserver.cgPointFromNSPoint(NSEvent.mouseLocation, forScreen: bestGuessMonitor)
        if currentMousePosition.distance(to: mouseLocation) > dist {
            DispatchQueue.main.async { [weak self] in
                self?.hideWindow()
            }
        }
    }

    deinit {
        trackingTimer?.invalidate()
    }

    func resetOpacity() {
        cancelFadeOut()
        setWindowOpacity(to: 1.0, duration: 0.0)
    }

    override func mouseExited(with event: NSEvent) {
        startFadeOut()
    }

    override func mouseEntered(with event: NSEvent) {
        cancelFadeOut()
        setWindowOpacity(to: 1.0, duration: 0.2)

        SharedPreviewWindowCoordinator.shared.cancelDebounceWorkItem()
    }

    private func startFadeOut() {
        cancelFadeOut()
        if fadeOutDuration == 0 {
            hideWindow()
        } else {
            setWindowOpacity(to: 0.0, duration: fadeOutDuration)
            fadeOutTimer = Timer.scheduledTimer(withTimeInterval: fadeOutDuration, repeats: false) { [weak self] _ in
                self?.hideWindow()
            }
        }
    }

    private func cancelFadeOut() {
        fadeOutTimer?.invalidate()
        fadeOutTimer = nil
    }

    private func setWindowOpacity(to value: CGFloat, duration: TimeInterval) {
        DispatchQueue.main.async { [weak self] in
            guard let window = self?.window else { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = duration
                window.animator().alphaValue = value
            }
        }
    }

    private func hideWindow() {
        let currentAppReturnType = DockObserver.shared.getDockItemAppStatusUnderMouse()
        switch currentAppReturnType.status {
        case .notFound:
            performHideWindow()
        case let .success(currApp):
            // Prevent accidental window hiding when quickly moving the mouse:
            // Only hide the window if the mouse has moved significantly (>100px)
            // from its initial position. This accounts for cases where the mouse
            // quickly leaves the dock, which can trigger a duplicate hover event.
            if currApp.localizedName == appName {
                let currentMousePosition = DockObserver.getMousePosition()
                if currentMousePosition.distance(to: mouseLocation) > 100 {
                    performHideWindow()
                } else if window?.alphaValue != 1 { // app was re-hovered while a fade out was in progress, reset the opacity
                    resetOpacity()
                }
            }
        case .notRunning:
            break
        }
    }

    private func performHideWindow() {
        DispatchQueue.main.async {
            SharedPreviewWindowCoordinator.shared.hideWindow()
            DockObserver.shared.lastAppUnderMouse = nil
        }
    }
}
