import CoreGraphics
@testable import DockDoor
import Foundation
import Testing

struct WindowGestureRecognizerTests {
    private func recognizer(holdDuration: TimeInterval? = 0.35, cancelTimeout: TimeInterval? = 1.5) -> WindowGestureRecognizer {
        var configuration = WindowGestureRecognizer.Configuration()
        configuration.holdDuration = holdDuration
        configuration.cancelTimeout = cancelTimeout
        return WindowGestureRecognizer(configuration: configuration)
    }

    private func lastProgress(_ outputs: [WindowGestureRecognizer.Output]) -> GestureProgress? {
        for output in outputs.reversed() {
            if case let .progressed(progress) = output { return progress }
        }
        return nil
    }

    @Test func swipeRightProducesOneStep() {
        var gesture = recognizer()
        _ = gesture.handle(.touchDown, at: 0)
        #expect(gesture.handle(.scroll(dx: 20, dy: 0), at: 0.01).isEmpty)
        let outputs = gesture.handle(.scroll(dx: 25, dy: 2), at: 0.02)
        #expect(lastProgress(outputs)?.steps == [.right])
        #expect(gesture.handle(.scrollLift, at: 0.05) == [.finished(GestureProgress(steps: [.right]))])
    }

    @Test func continuingTheSameSwipeDoesNotRepeatTheStep() {
        var gesture = recognizer()
        _ = gesture.handle(.touchDown, at: 0)
        _ = gesture.handle(.scroll(dx: 45, dy: 0), at: 0.01)
        #expect(gesture.handle(.scroll(dx: 45, dy: 0), at: 0.02).isEmpty)
        #expect(gesture.handle(.scroll(dx: 90, dy: 0), at: 0.03).isEmpty)
        #expect(gesture.progress.steps == [.right])
    }

    @Test func pausingRearmsTheSameDirection() {
        var gesture = recognizer()
        _ = gesture.handle(.touchDown, at: 0)
        _ = gesture.handle(.scroll(dx: 0, dy: 45), at: 0.01)
        #expect(gesture.handle(.tick, at: 0.2).isEmpty)
        #expect(gesture.handle(.tick, at: 0.35) == [.rearmed])
        let outputs = gesture.handle(.scroll(dx: 0, dy: 45), at: 0.4)
        #expect(lastProgress(outputs)?.steps == [.up, .up])
    }

    @Test func pauseIsDetectedFromEventTimingWithoutTicks() {
        var gesture = recognizer()
        _ = gesture.handle(.touchDown, at: 0)
        _ = gesture.handle(.scroll(dx: -45, dy: 0), at: 0.01)
        let outputs = gesture.handle(.scroll(dx: -45, dy: 0), at: 0.5)
        #expect(lastProgress(outputs)?.steps == [.left, .left])
    }

    @Test func oppositeDirectionUndoesTheLastStep() {
        var gesture = recognizer()
        _ = gesture.handle(.touchDown, at: 0)
        _ = gesture.handle(.scroll(dx: 45, dy: 0), at: 0.01)
        _ = gesture.handle(.scroll(dx: 0, dy: -45), at: 0.05)
        #expect(gesture.progress.steps == [.right, .down])
        let outputs = gesture.handle(.scroll(dx: 0, dy: 45), at: 0.08)
        #expect(lastProgress(outputs)?.steps == [.right])
    }

    @Test func diagonalSwipeProducesAQuarterInOneMove() {
        var gesture = recognizer()
        _ = gesture.handle(.touchDown, at: 0)
        let outputs = gesture.handle(.scroll(dx: 40, dy: -38), at: 0.02)
        #expect(lastProgress(outputs)?.steps == [.right, .down])
    }

    @Test func horizontalSwipeWithSomeDriftStaysHorizontal() {
        var gesture = recognizer()
        _ = gesture.handle(.touchDown, at: 0)
        let outputs = gesture.handle(.scroll(dx: 45, dy: 20), at: 0.02)
        #expect(lastProgress(outputs)?.steps == [.right])
    }

    @Test func holdingStillRecognizesTapAndHold() {
        var gesture = recognizer()
        _ = gesture.handle(.touchDown, at: 0)
        #expect(gesture.handle(.tick, at: 0.2).isEmpty)
        #expect(gesture.handle(.tick, at: 0.36) == [.progressed(GestureProgress(steps: [], held: true))])
        _ = gesture.handle(.scroll(dx: -45, dy: 0), at: 0.5)
        #expect(gesture.progress == GestureProgress(steps: [.left], held: true))
    }

    @Test func holdIsOffWhenDisabled() {
        var gesture = recognizer(holdDuration: nil)
        _ = gesture.handle(.touchDown, at: 0)
        #expect(gesture.handle(.tick, at: 1).isEmpty)
        #expect(gesture.handle(.scrollLift, at: 1.1) == [.finished(nil)])
    }

    @Test func quickTapFinishesWithNothing() {
        var gesture = recognizer()
        _ = gesture.handle(.touchDown, at: 0)
        #expect(gesture.handle(.scrollLift, at: 0.1) == [.finished(nil)])
        #expect(gesture.isIdle)
    }

    @Test func holdThenLiftFinishesAfterTheGracePeriod() {
        var gesture = recognizer()
        _ = gesture.handle(.touchDown, at: 0)
        _ = gesture.handle(.tick, at: 0.4)
        #expect(gesture.handle(.scrollLift, at: 0.5).isEmpty)
        #expect(gesture.handle(.tick, at: 0.55).isEmpty)
        #expect(gesture.handle(.tick, at: 0.7) == [.finished(GestureProgress(steps: [], held: true))])
    }

    @Test func holdThenPinchKeepsTheHold() {
        var gesture = recognizer()
        _ = gesture.handle(.touchDown, at: 0)
        _ = gesture.handle(.tick, at: 0.4)
        _ = gesture.handle(.scrollLift, at: 0.5)
        _ = gesture.handle(.pinchBegan, at: 0.52)
        let outputs = gesture.handle(.pinch(-0.3), at: 0.55)
        #expect(lastProgress(outputs) == GestureProgress(steps: [.pinchIn], held: true))
        #expect(gesture.handle(.pinchEnded, at: 0.7) == [.finished(GestureProgress(steps: [.pinchIn], held: true))])
    }

    @Test func pinchInTwiceNeedsAPause() {
        var gesture = recognizer()
        _ = gesture.handle(.pinchBegan, at: 0)
        _ = gesture.handle(.pinch(-0.15), at: 0.01)
        _ = gesture.handle(.pinch(-0.15), at: 0.02)
        #expect(gesture.progress.steps == [.pinchIn])
        _ = gesture.handle(.pinch(-0.3), at: 0.05)
        #expect(gesture.progress.steps == [.pinchIn])
        #expect(gesture.handle(.tick, at: 0.4) == [.rearmed])
        _ = gesture.handle(.pinch(-0.3), at: 0.45)
        #expect(gesture.progress.steps == [.pinchIn, .pinchIn])
    }

    @Test func pinchOutAfterPinchInUndoes() {
        var gesture = recognizer()
        _ = gesture.handle(.pinchBegan, at: 0)
        _ = gesture.handle(.pinch(-0.3), at: 0.01)
        _ = gesture.handle(.pinch(0.3), at: 0.05)
        #expect(gesture.progress.steps.isEmpty)
        #expect(gesture.handle(.pinchEnded, at: 0.1) == [.finished(nil)])
    }

    @Test func scrollCancelDuringAPinchDoesNotEndIt() {
        var gesture = recognizer()
        _ = gesture.handle(.touchDown, at: 0)
        _ = gesture.handle(.pinchBegan, at: 0.02)
        #expect(gesture.handle(.scrollLift, at: 0.03).isEmpty)
        _ = gesture.handle(.pinch(0.3), at: 0.05)
        #expect(gesture.handle(.pinchEnded, at: 0.1) == [.finished(GestureProgress(steps: [.pinchOut]))])
    }

    @Test func restingCancelsAfterTheTimeout() {
        var gesture = recognizer()
        _ = gesture.handle(.touchDown, at: 0)
        _ = gesture.handle(.scroll(dx: 45, dy: 0), at: 0.01)
        _ = gesture.handle(.tick, at: 0.4)
        #expect(gesture.handle(.tick, at: 1.6) == [.cancelled])
        #expect(gesture.isSpent)
        #expect(gesture.handle(.scroll(dx: -90, dy: 0), at: 1.7).isEmpty)
        #expect(gesture.handle(.scrollLift, at: 1.8) == [.finished(nil)])
    }

    @Test func escapeCancels() {
        var gesture = recognizer()
        _ = gesture.handle(.touchDown, at: 0)
        _ = gesture.handle(.scroll(dx: 45, dy: 0), at: 0.01)
        #expect(gesture.handle(.escape, at: 0.1) == [.cancelled])
        #expect(gesture.handle(.scrollLift, at: 0.2) == [.finished(nil)])
    }

    @Test func clearedStepsStillNeedAPauseToRepeat() {
        var gesture = recognizer()
        _ = gesture.handle(.touchDown, at: 0)
        _ = gesture.handle(.scroll(dx: 45, dy: 0), at: 0.01)
        gesture.clearSteps()
        #expect(gesture.handle(.scroll(dx: 45, dy: 0), at: 0.03).isEmpty)
        let outputs = gesture.handle(.scroll(dx: 0, dy: 45), at: 0.05)
        #expect(lastProgress(outputs)?.steps == [.up])
    }

    @Test func continuousModeRepeatsWithoutPausing() {
        var gesture = recognizer()
        _ = gesture.handle(.touchDown, at: 0)
        gesture.repeatsWithoutPause = true
        _ = gesture.handle(.scroll(dx: 45, dy: 0), at: 0.01)
        _ = gesture.handle(.scroll(dx: 45, dy: 0), at: 0.02)
        _ = gesture.handle(.scroll(dx: -45, dy: 0), at: 0.03)
        #expect(gesture.progress.steps == [.right, .right, .left])
    }

    @Test func sensitivityScalesTheStepDistance() {
        let sensitive = WindowGestureRecognizer.Configuration.make(sensitivity: 2, holds: true)
        let sluggish = WindowGestureRecognizer.Configuration.make(sensitivity: 0.5, holds: false)
        let clamped = WindowGestureRecognizer.Configuration.make(sensitivity: 50, holds: true)
        #expect(sensitive.stepDistance == 20)
        #expect(sensitive.holdDuration != nil)
        #expect(sluggish.stepDistance == 80)
        #expect(sluggish.holdDuration == nil)
        #expect(clamped.stepDistance == 20)
    }

    @Test func clearingStepsConsumesTheHold() {
        var gesture = recognizer()
        _ = gesture.handle(.touchDown, at: 0)
        _ = gesture.handle(.tick, at: 0.4)
        #expect(gesture.progress.held)
        gesture.clearSteps()
        #expect(!gesture.progress.held)
        #expect(gesture.handle(.tick, at: 0.8).isEmpty)
        let outputs = gesture.handle(.scroll(dx: -45, dy: 0), at: 0.9)
        #expect(lastProgress(outputs) == GestureProgress(steps: [.left], held: false))
    }

    @Test func swipingBackPastTheStartOnlyCancels() {
        var gesture = recognizer()
        _ = gesture.handle(.touchDown, at: 0)
        _ = gesture.handle(.scroll(dx: 45, dy: 0), at: 0.01)
        _ = gesture.handle(.scroll(dx: -45, dy: 0), at: 0.03)
        #expect(gesture.progress.steps.isEmpty)
        #expect(gesture.handle(.scroll(dx: -90, dy: 0), at: 0.05).isEmpty)
        #expect(gesture.progress.steps.isEmpty)
        let outputs = gesture.handle(.scroll(dx: -45, dy: 0), at: 0.5)
        #expect(lastProgress(outputs)?.steps == [.left])
    }

    @Test func backingOutOfAQuarterStaysOnTheHalfUntilAPause() {
        var gesture = recognizer()
        _ = gesture.handle(.touchDown, at: 0)
        _ = gesture.handle(.scroll(dx: 45, dy: 0), at: 0.01)
        _ = gesture.handle(.scroll(dx: 0, dy: -45), at: 0.03)
        _ = gesture.handle(.scroll(dx: 0, dy: 45), at: 0.05)
        _ = gesture.handle(.scroll(dx: 0, dy: 45), at: 0.07)
        #expect(gesture.progress.steps == [.right])
        _ = gesture.handle(.scroll(dx: 0, dy: 45), at: 0.5)
        #expect(gesture.progress.steps == [.right, .up])
    }

    @Test func cancelledPinchDoesNotCommit() {
        var gesture = recognizer()
        _ = gesture.handle(.pinchBegan, at: 0)
        _ = gesture.handle(.pinch(-0.3), at: 0.01)
        #expect(gesture.progress.steps == [.pinchIn])
        #expect(gesture.handle(.pinchCancelled, at: 0.05) == [.finished(nil)])
        #expect(gesture.isIdle)
    }
}
