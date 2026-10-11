import CoreGraphics
@testable import DockDoor
import Testing

struct WindowPositionRectTests {
    private let screen = CGRect(x: 0, y: 0, width: 1200, height: 800)

    @Test func halvesSplitTheVisibleFrame() {
        #expect(WindowInfo.WindowPositionRect.leftHalf.frame(in: screen) == CGRect(x: 0, y: 0, width: 600, height: 800))
        #expect(WindowInfo.WindowPositionRect.rightHalf.frame(in: screen) == CGRect(x: 600, y: 0, width: 600, height: 800))
        #expect(WindowInfo.WindowPositionRect.full.frame(in: screen) == screen)
    }

    @Test func quartersUseTopRowFirst() {
        #expect(WindowInfo.WindowPositionRect.topLeftQuarter.frame(in: screen) == CGRect(x: 0, y: 400, width: 600, height: 400))
        #expect(WindowInfo.WindowPositionRect.topRightQuarter.frame(in: screen) == CGRect(x: 600, y: 400, width: 600, height: 400))
        #expect(WindowInfo.WindowPositionRect.bottomLeftQuarter.frame(in: screen) == CGRect(x: 0, y: 0, width: 600, height: 400))
        #expect(WindowInfo.WindowPositionRect.bottomRightQuarter.frame(in: screen) == CGRect(x: 600, y: 0, width: 600, height: 400))
    }

    @Test func halvesTileWithoutGaps() {
        let odd = CGRect(x: 0, y: 25, width: 1511, height: 875)
        let left = WindowInfo.WindowPositionRect.leftHalf.frame(in: odd)
        let right = WindowInfo.WindowPositionRect.rightHalf.frame(in: odd)
        #expect(left.maxX == right.minX)
        #expect(right.maxX == odd.maxX)
    }

    @Test func framesFollowTheScreenOrigin() {
        let secondScreen = CGRect(x: 1200, y: -200, width: 1000, height: 600)
        #expect(WindowInfo.WindowPositionRect.rightHalf.frame(in: secondScreen) == CGRect(x: 1700, y: -200, width: 500, height: 600))
    }

    @Test func centerKeepsTheSizeAndFitsTheScreen() {
        let centered = WindowInfo.WindowPositionRect.center.frame(in: screen, currentSize: CGSize(width: 400, height: 300))
        #expect(centered == CGRect(x: 400, y: 250, width: 400, height: 300))
        let oversized = WindowInfo.WindowPositionRect.center.frame(in: screen, currentSize: CGSize(width: 2000, height: 300))
        #expect(oversized == CGRect(x: 0, y: 250, width: 1200, height: 300))
    }
}
