import SwiftUI

// Preference key to pass mouse events up the view hierarchy
struct MouseEventKey: PreferenceKey {
    static var defaultValue: NSEvent? = nil
    static func reduce(value: inout NSEvent?, nextValue: () -> NSEvent?) {
        value = nextValue() ?? value
    }
}

struct MouseEventModifier: ViewModifier {
    var onMiddleClick: () -> Void

    public func body(content: Content) -> some View {
        content
            .overlay(MouseEventCapturingView(onMiddleClick: onMiddleClick))
    }

    struct MouseEventCapturingView: NSViewRepresentable {
        var onMiddleClick: () -> Void

        func makeNSView(context: Context) -> NSView {
            let view = MiddleClickDetectorView()
            view.onMiddleClick = onMiddleClick
            return view
        }

        func updateNSView(_ nsView: NSView, context: Context) {
            if let view = nsView as? MiddleClickDetectorView {
                view.onMiddleClick = onMiddleClick
            }
        }

        class MiddleClickDetectorView: NSView {
            var onMiddleClick: (() -> Void)?

            override var isFlipped: Bool { true }

            private var trackingArea: NSTrackingArea?

            override func updateTrackingAreas() {
                super.updateTrackingAreas()

                if let existingTrackingArea = trackingArea {
                    removeTrackingArea(existingTrackingArea)
                }

                let newTrackingArea = NSTrackingArea(
                    rect: bounds,
                    options: [.activeInKeyWindow, .inVisibleRect, .mouseEnteredAndExited, .mouseMoved],
                    owner: self,
                    userInfo: nil
                )
                addTrackingArea(newTrackingArea)
                trackingArea = newTrackingArea
            }

            init() {
                super.init(frame: .zero)
                isHidden = false
                wantsLayer = true
                alphaValue = 0.001
            }

            @available(*, unavailable)
            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }

            // Allow mouse moved events to pass through
            override func mouseMoved(with event: NSEvent) {
                super.mouseMoved(with: event)

                // Pass the event up to the next responder
                if let nextResponder {
                    nextResponder.mouseMoved(with: event)
                }
            }

            // Allow mouse entered events to pass through
            override func mouseEntered(with event: NSEvent) {
                super.mouseEntered(with: event)

                // Pass the event up to the next responder
                if let nextResponder {
                    nextResponder.mouseEntered(with: event)
                }
            }

            // Allow mouse exited events to pass through
            override func mouseExited(with event: NSEvent) {
                super.mouseExited(with: event)

                if let nextResponder {
                    nextResponder.mouseExited(with: event)
                }
            }

            override func hitTest(_ point: NSPoint) -> NSView? {
                // Only intercept middle-click events, let others pass through
                if let currentEvent = NSApp.currentEvent,
                   currentEvent.type == .otherMouseDown,
                   currentEvent.buttonNumber == 2
                {
                    return bounds.contains(point) ? self : nil
                }

                // For all other event types, let them pass through
                return nil
            }

            override func otherMouseDown(with event: NSEvent) {
                if event.buttonNumber == 2 { // Middle click
                    onMiddleClick?()
                } else {
                    // For any other "other" mouse down events, pass them up the chain.
                    super.otherMouseDown(with: event)
                }
            }

            override var acceptsFirstResponder: Bool { true }
        }
    }
}

extension View {
    func onMiddleClick(perform action: @escaping () -> Void) -> some View {
        modifier(MouseEventModifier(onMiddleClick: action))
    }
}
