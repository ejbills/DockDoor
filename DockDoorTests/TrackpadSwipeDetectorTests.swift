import CoreGraphics
@testable import DockDoor
import Testing

struct TrackpadSwipeDetectorTests {
    private func fingers(_ count: Int, x: CGFloat, y: CGFloat = 0.5, spacing: CGFloat = 0.1) -> [SwipeTouch] {
        (0 ..< count).map { SwipeTouch(id: $0, position: CGPoint(x: x + CGFloat($0) * spacing, y: y)) }
    }

    private func open(_ detector: inout TrackpadSwipeDetector, fingerCount: Int = 3) {
        _ = detector.handle(fingers(fingerCount, x: 0.2), fingers: fingerCount, horizontal: true)
        #expect(detector.handle(fingers(fingerCount, x: 0.25), fingers: fingerCount, horizontal: true) == .open)
    }

    @Test func horizontalSwipeOpens() {
        var detector = TrackpadSwipeDetector()
        open(&detector)
        #expect(detector.isSwitching)
    }

    @Test func swipeInEitherDirectionOpens() {
        var detector = TrackpadSwipeDetector()
        _ = detector.handle(fingers(3, x: 0.4), fingers: 3, horizontal: true)
        #expect(detector.handle(fingers(3, x: 0.35), fingers: 3, horizontal: true) == .open)
    }

    @Test func firstFrameOnlyRecordsStartPositions() {
        var detector = TrackpadSwipeDetector()
        #expect(detector.handle(fingers(3, x: 0.9), fingers: 3, horizontal: true) == nil)
    }

    @Test func shortSwipeDoesNotOpen() {
        var detector = TrackpadSwipeDetector()
        _ = detector.handle(fingers(3, x: 0.2), fingers: 3, horizontal: true)
        #expect(detector.handle(fingers(3, x: 0.21), fingers: 3, horizontal: true) == nil)
    }

    @Test func verticalSwipeOnlyOpensWhenConfigured() {
        var horizontal = TrackpadSwipeDetector()
        _ = horizontal.handle(fingers(3, x: 0.2, y: 0.2), fingers: 3, horizontal: true)
        #expect(horizontal.handle(fingers(3, x: 0.2, y: 0.26), fingers: 3, horizontal: true) == nil)

        var vertical = TrackpadSwipeDetector()
        _ = vertical.handle(fingers(3, x: 0.2, y: 0.2), fingers: 3, horizontal: false)
        #expect(vertical.handle(fingers(3, x: 0.2, y: 0.26), fingers: 3, horizontal: false) == .open)
    }

    @Test func wrongFingerCountDoesNotOpen() {
        var detector = TrackpadSwipeDetector()
        _ = detector.handle(fingers(3, x: 0.2), fingers: 4, horizontal: true)
        #expect(detector.handle(fingers(3, x: 0.3), fingers: 4, horizontal: true) == nil)

        _ = detector.handle(fingers(2, x: 0.2), fingers: 3, horizontal: true)
        #expect(detector.handle(fingers(2, x: 0.3), fingers: 3, horizontal: true) == nil)
    }

    @Test func fourFingersOpenWhenConfigured() {
        var detector = TrackpadSwipeDetector()
        open(&detector, fingerCount: 4)
    }

    @Test func pinchDoesNotOpen() {
        var detector = TrackpadSwipeDetector()
        _ = detector.handle(fingers(3, x: 0.2, spacing: 0.2), fingers: 3, horizontal: true)
        let pinched = [
            SwipeTouch(id: 0, position: CGPoint(x: 0.26, y: 0.5)),
            SwipeTouch(id: 1, position: CGPoint(x: 0.4, y: 0.5)),
            SwipeTouch(id: 2, position: CGPoint(x: 0.54, y: 0.5)),
        ]
        #expect(detector.handle(pinched, fingers: 3, horizontal: true) == nil)
    }

    @Test func extraFingerSpendsTheGestureUntilFingersAreLifted() {
        var detector = TrackpadSwipeDetector()
        _ = detector.handle(fingers(4, x: 0.2), fingers: 3, horizontal: true)
        _ = detector.handle(fingers(3, x: 0.2), fingers: 3, horizontal: true)
        #expect(detector.handle(fingers(3, x: 0.3), fingers: 3, horizontal: true) == nil)

        _ = detector.handle([], fingers: 3, horizontal: true)
        open(&detector)
    }

    @Test func offAxisTravelSpendsTheGestureUntilFingersAreLifted() {
        var detector = TrackpadSwipeDetector()
        _ = detector.handle(fingers(3, x: 0.2, y: 0.2), fingers: 3, horizontal: true)
        #expect(detector.handle(fingers(3, x: 0.2, y: 0.4), fingers: 3, horizontal: true) == nil)
        #expect(detector.handle(fingers(3, x: 0.4, y: 0.4), fingers: 3, horizontal: true) == nil)

        _ = detector.handle([], fingers: 3, horizontal: true)
        open(&detector)
    }

    @Test func fingersArrivingOneByOneStillOpen() {
        var detector = TrackpadSwipeDetector()
        _ = detector.handle(fingers(1, x: 0.2), fingers: 3, horizontal: true)
        _ = detector.handle(fingers(2, x: 0.2), fingers: 3, horizontal: true)
        open(&detector)
    }

    @Test func movingWhileOpenCyclesSelection() {
        var detector = TrackpadSwipeDetector()
        open(&detector)
        #expect(detector.handle(fingers(3, x: 0.27), fingers: 3, horizontal: true) == nil)
        #expect(detector.handle(fingers(3, x: 0.3), fingers: 3, horizontal: true) == .cycleForward)
        #expect(detector.handle(fingers(3, x: 0.35), fingers: 3, horizontal: true) == .cycleForward)
        #expect(detector.handle(fingers(3, x: 0.3), fingers: 3, horizontal: true) == .cycleBackward)
    }

    @Test func liftingFingersReleases() {
        var detector = TrackpadSwipeDetector()
        open(&detector)
        #expect(detector.handle([], fingers: 3, horizontal: true) == .release)
        #expect(!detector.isSwitching)
        #expect(detector.handle([], fingers: 3, horizontal: true) == nil)
    }

    @Test func liftingOneFingerReleasesOnceAndDoesNotReopen() {
        var detector = TrackpadSwipeDetector()
        open(&detector)
        #expect(detector.handle(fingers(2, x: 0.25), fingers: 3, horizontal: true) == .release)
        #expect(detector.handle(fingers(2, x: 0.4), fingers: 3, horizontal: true) == nil)
        #expect(detector.handle(fingers(3, x: 0.4), fingers: 3, horizontal: true) == nil)
        #expect(detector.handle(fingers(3, x: 0.5), fingers: 3, horizontal: true) == nil)
    }
}
