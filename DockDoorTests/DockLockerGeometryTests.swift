import CoreGraphics
@testable import DockDoor
import Testing

// MARK: - EdgeInterval Tests

struct EdgeIntervalTests {
    // MARK: Merge

    @Test func mergeAdjacentIntervals() {
        let intervals = [
            EdgeInterval(start: 0, end: 100),
            EdgeInterval(start: 100, end: 200),
            EdgeInterval(start: 50, end: 150),
        ]
        let merged = EdgeInterval.merge(intervals)
        #expect(merged.count == 1)
        #expect(merged[0] == EdgeInterval(start: 0, end: 200))
    }

    @Test func mergeDisjointIntervals() {
        let intervals = [
            EdgeInterval(start: 0, end: 50),
            EdgeInterval(start: 100, end: 150),
        ]
        let merged = EdgeInterval.merge(intervals)
        #expect(merged.count == 2)
        #expect(merged[0] == EdgeInterval(start: 0, end: 50))
        #expect(merged[1] == EdgeInterval(start: 100, end: 150))
    }

    @Test func mergeEmpty() {
        let merged = EdgeInterval.merge([])
        #expect(merged.isEmpty)
    }

    // MARK: Subtract

    @Test func subtractIntervals() {
        let full = EdgeInterval(start: 0, end: 1920)
        let covered = [EdgeInterval(start: 500, end: 1000)]
        let result = EdgeInterval.subtract(from: full, removing: covered)
        #expect(result.count == 2)
        #expect(result[0] == EdgeInterval(start: 0, end: 500))
        #expect(result[1] == EdgeInterval(start: 1000, end: 1920))
    }

    @Test func subtractNoOverlap() {
        let full = EdgeInterval(start: 0, end: 1920)
        let covered = [EdgeInterval(start: 2000, end: 3000)]
        let result = EdgeInterval.subtract(from: full, removing: covered)
        #expect(result.count == 1)
        #expect(result[0] == EdgeInterval(start: 0, end: 1920))
    }

    @Test func subtractFullCoverage() {
        let full = EdgeInterval(start: 0, end: 1920)
        let covered = [EdgeInterval(start: -100, end: 2000)]
        let result = EdgeInterval.subtract(from: full, removing: covered)
        #expect(result.isEmpty)
    }

    @Test func subtractMultipleGaps() {
        let full = EdgeInterval(start: 0, end: 1000)
        let covered = [
            EdgeInterval(start: 100, end: 300),
            EdgeInterval(start: 500, end: 700),
        ]
        let result = EdgeInterval.subtract(from: full, removing: covered)
        #expect(result.count == 3)
        #expect(result[0] == EdgeInterval(start: 0, end: 100))
        #expect(result[1] == EdgeInterval(start: 300, end: 500))
        #expect(result[2] == EdgeInterval(start: 700, end: 1000))
    }
}

// MARK: - Trigger Zone Calculation Tests

struct TriggerZoneCalculationTests {
    // Two 1920x1080 screens side by side (CG coordinates: origin top-left, Y down)
    // Left screen:  (0, 0, 1920, 1080)
    // Right screen: (1920, 0, 1920, 1080)

    @Test func twoScreensSideBySide_BottomDock_LockedLeft() {
        let frames = [
            CGRect(x: 0, y: 0, width: 1920, height: 1080),
            CGRect(x: 1920, y: 0, width: 1920, height: 1080),
        ]
        let zones = DockLockerGeometry.calculateTriggerZones(
            screenFrames: frames, lockedScreenIndex: 0, dockPosition: .bottom
        )
        // Right screen's bottom edge should be blocked
        #expect(zones.count == 1)
        #expect(zones[0].rect.minX == 1920)
        #expect(zones[0].rect.maxX == 3840)
        #expect(zones[0].rect.maxY == 1080)
        #expect(zones[0].rect.height == 7)
        #expect(zones[0].nudgeVector == CGVector(dx: 0, dy: -7))
    }

    @Test func twoScreensSideBySide_BottomDock_LockedRight() {
        let frames = [
            CGRect(x: 0, y: 0, width: 1920, height: 1080),
            CGRect(x: 1920, y: 0, width: 1920, height: 1080),
        ]
        let zones = DockLockerGeometry.calculateTriggerZones(
            screenFrames: frames, lockedScreenIndex: 1, dockPosition: .bottom
        )
        // Left screen's bottom edge should be blocked
        #expect(zones.count == 1)
        #expect(zones[0].rect.minX == 0)
        #expect(zones[0].rect.maxX == 1920)
    }

    @Test func twoScreensStacked_BottomDock() {
        // Top screen:    (0, 0, 1920, 1080)
        // Bottom screen: (0, 1080, 1920, 1080)
        let frames = [
            CGRect(x: 0, y: 0, width: 1920, height: 1080),
            CGRect(x: 0, y: 1080, width: 1920, height: 1080),
        ]
        let zones = DockLockerGeometry.calculateTriggerZones(
            screenFrames: frames, lockedScreenIndex: 1, dockPosition: .bottom
        )
        // Top screen's bottom edge (y=1080) is adjacent to bottom screen's top edge — fully covered
        // So no trigger zones should be produced for the top screen
        #expect(zones.isEmpty)
    }

    @Test func threeScreens_MiddleLocked() {
        let frames = [
            CGRect(x: 0, y: 0, width: 1920, height: 1080),
            CGRect(x: 1920, y: 0, width: 1920, height: 1080),
            CGRect(x: 3840, y: 0, width: 1920, height: 1080),
        ]
        let zones = DockLockerGeometry.calculateTriggerZones(
            screenFrames: frames, lockedScreenIndex: 1, dockPosition: .bottom
        )
        // Left and right screens should each have a trigger zone
        #expect(zones.count == 2)
        let leftZone = zones.first { $0.rect.minX == 0 }
        let rightZone = zones.first { $0.rect.minX == 3840 }
        #expect(leftZone != nil)
        #expect(rightZone != nil)
    }

    @Test func singleScreen_NoZones() {
        let frames = [CGRect(x: 0, y: 0, width: 1920, height: 1080)]
        let zones = DockLockerGeometry.calculateTriggerZones(
            screenFrames: frames, lockedScreenIndex: 0, dockPosition: .bottom
        )
        #expect(zones.isEmpty)
    }

    @Test func leftDock_TriggerOnLeftEdge() {
        let frames = [
            CGRect(x: 0, y: 0, width: 1920, height: 1080),
            CGRect(x: 1920, y: 0, width: 1920, height: 1080),
        ]
        let zones = DockLockerGeometry.calculateTriggerZones(
            screenFrames: frames, lockedScreenIndex: 0, dockPosition: .left
        )
        // Right screen's left edge (x=1920) is adjacent to left screen's right edge — blocked by adjacency
        // Since left screen's right edge meets right screen's left edge, the left edge of right screen is fully covered
        // So there should be no trigger zones (the screens are adjacent at x=1920)
        #expect(zones.isEmpty)
    }

    @Test func leftDock_NonAdjacentScreens() {
        // Two screens with a gap between them
        let frames = [
            CGRect(x: 0, y: 0, width: 1920, height: 1080),
            CGRect(x: 2000, y: 0, width: 1920, height: 1080),
        ]
        let zones = DockLockerGeometry.calculateTriggerZones(
            screenFrames: frames, lockedScreenIndex: 0, dockPosition: .left
        )
        // Right screen's left edge is NOT adjacent (80px gap) so it should have a trigger zone
        #expect(zones.count == 1)
        #expect(zones[0].rect.minX == 2000)
        #expect(zones[0].rect.width == 7)
        #expect(zones[0].nudgeVector == CGVector(dx: 7, dy: 0))
    }

    @Test func rightDock_TriggerOnRightEdge() {
        // Two screens with a gap
        let frames = [
            CGRect(x: 0, y: 0, width: 1920, height: 1080),
            CGRect(x: 2000, y: 0, width: 1920, height: 1080),
        ]
        let zones = DockLockerGeometry.calculateTriggerZones(
            screenFrames: frames, lockedScreenIndex: 1, dockPosition: .right
        )
        // Left screen's right edge (x=1920) is NOT adjacent to right screen (gap), so trigger zone on right edge
        #expect(zones.count == 1)
        #expect(zones[0].rect.maxX == 1920)
        #expect(zones[0].rect.width == 7)
        #expect(zones[0].nudgeVector == CGVector(dx: -7, dy: 0))
    }

    @Test func partiallyBlockedEdge() {
        // Primary: large screen (0, 0, 2560, 1440)
        // Secondary: shorter screen offset to the right, below primary
        //   (1920, 1440, 1920, 1080) — sits below the right portion of primary
        let frames = [
            CGRect(x: 0, y: 0, width: 2560, height: 1440),
            CGRect(x: 1920, y: 1440, width: 1920, height: 1080),
        ]
        let zones = DockLockerGeometry.calculateTriggerZones(
            screenFrames: frames, lockedScreenIndex: 1, dockPosition: .bottom
        )
        // Primary's bottom edge (y=1440) is partially blocked by secondary (x: 1920..3840)
        // But secondary only covers x: 1920..2560 of primary's edge (primary ends at 2560)
        // So exposed portion of primary's bottom edge is x: 0..1920
        #expect(zones.count == 1)
        let zone = zones[0]
        #expect(abs(zone.rect.minX - 0) < 1)
        #expect(abs(zone.rect.maxX - 1920) < 1)
        #expect(zone.rect.maxY == 1440)
        #expect(zone.rect.height == 7)
    }

    @Test func unsupportedDockPosition_NoZones() {
        let frames = [
            CGRect(x: 0, y: 0, width: 1920, height: 1080),
            CGRect(x: 1920, y: 0, width: 1920, height: 1080),
        ]
        // .unknown, .cmdTab, .cli, and .top are not supported dock positions for locking
        let zones = DockLockerGeometry.calculateTriggerZones(
            screenFrames: frames, lockedScreenIndex: 0, dockPosition: .unknown
        )
        #expect(zones.isEmpty)
    }
}
