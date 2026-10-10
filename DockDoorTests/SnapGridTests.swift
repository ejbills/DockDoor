import CoreGraphics
@testable import DockDoor
import Testing

struct SnapGridTests {
    private let screen = CGRect(x: 0, y: 0, width: 1200, height: 800)

    @Test func halvesSplitTheVisibleFrame() {
        #expect(SnapRegion.leftHalf.frame(in: screen) == CGRect(x: 0, y: 0, width: 600, height: 800))
        #expect(SnapRegion.rightHalf.frame(in: screen) == CGRect(x: 600, y: 0, width: 600, height: 800))
        #expect(SnapRegion.topHalf.frame(in: screen) == CGRect(x: 0, y: 400, width: 1200, height: 400))
        #expect(SnapRegion.bottomHalf.frame(in: screen) == CGRect(x: 0, y: 0, width: 1200, height: 400))
    }

    @Test func quartersUseTopRowFirst() {
        #expect(SnapRegion.topLeftQuarter.frame(in: screen) == CGRect(x: 0, y: 400, width: 600, height: 400))
        #expect(SnapRegion.bottomRightQuarter.frame(in: screen) == CGRect(x: 600, y: 0, width: 600, height: 400))
    }

    @Test func thirdsAndTwoThirdsTileExactly() {
        let leftThird = SnapRegion(columns: 3, rows: 1, columnSpan: 0 ... 0, rowSpan: 0 ... 0).frame(in: screen)
        let rightTwoThirds = SnapRegion(columns: 3, rows: 1, columnSpan: 1 ... 2, rowSpan: 0 ... 0).frame(in: screen)
        #expect(leftThird == CGRect(x: 0, y: 0, width: 400, height: 800))
        #expect(rightTwoThirds == CGRect(x: 400, y: 0, width: 800, height: 800))
    }

    @Test func spacingLeavesGapsBetweenAndAroundWindows() {
        let left = SnapRegion.leftHalf.frame(in: screen, spacing: 10, includeEdges: true)
        let right = SnapRegion.rightHalf.frame(in: screen, spacing: 10, includeEdges: true)
        #expect(left == CGRect(x: 10, y: 10, width: 585, height: 780))
        #expect(right == CGRect(x: 605, y: 10, width: 585, height: 780))
        #expect(right.minX - left.maxX == 10)
    }

    @Test func spacingWithoutEdgesOnlySeparatesWindows() {
        let left = SnapRegion.leftHalf.frame(in: screen, spacing: 10, includeEdges: false)
        let right = SnapRegion.rightHalf.frame(in: screen, spacing: 10, includeEdges: false)
        #expect(left == CGRect(x: 0, y: 0, width: 595, height: 800))
        #expect(right == CGRect(x: 605, y: 0, width: 595, height: 800))
    }

    @Test func framesFollowTheScreenOrigin() {
        let secondScreen = CGRect(x: 1200, y: -200, width: 1000, height: 600)
        #expect(SnapRegion.rightHalf.frame(in: secondScreen) == CGRect(x: 1700, y: -200, width: 500, height: 600))
    }

    @Test func almostMaximizeLeavesAMargin() {
        let frame = SnapRegion.almostMaximize.frame(in: screen)
        #expect(frame == CGRect(x: 32, y: 32, width: 1136, height: 736))
    }

    @Test func transposedRegionsSwapAxes() {
        let region = SnapRegion(columns: 3, rows: 2, columnSpan: 0 ... 1, rowSpan: 1 ... 1).transposed
        #expect(region == SnapRegion(columns: 2, rows: 3, columnSpan: 1 ... 1, rowSpan: 0 ... 1))
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
