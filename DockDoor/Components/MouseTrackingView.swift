import SwiftUI

struct MouseTrackingView: NSViewRepresentable {
    func makeNSView(context: Context) -> MouseTrackingNSView {
        MouseTrackingNSView()
    }

    func updateNSView(_ nsView: MouseTrackingNSView, context: Context) {}
}

class MouseTrackingNSView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupTrackingArea()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTrackingArea()
    }

    private func setupTrackingArea() {
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways, .inVisibleRect]
        let trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }

    override func mouseExited(with event: NSEvent) {
        DispatchQueue.main.async {
            SharedPreviewWindowCoordinator.shared.hideWindow()
            DockObserver.shared.lastAppUnderMouse = nil
        }
    }
}
