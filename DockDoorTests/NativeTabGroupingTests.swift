import CoreGraphics
@testable import DockDoor
import Foundation
import Testing

// MARK: - NativeTabGrouping Tests

struct NativeTabGroupingTests {
    private func candidate(
        id: CGWindowID,
        pid: pid_t = 100,
        frame: CGRect = CGRect(x: 0, y: 0, width: 800, height: 600),
        recency: TimeInterval = 0,
        groupable: Bool = true
    ) -> NativeTabGrouping.Candidate {
        NativeTabGrouping.Candidate(
            id: id,
            pid: pid,
            frame: frame,
            recency: Date(timeIntervalSinceReferenceDate: recency),
            groupable: groupable
        )
    }

    @Test func collapsesSameFrameSameProcessIntoOne() {
        let frame = CGRect(x: 10, y: 20, width: 800, height: 600)
        let kept = NativeTabGrouping.representativeIDs(from: [
            candidate(id: 1, frame: frame, recency: 0),
            candidate(id: 2, frame: frame, recency: 5),
            candidate(id: 3, frame: frame, recency: 2),
        ])
        #expect(kept == [2]) // most recently accessed represents the group
    }

    @Test func keepsWindowsWithDifferentFrames() {
        let kept = NativeTabGrouping.representativeIDs(from: [
            candidate(id: 1, frame: CGRect(x: 0, y: 0, width: 800, height: 600)),
            candidate(id: 2, frame: CGRect(x: 100, y: 100, width: 800, height: 600)),
        ])
        #expect(kept == [1, 2])
    }

    @Test func doesNotMergeAcrossProcesses() {
        let frame = CGRect(x: 0, y: 0, width: 800, height: 600)
        let kept = NativeTabGrouping.representativeIDs(from: [
            candidate(id: 1, pid: 100, frame: frame),
            candidate(id: 2, pid: 200, frame: frame),
        ])
        #expect(kept == [1, 2])
    }

    @Test func nonGroupableWindowsAreAlwaysKept() {
        let frame = CGRect(x: 0, y: 0, width: 800, height: 600)
        let kept = NativeTabGrouping.representativeIDs(from: [
            candidate(id: 1, frame: frame, recency: 0, groupable: true),
            candidate(id: 2, frame: frame, recency: 9, groupable: false),
            candidate(id: 3, frame: frame, recency: 1, groupable: true),
        ])
        // The minimized/hidden window (id 2) is always kept; the two groupable
        // tabs collapse to the more recent one (id 3).
        #expect(kept == [2, 3])
    }

    @Test func roundsSubpixelFrameDifferences() {
        let kept = NativeTabGrouping.representativeIDs(from: [
            candidate(id: 1, frame: CGRect(x: 10.2, y: 20.1, width: 800.4, height: 600.3), recency: 1),
            candidate(id: 2, frame: CGRect(x: 9.8, y: 20.4, width: 799.6, height: 600.0), recency: 2),
        ])
        #expect(kept == [2])
    }

    @Test func tieBreaksOnLargerIDDeterministically() {
        let frame = CGRect(x: 0, y: 0, width: 400, height: 400)
        let kept = NativeTabGrouping.representativeIDs(from: [
            candidate(id: 7, frame: frame, recency: 3),
            candidate(id: 42, frame: frame, recency: 3),
        ])
        #expect(kept == [42])
    }

    @Test func emptyInputYieldsEmpty() {
        #expect(NativeTabGrouping.representativeIDs(from: []).isEmpty)
    }
}
