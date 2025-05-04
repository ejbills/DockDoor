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
    private var inactivityTimer: Timer?
    private let inactivityTimeout: CGFloat

    init(appName: String, mouseLocation: CGPoint, bestGuessMonitor: NSScreen, dockPosition: DockPosition, frame frameRect: NSRect = .zero) {
        self.appName = appName
        self.bestGuessMonitor = bestGuessMonitor
        self.mouseLocation = DockObserver.cgPointFromNSPoint(mouseLocation, forScreen: bestGuessMonitor)
        self.dockPosition = dockPosition
        fadeOutDuration = Defaults[.fadeOutDuration]
        inactivityTimeout = Defaults[.inactivityTimeout]
        super.init(frame: frameRect)
        setupTrackingArea()
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

    deinit {
        clearTimers()
    }

    private func clearTimers() {
        trackingTimer?.invalidate()
        inactivityTimer?.invalidate()
        inactivityTimer = nil
    }

    private func resetInactivityTimer() {
        inactivityTimer?.invalidate()
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: inactivityTimeout, repeats: false) { [weak self] _ in
            self?.startFadeOut()
        }
    }

    func resetOpacity() {
        cancelFadeOut()
        setWindowOpacity(to: 1.0, duration: 0.0)
        resetInactivityTimer()
    }

    override func mouseExited(with event: NSEvent) {
        startFadeOut()
    }

    override func mouseEntered(with event: NSEvent) {
        cancelFadeOut()
        setWindowOpacity(to: 1.0, duration: 0.2)
        resetInactivityTimer()

        clearTimers()
    }

    private func startFadeOut() {
        cancelFadeOut()
        if fadeOutDuration == 0 {
            performHideWindow()
        } else {
            let currentAppReturnType = DockObserver.shared.getDockItemAppStatusUnderMouse()

            switch currentAppReturnType.status {
            case let .success(currApp):
                if currApp.localizedName == appName {
                    resetOpacity()
                }
            default:
                setWindowOpacity(to: 0.0, duration: fadeOutDuration)
                fadeOutTimer = Timer.scheduledTimer(withTimeInterval: fadeOutDuration, repeats: false) { [weak self] _ in
                    guard let self else { return }
                    performHideWindow()
                }
            }
        }
    }

    func cancelFadeOut() {
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

    private func performHideWindow() {
        DispatchQueue.main.async { [weak self] in
            guard self != nil else { return }
            SharedPreviewWindowCoordinator.shared.hideWindow()
            DockObserver.shared.lastAppUnderMouse = nil
        }
    }
}
