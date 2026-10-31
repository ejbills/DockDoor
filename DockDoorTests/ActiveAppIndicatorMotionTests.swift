import CoreGraphics
@testable import DockDoor
import Testing

struct ActiveAppIndicatorMotionTests {
    private let interval = 1.0 / 120.0

    private func frame(_ x: CGFloat, _ y: CGFloat = 10) -> CGRect {
        CGRect(x: x, y: y, width: 20, height: 4)
    }

    @Test func firstSampleDoesNotJump() {
        var predictor = ActiveAppIndicatorMotionPredictor()
        #expect(predictor.project(frame(10), at: 0, presentationTime: interval) == frame(10))
    }

    @Test func steadyMovementPredictsOneRefresh() {
        var predictor = ActiveAppIndicatorMotionPredictor()
        _ = predictor.project(frame(0), at: 0, presentationTime: interval)
        let result = predictor.project(frame(2), at: interval, presentationTime: interval * 2)
        #expect(abs(result.minX - 4) < 0.001)
        #expect(result.size == frame(2).size)
    }

    @Test func stoppedIconSettlesOnNextRefresh() {
        var predictor = ActiveAppIndicatorMotionPredictor()
        _ = predictor.project(frame(0), at: 0, presentationTime: interval)
        _ = predictor.project(frame(2), at: interval, presentationTime: interval * 2)
        #expect(predictor.project(frame(2), at: interval * 2, presentationTime: interval * 3) == frame(2))
    }

    @Test func reversalDoesNotProjectInEitherDirection() {
        var predictor = ActiveAppIndicatorMotionPredictor()
        _ = predictor.project(frame(0), at: 0, presentationTime: interval)
        _ = predictor.project(frame(2), at: interval, presentationTime: interval * 2)
        #expect(predictor.project(frame(1), at: interval * 2, presentationTime: interval * 3) == frame(1))
    }

    @Test func projectionIsLimitedToThreePoints() {
        var predictor = ActiveAppIndicatorMotionPredictor()
        _ = predictor.project(frame(0, 0), at: 0, presentationTime: interval)
        let result = predictor.project(frame(10, 10), at: interval, presentationTime: interval * 10)
        #expect(abs(hypot(result.minX - 10, result.minY - 10) - 3) < 0.001)
    }

    @Test func largeJumpAndLongPauseDoNotPredict() {
        var predictor = ActiveAppIndicatorMotionPredictor()
        _ = predictor.project(frame(0), at: 0, presentationTime: interval)
        #expect(predictor.project(frame(100), at: interval, presentationTime: interval * 2) == frame(100))
        #expect(predictor.project(frame(101), at: 1, presentationTime: 1 + interval) == frame(101))
    }

    @Test func resetAndExpiredPresentationDoNotPredict() {
        var predictor = ActiveAppIndicatorMotionPredictor()
        _ = predictor.project(frame(0), at: 0, presentationTime: interval)
        #expect(predictor.project(frame(2), at: interval, presentationTime: 0) == frame(2))
        predictor.reset()
        #expect(predictor.project(frame(100), at: interval * 2, presentationTime: interval * 3) == frame(100))
    }
}
