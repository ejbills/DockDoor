import CoreGraphics
@testable import DockDoor
import Testing

struct SnapGridTests {
    private let screen = CGRect(x: 0, y: 0, width: 1200, height: 800)

    @Test func halvesSplitTheVisibleFrame() {
        #expect(SnapRegion.leftHalf.frame(in: screen) == CGRect(x: 0, y: 0, width: 600, height: 800))
        #expect(SnapRegion.rightHalf.frame(in: screen) == CGRect(x: 600, y: 0, width: 600, height: 800))
        #expect(SnapRegion.maximize.frame(in: screen) == screen)
    }

    @Test func quartersUseTopRowFirst() {
        #expect(SnapRegion.topLeftQuarter.frame(in: screen) == CGRect(x: 0, y: 400, width: 600, height: 400))
        #expect(SnapRegion.topRightQuarter.frame(in: screen) == CGRect(x: 600, y: 400, width: 600, height: 400))
        #expect(SnapRegion.bottomLeftQuarter.frame(in: screen) == CGRect(x: 0, y: 0, width: 600, height: 400))
        #expect(SnapRegion.bottomRightQuarter.frame(in: screen) == CGRect(x: 600, y: 0, width: 600, height: 400))
    }

    @Test func oddSizesTileWithoutGaps() {
        let odd = CGRect(x: 0, y: 25, width: 1511, height: 875)
        let left = SnapRegion.leftHalf.frame(in: odd)
        let right = SnapRegion.rightHalf.frame(in: odd)
        #expect(left.maxX == right.minX)
        #expect(right.maxX == odd.maxX)
    }

    @Test func framesFollowTheScreenOrigin() {
        let secondScreen = CGRect(x: 1200, y: -200, width: 1000, height: 600)
        #expect(SnapRegion.rightHalf.frame(in: secondScreen) == CGRect(x: 1700, y: -200, width: 500, height: 600))
    }

    @Test func stageManagerOffsetReservesTheStripSide() {
        let left = SnapScreenGeometry.usableFrame(visibleFrame: screen, stageManagerOffset: 140, stageManagerOnLeft: true)
        let right = SnapScreenGeometry.usableFrame(visibleFrame: screen, stageManagerOffset: 140, stageManagerOnLeft: false)
        #expect(left == CGRect(x: 140, y: 0, width: 1060, height: 800))
        #expect(right == CGRect(x: 0, y: 0, width: 1060, height: 800))
        #expect(SnapScreenGeometry.usableFrame(visibleFrame: screen, stageManagerOffset: 0, stageManagerOnLeft: true) == screen)
    }

    @Test func outOfRangeSpansAreClamped() {
        let region = SnapRegion(columns: 2, rows: 1, columnSpan: 0 ... 5, rowSpan: -1 ... 0)
        #expect(region.columnSpan == 0 ... 1)
        #expect(region.rowSpan == 0 ... 0)
    }
}
