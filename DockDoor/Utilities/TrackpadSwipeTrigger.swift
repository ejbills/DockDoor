import AppKit
import Defaults

struct SwipeTouch {
    let id: Int
    let position: CGPoint
}

enum TrackpadSwipeEvent: Equatable {
    case open
    case cycleForward
    case cycleBackward
    case release
}

/// Positions are fractions of the trackpad surface (`NSTouch.normalizedPosition`).
struct TrackpadSwipeDetector {
    static let openDistance: CGFloat = 0.03
    /// Travel required after opening before the first cycle, so a normal-length swipe
    /// does not blow past the intended window. Later cycles use `cycleDistance`.
    static let firstCycleDistance: CGFloat = 0.15
    static let cycleDistance: CGFloat = 0.04
    static let maxOffAxisDistance: CGFloat = 0.1
    static let axisDominanceRatio: CGFloat = 1.5

    private var startPositions: [Int: CGPoint] = [:]
    /// Set when this finger-down session was used for something else (extra fingers, off-axis travel).
    /// Cleared once at most one finger is left on the trackpad.
    private var isSpent = false
    private var hasCycled = false
    private(set) var isSwitching = false

    /// `touches` must be every finger currently on the trackpad.
    mutating func handle(_ touches: [SwipeTouch], fingers: Int, horizontal: Bool) -> TrackpadSwipeEvent? {
        if isSwitching {
            if touches.count < fingers {
                isSwitching = false
                isSpent = touches.count > 1
                startPositions.removeAll()
                return .release
            }
            guard let deltas = travel(touches) else { return nil }
            let averageAlong = deltas.map { horizontal ? $0.x : $0.y }.reduce(0, +) / CGFloat(deltas.count)
            let threshold = hasCycled ? Self.cycleDistance : Self.firstCycleDistance
            guard abs(averageAlong) >= threshold else { return nil }
            hasCycled = true
            rebase(touches)
            return averageAlong > 0 ? .cycleForward : .cycleBackward
        }

        if touches.count <= 1 {
            isSpent = false
            startPositions.removeAll()
            return nil
        }
        if isSpent {
            return nil
        }
        if touches.count > fingers {
            isSpent = true
            return nil
        }
        guard touches.count == fingers else {
            startPositions.removeAll()
            return nil
        }
        guard let deltas = travel(touches) else { return nil }

        let alongAxis = deltas.map { horizontal ? $0.x : $0.y }
        let acrossAxis = deltas.map { horizontal ? abs($0.y) : abs($0.x) }
        if acrossAxis.contains(where: { $0 >= Self.maxOffAxisDistance }) {
            isSpent = true
            return nil
        }
        // Every finger has to travel the same way, so pinches and spreads don't count.
        let allPositive = alongAxis.allSatisfy { $0 >= Self.openDistance }
        let allNegative = alongAxis.allSatisfy { $0 <= -Self.openDistance }
        guard allPositive || allNegative else { return nil }
        guard zip(alongAxis.map(abs), acrossAxis).allSatisfy({ $0 > $1 * Self.axisDominanceRatio }) else { return nil }

        isSwitching = true
        hasCycled = false
        rebase(touches)
        return .open
    }

    /// Per-finger travel since the gesture started, or nil when a finger is new and the measurement restarts.
    private mutating func travel(_ touches: [SwipeTouch]) -> [CGPoint]? {
        let deltas = touches.compactMap { touch -> CGPoint? in
            guard let start = startPositions[touch.id] else { return nil }
            return CGPoint(x: touch.position.x - start.x, y: touch.position.y - start.y)
        }
        guard !deltas.isEmpty, deltas.count == touches.count else {
            rebase(touches)
            return nil
        }
        return deltas
    }

    private mutating func rebase(_ touches: [SwipeTouch]) {
        startPositions = Dictionary(touches.map { ($0.id, $0.position) }, uniquingKeysWith: { first, _ in first })
    }
}

/// Listens to trackpad touches and reports swipes that should drive the window switcher.
final class TrackpadSwipeTrigger {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var detector = TrackpadSwipeDetector()
    private let onSwipe: @MainActor (TrackpadSwipeEvent) -> Void

    init(onSwipe: @escaping @MainActor (TrackpadSwipeEvent) -> Void) {
        self.onSwipe = onSwipe
        setupEventTap()
    }

    deinit {
        removeEventTap()
    }

    func reset() {
        removeEventTap()
        detector = TrackpadSwipeDetector()
        setupEventTap()
    }

    private static let eventCallback: CGEventTapCallBack = { _, type, event, refcon in
        guard let refcon else { return Unmanaged.passUnretained(event) }
        let trigger = Unmanaged<TrackpadSwipeTrigger>.fromOpaque(refcon).takeUnretainedValue()
        if let passthrough = reEnableIfNeeded(tap: trigger.eventTap, type: type, event: event) {
            return passthrough
        }
        if type.rawValue == NSEvent.EventType.gesture.rawValue {
            trigger.handle(event)
        }
        return Unmanaged.passUnretained(event)
    }

    private func setupEventTap() {
        guard eventTap == nil else { return }
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: NSEvent.EventTypeMask.gesture.rawValue,
            callback: TrackpadSwipeTrigger.eventCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                self?.setupEventTap()
            }
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        if let source {
            EventTapThread.shared.add(source)
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    private func removeEventTap() {
        guard let eventTap else { return }
        CGEvent.tapEnable(tap: eventTap, enable: false)
        if let runLoopSource {
            EventTapThread.shared.remove(runLoopSource)
        }
        CFMachPortInvalidate(eventTap)
        self.eventTap = nil
        runLoopSource = nil
    }

    private func handle(_ cgEvent: CGEvent) {
        guard let nsEvent = NSEvent(cgEvent: cgEvent) else { return }
        let touches = nsEvent.allTouches().filter { $0.type == .indirect }
        guard !touches.isEmpty else { return }

        let down = touches.filter { NSTouch.Phase.touching.contains($0.phase) && !$0.isResting }
        let swipeTouches = down.count > 1
            ? down.map { SwipeTouch(id: $0.identity.hash, position: $0.normalizedPosition) }
            : []

        let fingers = min(max(Defaults[.trackpadSwitcherSwipeFingers], 3), 4)
        let horizontal = Defaults[.trackpadSwitcherSwipeDirection] == .horizontal
        guard let event = detector.handle(swipeTouches, fingers: fingers, horizontal: horizontal) else { return }

        let onSwipe = onSwipe
        Task { @MainActor in
            onSwipe(event)
        }
    }
}
