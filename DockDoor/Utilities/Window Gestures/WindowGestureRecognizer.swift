import CoreGraphics
import Foundation

enum GestureStep: Equatable {
    case left
    case right
    case up
    case down
    case pinchIn
    case pinchOut

    var opposite: GestureStep {
        switch self {
        case .left: .right
        case .right: .left
        case .up: .down
        case .down: .up
        case .pinchIn: .pinchOut
        case .pinchOut: .pinchIn
        }
    }

    var isHorizontal: Bool { self == .left || self == .right }
    var isVertical: Bool { self == .up || self == .down }
    var isPinch: Bool { self == .pinchIn || self == .pinchOut }
}

struct GestureProgress: Equatable {
    var steps: [GestureStep] = []
    var held = false

    var isEmpty: Bool { steps.isEmpty && !held }
}

struct WindowGestureRecognizer {
    struct Configuration: Equatable {
        var stepDistance: CGFloat = 40
        var pinchDistance: CGFloat = 0.25
        var rearmInterval: TimeInterval = 0.3
        var holdDuration: TimeInterval? = 0.35
        var cancelTimeout: TimeInterval? = 1.5
        var axisDominance: CGFloat = 1.3
        var liftGrace: TimeInterval = 0.15
        var maximumSteps = 6

        static let sensitivityRange: ClosedRange<CGFloat> = 0.5 ... 2

        static func make(sensitivity: CGFloat, holdEnabled: Bool, holdDuration: TimeInterval, cancelTimeout: TimeInterval) -> Configuration {
            let clamped = min(max(sensitivity, sensitivityRange.lowerBound), sensitivityRange.upperBound)
            var configuration = Configuration()
            configuration.stepDistance /= clamped
            configuration.pinchDistance /= clamped
            configuration.holdDuration = holdEnabled ? max(holdDuration, 0.1) : nil
            configuration.cancelTimeout = cancelTimeout > 0 ? cancelTimeout : nil
            return configuration
        }
    }

    enum Input {
        case touchDown
        case scroll(dx: CGFloat, dy: CGFloat)
        case scrollLift
        case pinchBegan
        case pinch(CGFloat)
        case pinchEnded
        case pinchCancelled
        case escape
        case tick
    }

    enum Output: Equatable {
        case progressed(GestureProgress)
        case rearmed
        case cancelled
        case finished(GestureProgress?)
    }

    private enum Phase: Equatable {
        case idle
        case touching(since: TimeInterval)
        case swiping
        case pinching
        case liftPending(deadline: TimeInterval)
        case spent
    }

    private static let scrollMovementEpsilon: CGFloat = 0.5
    private static let pinchMovementEpsilon: CGFloat = 0.002

    var configuration: Configuration
    var repeatsWithoutPause = false
    private(set) var progress = GestureProgress()
    private var phase: Phase = .idle
    private var accumulatedX: CGFloat = 0
    private var accumulatedY: CGFloat = 0
    private var accumulatedPinch: CGFloat = 0
    private var lastMovement: TimeInterval = 0
    private var rearmed = false
    private var guardStep: GestureStep?
    private var holdConsumed = false

    init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    var isIdle: Bool { phase == .idle }
    var isSpent: Bool { phase == .spent }
    var isPinching: Bool { phase == .pinching }

    var hasMoved: Bool {
        switch phase {
        case .swiping, .pinching: true
        default: false
        }
    }

    mutating func clearSteps() {
        guardStep = progress.steps.last ?? guardStep
        progress.steps.removeAll()
        if progress.held {
            holdConsumed = true
            progress.held = false
        }
        rearmed = false
        accumulatedX = 0
        accumulatedY = 0
        accumulatedPinch = 0
    }

    mutating func handle(_ input: Input, at time: TimeInterval) -> [Output] {
        switch input {
        case .touchDown:
            return touchDown(at: time)
        case let .scroll(dx, dy):
            return scroll(dx: dx, dy: dy, at: time)
        case .scrollLift:
            return scrollLift(at: time)
        case .pinchBegan:
            return pinchBegan(at: time)
        case let .pinch(delta):
            return pinch(delta, at: time)
        case .pinchEnded:
            return pinchEnded()
        case .pinchCancelled:
            guard phase == .pinching || phase == .spent else { return [] }
            reset()
            return [.finished(nil)]
        case .escape:
            guard phase != .idle, phase != .spent else { return [] }
            phase = .spent
            return [.cancelled]
        case .tick:
            return tick(at: time)
        }
    }

    private mutating func touchDown(at time: TimeInterval) -> [Output] {
        if phase == .pinching { return [] }
        var outputs: [Output] = []
        if case .liftPending = phase {
            outputs.append(.finished(progress))
        }
        reset()
        phase = .touching(since: time)
        lastMovement = time
        return outputs
    }

    private mutating func scroll(dx: CGFloat, dy: CGFloat, at time: TimeInterval) -> [Output] {
        switch phase {
        case .spent, .pinching, .liftPending:
            return []
        case .idle:
            reset()
            phase = .swiping
            lastMovement = time
        case .touching:
            phase = .swiping
        case .swiping:
            break
        }

        let magnitude = hypot(dx, dy)
        guard magnitude > 0 else { return [] }
        if magnitude >= Self.scrollMovementEpsilon {
            noteMovement(at: time)
        }

        accumulatedX += dx
        accumulatedY += dy
        let horizontalTravel = abs(accumulatedX)
        let verticalTravel = abs(accumulatedY)
        guard max(horizontalTravel, verticalTravel) >= configuration.stepDistance else { return [] }

        let horizontalStep: GestureStep = accumulatedX > 0 ? .right : .left
        let verticalStep: GestureStep = accumulatedY > 0 ? .up : .down
        let detected: [GestureStep] = if horizontalTravel >= verticalTravel * configuration.axisDominance {
            [horizontalStep]
        } else if verticalTravel >= horizontalTravel * configuration.axisDominance {
            [verticalStep]
        } else {
            [horizontalStep, verticalStep]
        }
        accumulatedX = 0
        accumulatedY = 0

        var changed = false
        for step in detected where apply(step) {
            changed = true
        }
        return changed ? [.progressed(progress)] : []
    }

    private mutating func scrollLift(at time: TimeInterval) -> [Output] {
        switch phase {
        case .idle, .pinching, .liftPending:
            return []
        case .touching:
            if progress.held {
                phase = .liftPending(deadline: time + configuration.liftGrace)
                return []
            }
            reset()
            return [.finished(nil)]
        case .swiping:
            let finished = progress
            reset()
            return [.finished(finished.isEmpty ? nil : finished)]
        case .spent:
            reset()
            return [.finished(nil)]
        }
    }

    private mutating func pinchBegan(at time: TimeInterval) -> [Output] {
        switch phase {
        case .spent, .pinching:
            return []
        case .swiping where !progress.steps.isEmpty:
            return []
        case .idle:
            reset()
        case .touching, .swiping, .liftPending:
            break
        }
        phase = .pinching
        accumulatedPinch = 0
        lastMovement = time
        return []
    }

    private mutating func pinch(_ delta: CGFloat, at time: TimeInterval) -> [Output] {
        guard phase == .pinching else { return [] }
        if abs(delta) >= Self.pinchMovementEpsilon {
            noteMovement(at: time)
        }
        accumulatedPinch += delta
        guard abs(accumulatedPinch) >= configuration.pinchDistance else { return [] }
        let step: GestureStep = accumulatedPinch < 0 ? .pinchIn : .pinchOut
        accumulatedPinch = 0
        return apply(step) ? [.progressed(progress)] : []
    }

    private mutating func pinchEnded() -> [Output] {
        switch phase {
        case .pinching:
            let finished = progress
            reset()
            return [.finished(finished.isEmpty ? nil : finished)]
        case .spent:
            reset()
            return [.finished(nil)]
        default:
            return []
        }
    }

    private mutating func tick(at time: TimeInterval) -> [Output] {
        switch phase {
        case let .touching(since):
            if let holdDuration = configuration.holdDuration, !progress.held, !holdConsumed, time - since >= holdDuration {
                progress.held = true
                lastMovement = time
                return [.progressed(progress)]
            }
            if progress.held, let cancelTimeout = configuration.cancelTimeout, time - lastMovement >= cancelTimeout {
                phase = .spent
                return [.cancelled]
            }
            return []
        case .swiping, .pinching:
            if !progress.isEmpty, let cancelTimeout = configuration.cancelTimeout, time - lastMovement >= cancelTimeout {
                phase = .spent
                return [.cancelled]
            }
            if !rearmed, !repeatsWithoutPause, progress.steps.last != nil || guardStep != nil,
               time - lastMovement >= configuration.rearmInterval
            {
                rearmed = true
                return [.rearmed]
            }
            return []
        case let .liftPending(deadline):
            guard time >= deadline else { return [] }
            let finished = progress
            reset()
            return [.finished(finished)]
        case .idle, .spent:
            return []
        }
    }

    private mutating func noteMovement(at time: TimeInterval) {
        if !rearmed, time - lastMovement >= configuration.rearmInterval {
            rearmed = true
        }
        lastMovement = time
    }

    private mutating func apply(_ step: GestureStep) -> Bool {
        if repeatsWithoutPause {
            guard progress.steps.count < configuration.maximumSteps * 8 else { return false }
            progress.steps.append(step)
            guardStep = nil
            rearmed = false
            return true
        }

        if let last = progress.steps.last {
            if last == step.opposite {
                progress.steps.removeLast()
                guardStep = step
                rearmed = false
                return true
            }
            if last == step, !rearmed {
                return false
            }
        }
        if guardStep == step, !rearmed {
            return false
        }

        guard progress.steps.count < configuration.maximumSteps else { return false }
        progress.steps.append(step)
        guardStep = nil
        rearmed = false
        return true
    }

    private mutating func reset() {
        progress = GestureProgress()
        phase = .idle
        accumulatedX = 0
        accumulatedY = 0
        accumulatedPinch = 0
        rearmed = false
        guardStep = nil
        holdConsumed = false
        repeatsWithoutPause = false
    }
}
