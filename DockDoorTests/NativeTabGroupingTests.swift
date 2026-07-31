import AppKit
import ApplicationServices
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
        isFocused: Bool = false,
        groupable: Bool = true
    ) -> NativeTabGrouping.Candidate {
        NativeTabGrouping.Candidate(
            id: id,
            pid: pid,
            frame: frame,
            recency: Date(timeIntervalSinceReferenceDate: recency),
            isFocused: isFocused,
            groupable: groupable
        )
    }

    private func window(
        id: CGWindowID,
        frame: CGRect,
        recency: TimeInterval
    ) -> WindowInfo {
        let app = NSRunningApplication.current
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        return WindowInfo(
            windowProvider: MockPreviewWindow(
                windowID: id,
                frame: frame,
                title: "Terminal",
                owningApplicationBundleIdentifier: app.bundleIdentifier,
                owningApplicationProcessID: app.processIdentifier,
                isOnScreen: true,
                windowLayer: 0
            ),
            app: app,
            image: nil,
            axElement: appElement,
            appAxElement: appElement,
            closeButton: nil,
            lastAccessedTime: Date(timeIntervalSinceReferenceDate: recency),
            isMinimized: false,
            isHidden: false
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

    @Test func focusedMemberWinsWhenIdenticalTitlesHaveEqualRecency() {
        let kept = NativeTabGrouping.representativeIDs(from: [
            candidate(id: 7, recency: 3),
            candidate(id: 42, recency: 3, isFocused: true),
        ])
        #expect(kept == [42])
    }

    @Test func focusedMemberWinsAfterRestartWithStaleRecency() {
        let kept = NativeTabGrouping.representativeIDs(from: [
            candidate(id: 7, recency: 100),
            candidate(id: 42, recency: 0, isFocused: true),
        ])
        #expect(kept == [42])
    }

    @Test func focusedMemberWinsAfterRapidlySwitchingAway() {
        let kept = NativeTabGrouping.representativeIDs(from: [
            candidate(id: 7, recency: 50),
            candidate(id: 42, recency: 49, isFocused: true),
        ])
        #expect(kept == [42])
    }

    @Test func collapsesMultipleTabbedWindowsIndependently() {
        let firstFrame = CGRect(x: 0, y: 0, width: 800, height: 600)
        let secondFrame = CGRect(x: 100, y: 100, width: 900, height: 700)
        let groups = NativeTabGrouping.groups(from: [
            candidate(id: 1, frame: firstFrame, recency: 10),
            candidate(id: 2, frame: firstFrame, recency: 0, isFocused: true),
            candidate(id: 3, frame: secondFrame, recency: 2),
            candidate(id: 4, frame: secondFrame, recency: 8),
        ])

        #expect(groups == [
            NativeTabGrouping.Group(representativeID: 2, memberIDs: [1, 2]),
            NativeTabGrouping.Group(representativeID: 4, memberIDs: [3, 4]),
        ])
    }

    @Test func refreshedSwitcherPathPreservesCollapsedMemberIDs() {
        let frame = CGRect(x: 0, y: 0, width: 800, height: 600)
        let pid = NSRunningApplication.current.processIdentifier
        let collapsed = WindowUtil.collapseNativeTabs(
            [
                window(id: 1, frame: frame, recency: 10),
                window(id: 2, frame: frame, recency: 0),
            ],
            focusedWindowIDsByPID: [pid: 2]
        )

        #expect(collapsed.map(\.id) == [2])
        #expect(collapsed.first?.nativeTabGroupWindowIDs == [1, 2])
    }

    @Test func cachedSwitcherPathCollapsesBeforeRefresh() {
        let frame = CGRect(x: 0, y: 0, width: 800, height: 600)
        let pid = NSRunningApplication.current.processIdentifier
        let collapsed = WindowUtil.collapseNativeTabs(
            [
                window(id: 1, frame: frame, recency: 100),
                window(id: 2, frame: frame, recency: 0),
            ],
            focusedWindowIDsByPID: [pid: 2]
        )

        #expect(collapsed.map(\.id) == [2])
    }

    @Test func activationReResolvesCurrentFocusedGroupMember() {
        let selectedID = NativeTabGrouping.activationWindowID(
            representativeID: 2,
            memberIDs: [1, 2],
            focusedWindowID: 1
        )
        #expect(selectedID == 1)
    }

    @Test func activationKeepsRepresentativeWhenFocusBelongsToAnotherTabbedWindow() {
        let selectedID = NativeTabGrouping.activationWindowID(
            representativeID: 2,
            memberIDs: [1, 2],
            focusedWindowID: 4
        )
        #expect(selectedID == 2)
    }

    @Test func emptyInputYieldsEmpty() {
        #expect(NativeTabGrouping.representativeIDs(from: []).isEmpty)
    }
}
