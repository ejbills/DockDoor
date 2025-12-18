import Cocoa
import SwiftUI

struct TrackpadGestureModifier: ViewModifier {
    var onSwipeUp: () -> Void
    var onSwipeDown: () -> Void
    var onSwipeLeft: () -> Void
    var onSwipeRight: () -> Void

    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                isHovering = hovering
            }
            .background(
                TrackpadEventMonitor(
                    isActive: $isHovering,
                    onSwipeUp: onSwipeUp,
                    onSwipeDown: onSwipeDown,
                    onSwipeLeft: onSwipeLeft,
                    onSwipeRight: onSwipeRight
                )
                .frame(width: 0, height: 0)
            )
    }
}

struct TrackpadEventMonitor: NSViewRepresentable {
    @Binding var isActive: Bool
    var onSwipeUp: () -> Void
    var onSwipeDown: () -> Void
    var onSwipeLeft: () -> Void
    var onSwipeRight: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.isActive = isActive
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onSwipeUp: onSwipeUp,
            onSwipeDown: onSwipeDown,
            onSwipeLeft: onSwipeLeft,
            onSwipeRight: onSwipeRight
        )
    }

    class Coordinator {
        var isActive = false
        var onSwipeUp: () -> Void
        var onSwipeDown: () -> Void
        var onSwipeLeft: () -> Void
        var onSwipeRight: () -> Void

        private var scrollMonitor: Any?
        private var cumulativeScrollX: CGFloat = 0
        private var cumulativeScrollY: CGFloat = 0
        private var isScrolling = false
        private var isNaturalScrolling = false
        private var scrollEndTimer: Timer?

        init(
            onSwipeUp: @escaping () -> Void,
            onSwipeDown: @escaping () -> Void,
            onSwipeLeft: @escaping () -> Void,
            onSwipeRight: @escaping () -> Void
        ) {
            self.onSwipeUp = onSwipeUp
            self.onSwipeDown = onSwipeDown
            self.onSwipeLeft = onSwipeLeft
            self.onSwipeRight = onSwipeRight
            setupMonitor()
        }

        deinit {
            if let monitor = scrollMonitor {
                NSEvent.removeMonitor(monitor)
            }
            scrollEndTimer?.invalidate()
        }

        private func setupMonitor() {
            scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                self?.handleScroll(event)
                return event
            }
        }

        private func handleScroll(_ event: NSEvent) {
            guard isActive else { return }
            guard event.hasPreciseScrollingDeltas else { return }

            switch event.phase {
            case .began:
                cumulativeScrollX = 0
                cumulativeScrollY = 0
                isScrolling = true
                isNaturalScrolling = event.isDirectionInvertedFromDevice
                scrollEndTimer?.invalidate()

            case .changed:
                cumulativeScrollX += event.scrollingDeltaX
                cumulativeScrollY += event.scrollingDeltaY

            case .ended:
                finishScroll()

            case .cancelled:
                cumulativeScrollX = 0
                cumulativeScrollY = 0
                isScrolling = false

            default:
                break
            }

            // Backup timer for end detection
            scrollEndTimer?.invalidate()
            scrollEndTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak self] _ in
                self?.finishScroll()
            }
        }

        private func finishScroll() {
            guard isScrolling else { return }
            isScrolling = false

            let minDelta: CGFloat = 50

            let normalizedY = isNaturalScrolling ? -cumulativeScrollY : cumulativeScrollY

            if abs(cumulativeScrollY) > abs(cumulativeScrollX), abs(cumulativeScrollY) > minDelta {
                if normalizedY > 0 {
                    DispatchQueue.main.async { self.onSwipeUp() }
                } else {
                    DispatchQueue.main.async { self.onSwipeDown() }
                }
            } else if abs(cumulativeScrollX) > abs(cumulativeScrollY), abs(cumulativeScrollX) > minDelta {
                if cumulativeScrollX < 0 {
                    DispatchQueue.main.async { self.onSwipeLeft() }
                } else {
                    DispatchQueue.main.async { self.onSwipeRight() }
                }
            }

            cumulativeScrollX = 0
            cumulativeScrollY = 0
        }
    }
}

extension View {
    func onTrackpadSwipe(
        onSwipeUp: @escaping () -> Void = {},
        onSwipeDown: @escaping () -> Void = {},
        onSwipeLeft: @escaping () -> Void = {},
        onSwipeRight: @escaping () -> Void = {}
    ) -> some View {
        modifier(TrackpadGestureModifier(
            onSwipeUp: onSwipeUp,
            onSwipeDown: onSwipeDown,
            onSwipeLeft: onSwipeLeft,
            onSwipeRight: onSwipeRight
        ))
    }
}
