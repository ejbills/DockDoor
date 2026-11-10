import ApplicationServices
import Cocoa
import CoreGraphics
import Defaults
@testable import DockDoor
import Foundation
import Testing

// MARK: - NativeTabGrouping Tests

@Suite(.serialized)
struct NativeTabGroupingTests {
    private func candidate(
        id: CGWindowID,
        pid: pid_t = 100,
        frame: CGRect = CGRect(x: 0, y: 0, width: 800, height: 600),
        recency: TimeInterval = 0,
        groupable: Bool = true,
        isOnScreen: Bool = false
    ) -> NativeTabGrouping.Candidate {
        NativeTabGrouping.Candidate(
            id: id,
            pid: pid,
            frame: frame,
            recency: Date(timeIntervalSinceReferenceDate: recency),
            groupable: groupable,
            isOnScreen: isOnScreen
        )
    }

    @Test func keepsAllOnScreenWindowsSharingAFrame() {
        let frame = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let kept = NativeTabGrouping.representativeIDs(from: [
            candidate(id: 1, frame: frame, recency: 0, isOnScreen: true),
            candidate(id: 2, frame: frame, recency: 5, isOnScreen: true),
        ])
        #expect(kept == [1, 2])
    }

    @Test func collapsesOffScreenTabsIntoTheOnScreenWindow() {
        let frame = CGRect(x: 149, y: 148, width: 1363, height: 694)
        let kept = NativeTabGrouping.representativeIDs(from: [
            candidate(id: 1, frame: frame, recency: 9, isOnScreen: false),
            candidate(id: 2, frame: frame, recency: 1, isOnScreen: true),
            candidate(id: 3, frame: CGRect(x: 120, y: 119, width: 1363, height: 694), recency: 0, isOnScreen: true),
        ])
        #expect(kept == [2, 3])
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
        // The non-groupable window (id 2) is always kept; the two groupable
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

    @Test @MainActor func collapsesMinimizedNativeTabsWhenEnabled() throws {
        let originalSetting = Defaults[.collapseNativeTabsIntoSingleWindow]
        defer { Defaults[.collapseNativeTabsIntoSingleWindow] = originalSetting }

        let app = NSRunningApplication.current
        let appAX = AXUIElementCreateApplication(app.processIdentifier)
        let frame = CGRect(x: 10, y: 20, width: 800, height: 600)
        let windows = [1.0, 3.0, 2.0].enumerated().map { index, recency in
            WindowInfo(
                windowProvider: MockPreviewWindow(
                    windowID: CGWindowID.max - CGWindowID(index + 1),
                    frame: frame,
                    title: "Tab \(index)",
                    owningApplicationBundleIdentifier: app.bundleIdentifier,
                    owningApplicationProcessID: app.processIdentifier,
                    isOnScreen: false,
                    windowLayer: 0
                ),
                app: app,
                image: nil,
                axElement: appAX,
                appAxElement: appAX,
                closeButton: nil,
                lastAccessedTime: Date(timeIntervalSinceReferenceDate: recency),
                isMinimized: true,
                isHidden: false,
                readsAXTitle: false
            )
        }
        let onScreenWindows = try #require(
            CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]]
        )
        let onScreenIDs = Set(onScreenWindows.compactMap { $0[kCGWindowNumber as String] as? CGWindowID })
        try #require(windows.allSatisfy { !onScreenIDs.contains($0.id) })

        Defaults[.collapseNativeTabsIntoSingleWindow] = false
        let uncollapsed = WindowUtil.collapseNativeTabsIfNeeded(windows)
        #expect(uncollapsed.map(\.id) == windows.map(\.id))
        #expect(uncollapsed.allSatisfy(\.isMinimized))

        Defaults[.collapseNativeTabsIntoSingleWindow] = true
        let collapsed = WindowUtil.collapseNativeTabsIfNeeded(windows)
        #expect(collapsed.map(\.id) == [windows[1].id])
        #expect(collapsed.first?.isMinimized == true)
        #expect(WindowUtil.collapseNativeTabsIfNeeded(collapsed).map(\.id) == collapsed.map(\.id))

        var differentFrames = windows
        differentFrames[0].frame = frame.offsetBy(dx: 100, dy: 100)
        let separateGroups = WindowUtil.collapseNativeTabsIfNeeded(differentFrames)
        #expect(separateGroups.map(\.id) == [windows[0].id, windows[1].id])
        #expect(WindowUtil.collapseNativeTabsIfNeeded(separateGroups).map(\.id) == separateGroups.map(\.id))

        var mixedMinimizeState = windows
        mixedMinimizeState[0].isMinimized = false
        #expect(WindowUtil.collapseNativeTabsIfNeeded(mixedMinimizeState).map(\.id) == [windows[1].id])

        var hiddenWindows = windows
        hiddenWindows[0].isHidden = true
        #expect(WindowUtil.collapseNativeTabsIfNeeded(hiddenWindows).map(\.id) == [windows[0].id, windows[1].id])

        var windowless = WindowInfo.windowlessEntry(for: app)
        windowless.frame = frame
        #expect(WindowUtil.collapseNativeTabsIfNeeded(windows + [windowless]).map(\.id) == [windows[1].id, windowless.id])

        let zeroSized = windows.map { window in
            var window = window
            window.frame = .zero
            return window
        }
        #expect(WindowUtil.collapseNativeTabsIfNeeded(zeroSized).map(\.id) == windows.map(\.id))
    }
}
