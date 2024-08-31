import AppKit
import SwiftUI

struct MouseTrackingView: NSViewRepresentable {
    func makeNSView(context: Context) -> MouseTrackingNSView {
        let view = MouseTrackingNSView()
        view.resetOpacity()
        return view
    }

    func updateNSView(_ nsView: MouseTrackingNSView, context: Context) {
        nsView.resetOpacity()
    }
}

class MouseTrackingNSView: NSView {
    private var fadeOutTimer: Timer?
    private let fadeOutDuration: TimeInterval = 1.0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupTrackingArea()
        resetOpacity()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTrackingArea()
        resetOpacity()
    }

    private func setupTrackingArea() {
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways, .inVisibleRect]
        let trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }

    func resetOpacity() {
        cancelFadeOut()
        setWindowOpacity(to: 1.0, duration: 0.0)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        resetOpacity()
    }

    override func mouseExited(with event: NSEvent) {
        startFadeOut()
    }

    override func mouseEntered(with event: NSEvent) {
        cancelFadeOut()
        setWindowOpacity(to: 1.0, duration: 0.2)
    }

    private func startFadeOut() {
        cancelFadeOut()
        setWindowOpacity(to: 0.0, duration: fadeOutDuration) {
            if self.window?.alphaValue == 0.0 {
                SharedPreviewWindowCoordinator.shared.hideWindow()
                DockObserver.shared.lastAppUnderMouse = nil
            }
        }

        fadeOutTimer = Timer.scheduledTimer(withTimeInterval: fadeOutDuration, repeats: false) { [weak self] _ in
            self?.forceHideWindow()
        }
    }

    private func cancelFadeOut() {
        fadeOutTimer?.invalidate()
        fadeOutTimer = nil
    }

    private func setWindowOpacity(to value: CGFloat, duration: TimeInterval, completion: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            if let window = self.window {
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = duration
                    window.animator().alphaValue = value
                }, completionHandler: completion)
            }
        }
    }

    private func forceHideWindow() {
        DispatchQueue.main.async {
            SharedPreviewWindowCoordinator.shared.hideWindow()
            DockObserver.shared.lastAppUnderMouse = nil
        }
    }
}
