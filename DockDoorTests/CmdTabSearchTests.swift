import AppKit
import Carbon
@testable import DockDoor
import Foundation
import Testing

struct CmdTabSelectionTrackerTests {
    @Test func echoOfOurOwnWriteIsIgnored() {
        var tracker = CmdTabSelectionTracker()
        tracker.markInSync(with: 10)

        let reported = tracker.nativeSelectionChanged(to: 10)

        #expect(reported == false)
        #expect(tracker.userMoveGeneration == 0)
    }

    @Test func genuineMoveIsReportedAndInvalidatesPendingWrites() {
        var tracker = CmdTabSelectionTracker()
        tracker.markInSync(with: 10)
        let pendingGeneration = tracker.userMoveGeneration

        let reported = tracker.nativeSelectionChanged(to: 20)

        #expect(reported)
        #expect(tracker.lastSyncedPID == 20)
        #expect(tracker.userMoveGeneration != pendingGeneration)
    }

    @Test func movingBackToAnEarlierAppIsStillAGenuineMove() {
        var tracker = CmdTabSelectionTracker()
        let moves = [10, 20, 10].map { tracker.nativeSelectionChanged(to: $0) }

        #expect(moves == [true, true, true])
        #expect(tracker.userMoveGeneration == 3)
    }

    @Test func writesAreSkippedOnlyForTheAppAlreadyHighlighted() {
        var tracker = CmdTabSelectionTracker()
        tracker.markInSync(with: 10)

        #expect(tracker.needsWrite(for: 10) == false)
        #expect(tracker.needsWrite(for: 20))
        #expect(tracker.needsWrite(for: nil))
    }

    @Test func resetNeverReusesAnEarlierGeneration() {
        var tracker = CmdTabSelectionTracker()
        _ = tracker.nativeSelectionChanged(to: 10)
        let scheduledBeforeReset = tracker.userMoveGeneration

        tracker.reset()

        #expect(tracker.userMoveGeneration != scheduledBeforeReset)
        #expect(tracker.lastSyncedPID == nil)
    }

    @Test func aFailedWriteDisablesFurtherWritesUntilReset() {
        var tracker = CmdTabSelectionTracker()
        tracker.writeFailed()

        #expect(tracker.needsWrite(for: 20) == false)

        tracker.reset()
        #expect(tracker.needsWrite(for: 20))
        #expect(tracker.writesDisabled == false)
    }

    @Test func aPanelWriteMakesTheNextNativeNotificationAnEcho() {
        var tracker = CmdTabSelectionTracker()
        tracker.markInSync(with: 30)

        let reported = tracker.nativeSelectionChanged(to: 30)

        #expect(tracker.needsWrite(for: 30) == false)
        #expect(reported == false)
    }
}

struct CmdTabSearchLayoutTests {
    private let primary = CGRect(x: 0, y: 0, width: 1728, height: 1083) // below the menu bar
    private let secondaryNoMenuBar = CGRect(x: -1920, y: 1117, width: 1920, height: 1080)

    @Test func panelHangsFromAFixedTopBelowTheSearchBar() {
        let top = CmdTabSearchLayout.panelTop(in: primary)
        let expectedTop: CGFloat = 1083 - 40 - 8
        #expect(top == expectedTop)

        // Whatever the content height, the top edge stays put: only the bottom moves.
        for height: CGFloat in [120, 421, 900] {
            let origin = CmdTabSearchLayout.origin(for: CGSize(width: 396, height: height), in: primary)
            #expect(origin.y + height == top)
        }
    }

    @Test func panelIsCenteredOnItsOwnDisplay() {
        let origin = CmdTabSearchLayout.origin(for: CGSize(width: 396, height: 400), in: primary)
        let halfWidth: CGFloat = 198
        #expect(origin.x + halfWidth == primary.midX)
    }

    @Test func worksOnADisplayWithNegativeCoordinatesAndNoMenuBar() {
        // A secondary display arranged left of and above the primary, as when displays share
        // one Space and only the primary keeps the menu bar.
        let origin = CmdTabSearchLayout.origin(for: CGSize(width: 396, height: 500), in: secondaryNoMenuBar)
        let halfWidth: CGFloat = 198
        let height: CGFloat = 500
        #expect(origin.x + halfWidth == secondaryNoMenuBar.midX)
        #expect(origin.y + height == secondaryNoMenuBar.maxY - CmdTabSearchLayout.barHeight - CmdTabSearchLayout.topGap)
        #expect(secondaryNoMenuBar.contains(origin))
    }

    @Test func oversizedContentIsKeptInsideTheVisibleFrame() {
        let origin = CmdTabSearchLayout.origin(for: CGSize(width: 5000, height: 5000), in: primary)
        #expect(origin.x == primary.minX)
        #expect(origin.y == primary.minY)
    }

    @Test func budgetIsTheSpaceBetweenTheBarAndTheStripMinusTheGap() {
        let budget = CmdTabSearchLayout.heightBudget(in: primary, stripTop: 602)
        let expected: CGFloat = (1083 - 40 - 8) - (602 + 12)
        #expect(budget == expected)
    }

    @Test func budgetNeverDropsBelowTheMinimum() {
        let budget = CmdTabSearchLayout.heightBudget(in: primary, stripTop: 1000)
        #expect(budget == CmdTabSearchLayout.minimumHeight)
    }
}

struct CmdTabSessionKeyTests {
    @Test func tabAndTheBackwardKeyStayWithTheNativeStrip() {
        #expect(CmdTabSessionKey.disposition(forKeyCode: Int64(kVK_Tab)) == .passToSystem)
        #expect(CmdTabSessionKey.disposition(forKeyCode: Int64(kVK_ANSI_Grave)) == .passToSystem)
    }

    @Test func escapeUsesTheExistingDismissBranch() {
        #expect(CmdTabSessionKey.disposition(forKeyCode: Int64(kVK_Escape)) == .escape)
    }

    @Test func keysThatTheNativeSwitcherTreatsAsActionsAreAlwaysConsumed() {
        // Command+Q quits and Command+H hides the highlighted app in the native switcher.
        for key in [kVK_ANSI_Q, kVK_ANSI_H, kVK_ANSI_W, kVK_ANSI_M, kVK_ANSI_A, kVK_Return, kVK_Space, kVK_LeftArrow, kVK_DownArrow, kVK_Delete] {
            #expect(CmdTabSessionKey.disposition(forKeyCode: Int64(key)) == .consume)
        }
    }
}

@MainActor
struct SwitcherHeightBudgetTests {
    @Test func limitIsTheVisibleHeightWithoutABudget() throws {
        let screen = try #require(NSScreen.main)
        SwitcherHeightBudget.current = nil

        #expect(SwitcherHeightBudget.limit(for: screen) == screen.visibleFrame.height)
    }

    @Test func aBudgetOnlyEverLowersTheLimit() throws {
        let screen = try #require(NSScreen.main)
        defer { SwitcherHeightBudget.current = nil }

        SwitcherHeightBudget.current = 300
        #expect(SwitcherHeightBudget.limit(for: screen) == min(300, screen.visibleFrame.height))

        SwitcherHeightBudget.current = screen.visibleFrame.height + 500
        #expect(SwitcherHeightBudget.limit(for: screen) == screen.visibleFrame.height)
    }
}
