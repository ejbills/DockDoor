import Cocoa
@testable import DockDoor
import Testing

struct DockAppInstanceOrderingTests {
    @Test func unknownDuplicatesAreNotGuessed() {
        #expect(DockAppInstanceOrdering.resolve(runningPIDs: [101, 202], runningStates: [true, true], knownPIDs: [nil, nil]) == [nil, nil])
    }

    @Test func nativeActivationResolvesEitherOrder() {
        #expect(DockAppInstanceOrdering.resolve(runningPIDs: [101, 202], runningStates: [true, true], knownPIDs: [101, nil]) == [101, 202])
        #expect(DockAppInstanceOrdering.resolve(runningPIDs: [101, 202], runningStates: [true, true], knownPIDs: [202, nil]) == [202, 101])
    }

    @Test func inputOrderDoesNotChangeObservedIdentity() {
        #expect(DockAppInstanceOrdering.resolve(runningPIDs: [202, 101], runningStates: [true, true], knownPIDs: [101, nil]) == [101, 202])
    }

    @Test func survivingProcessKeepsOccupiedTile() {
        #expect(DockAppInstanceOrdering.resolve(runningPIDs: [101], runningStates: [false, true], knownPIDs: [nil, nil]) == [nil, 101])
        #expect(DockAppInstanceOrdering.resolve(runningPIDs: [101], runningStates: [true, false], knownPIDs: [nil, nil]) == [101, nil])
    }

    @Test func deadProcessIsDiscarded() {
        #expect(DockAppInstanceOrdering.resolve(runningPIDs: [202, 303], runningStates: [true, true], knownPIDs: [101, nil]) == [nil, nil])
    }

    @Test func threeInstancesRequireMoreEvidence() {
        #expect(DockAppInstanceOrdering.resolve(runningPIDs: [101, 202, 303], runningStates: [true, true, true], knownPIDs: [202, nil, nil]) == [202, nil, nil])
    }

    @Test func incompleteOccupancyDoesNotInfer() {
        #expect(DockAppInstanceOrdering.resolve(runningPIDs: [101, 202], runningStates: [true, nil], knownPIDs: [101, nil]) == [101, nil])
        #expect(DockAppInstanceOrdering.resolve(runningPIDs: [101, 202], runningStates: [true, true, true], knownPIDs: [101, nil, nil]) == [101, nil, nil])
    }

    @Test func conflictingEvidenceDoesNotTargetEitherTile() {
        #expect(DockAppInstanceOrdering.resolve(runningPIDs: [101, 202], runningStates: [true, true], knownPIDs: [101, 101]) == [nil, nil])
    }

    @Test func processOwnedByAnotherShortcutCannotKeepAssignment() {
        #expect(DockAppInstanceOrdering.resolve(runningPIDs: [202], runningStates: [true], knownPIDs: [101]) == [202])
    }

    @Test func mismatchedEvidenceDoesNotGuess() {
        #expect(DockAppInstanceOrdering.resolve(runningPIDs: [101, 202], runningStates: [true, true], knownPIDs: [101]) == [nil, nil])
    }

    private let processes: [DockAppInstanceOrdering.Process] = [.init(pid: 101), .init(pid: 202)]
    private let items: [DockAppInstanceOrdering.Item] = [
        .init(element: AXUIElementCreateApplication(101), isRunning: true),
        .init(element: AXUIElementCreateApplication(202), isRunning: true),
    ]

    @Test func learnsFromActivationWithoutAnObserver() {
        let ordering = DockAppInstanceOrdering()
        #expect(ordering.processIdentifiers(for: processes, items: items, bundleIdentifier: "app") == [nil, nil])
        ordering.observeNativeClick(on: items[0].element, bundleIdentifier: "app")
        ordering.recordActivation(of: processes[1], bundleIdentifier: "app")
        #expect(ordering.processIdentifiers(for: processes.reversed(), items: items, bundleIdentifier: "app") == [202, 101])
        ordering.recordActivation(of: processes[0], bundleIdentifier: "app")
        #expect(ordering.processIdentifiers(for: processes, items: items, bundleIdentifier: "app") == [202, 101])
    }

    @Test func fallbackKeepsPreviewsAndGesturesAvailableWithoutClaimingAnIdentity() {
        let resolved = DockAppInstanceOrdering.resolve(runningPIDs: [202, 101], runningStates: [true, true], knownPIDs: [nil, nil])
        #expect(resolved == [nil, nil])
        #expect(DockAppInstanceOrdering.fallbackProcessIdentifiers(runningPIDs: [202, 101], runningStates: [true, true], resolvedPIDs: resolved) == [101, 202])
        #expect(DockAppInstanceOrdering.fallbackProcessIdentifiers(runningPIDs: [101, 202, 303], runningStates: [true, true, true], resolvedPIDs: [202, nil, nil]) == [202, 101, 303])
        #expect(DockAppInstanceOrdering.fallbackProcessIdentifiers(runningPIDs: [202], runningStates: [false, true], resolvedPIDs: [nil, 202]) == [nil, 202])
    }

    @Test func unresolvedStatusSupportsNonClickActionsButNotIndicators() {
        let app = NSRunningApplication.current
        let status = ApplicationReturnType.Status.unresolvedInstance(bundleIdentifier: "app", fallback: app)
        #expect(status.previewOrGestureApplication == app)
        #expect(status.resolvedApplication == nil)
        #expect(ApplicationReturnType.Status.success(app).resolvedApplication == app)
        #expect(ApplicationReturnType.Status.notFound.previewOrGestureApplication == nil)
        #expect(ApplicationReturnType.Status.notRunning(bundleIdentifier: "app").previewOrGestureApplication == nil)
    }

    @Test func resetDiscardsAssignmentsAndPendingClicks() {
        let ordering = DockAppInstanceOrdering()
        _ = ordering.processIdentifiers(for: processes, items: items, bundleIdentifier: "app")
        ordering.observeNativeClick(on: items[0].element, bundleIdentifier: "app")
        ordering.recordActivation(of: processes[1], bundleIdentifier: "app")
        ordering.observeNativeClick(on: items[1].element, bundleIdentifier: "app")
        ordering.reset()
        #expect(!ordering.hasPendingClick)
        ordering.recordActivation(of: processes[0], bundleIdentifier: "app")
        #expect(ordering.processIdentifiers(for: processes, items: items, bundleIdentifier: "app") == [nil, nil])
    }

    @Test func rebuiltDockItemsDiscardAssignmentsAndPendingClicks() {
        let ordering = DockAppInstanceOrdering()
        _ = ordering.processIdentifiers(for: processes, items: items, bundleIdentifier: "app")
        ordering.observeNativeClick(on: items[0].element, bundleIdentifier: "app")
        ordering.recordActivation(of: processes[1], bundleIdentifier: "app")
        ordering.observeNativeClick(on: items[1].element, bundleIdentifier: "app")
        let rebuilt = [items[0], DockAppInstanceOrdering.Item(element: AXUIElementCreateApplication(303), isRunning: true)]
        #expect(ordering.processIdentifiers(for: processes, items: rebuilt, bundleIdentifier: "app") == [nil, nil])
        #expect(!ordering.hasPendingClick)
    }

    @Test func processChangesDiscardAssignments() {
        let ordering = DockAppInstanceOrdering()
        _ = ordering.processIdentifiers(for: processes, items: items, bundleIdentifier: "app")
        ordering.observeNativeClick(on: items[0].element, bundleIdentifier: "app")
        ordering.recordActivation(of: processes[1], bundleIdentifier: "app")
        let relaunched = [processes[0], DockAppInstanceOrdering.Process(pid: 202, launchDate: Date())]
        #expect(ordering.processIdentifiers(for: relaunched, items: items, bundleIdentifier: "app") == [nil, nil])
        ordering.observeNativeClick(on: items[0].element, bundleIdentifier: "app")
        ordering.recordActivation(of: processes[1], bundleIdentifier: "app")
        #expect(ordering.processIdentifiers(for: relaunched, items: items, bundleIdentifier: "app") == [nil, nil])
    }

    @Test func unrelatedBundleLookupPreservesPendingClick() {
        let ordering = DockAppInstanceOrdering()
        _ = ordering.processIdentifiers(for: processes, items: items, bundleIdentifier: "app")
        ordering.observeNativeClick(on: items[0].element, bundleIdentifier: "app")
        _ = ordering.processIdentifiers(for: processes, items: items, bundleIdentifier: "other")
        ordering.recordActivation(of: processes[1], bundleIdentifier: "app")
        #expect(ordering.processIdentifiers(for: processes, items: items, bundleIdentifier: "app") == [202, 101])
    }

    @Test func expiredCancelledOrUnrelatedActivationCannotTeachAnIdentity() {
        let ordering = DockAppInstanceOrdering()
        let now = Date()
        _ = ordering.processIdentifiers(for: processes, items: items, bundleIdentifier: "app")
        ordering.observeNativeClick(on: items[0].element, bundleIdentifier: "app", now: now)
        ordering.recordActivation(of: processes[1], bundleIdentifier: "app", now: now.addingTimeInterval(2))
        #expect(ordering.processIdentifiers(for: processes, items: items, bundleIdentifier: "app") == [nil, nil])
        ordering.observeNativeClick(on: items[0].element, bundleIdentifier: "app")
        ordering.cancelPendingClick()
        ordering.recordActivation(of: processes[1], bundleIdentifier: "app")
        #expect(ordering.processIdentifiers(for: processes, items: items, bundleIdentifier: "app") == [nil, nil])
        ordering.observeNativeClick(on: items[0].element, bundleIdentifier: "app")
        ordering.recordActivation(of: processes[1], bundleIdentifier: "other")
        #expect(ordering.processIdentifiers(for: processes, items: items, bundleIdentifier: "app") == [nil, nil])
    }

    @Test func concurrentLookupActivationAndResetAreSafe() {
        let ordering = DockAppInstanceOrdering()
        DispatchQueue.concurrentPerform(iterations: 300) { index in
            let localItems: [DockAppInstanceOrdering.Item] = [
                .init(element: AXUIElementCreateApplication(101), isRunning: true),
                .init(element: AXUIElementCreateApplication(202), isRunning: true),
            ]
            let localProcesses: [DockAppInstanceOrdering.Process] = [.init(pid: 101), .init(pid: 202)]
            _ = ordering.processIdentifiers(for: localProcesses, items: localItems, bundleIdentifier: "app")
            ordering.observeNativeClick(on: localItems[0].element, bundleIdentifier: "app")
            if index.isMultiple(of: 3) { ordering.reset() }
            if index.isMultiple(of: 2) { ordering.cancelPendingClick() }
            ordering.recordActivation(of: localProcesses[1], bundleIdentifier: "app")
        }
        ordering.reset()
        #expect(ordering.processIdentifiers(for: processes, items: items, bundleIdentifier: "app") == [nil, nil])
    }

    @Test func activationAlreadyInFlightCannotConsumeANewerClick() {
        let ordering = DockAppInstanceOrdering()
        let now = Date()
        _ = ordering.processIdentifiers(for: processes, items: items, bundleIdentifier: "app")
        ordering.observeNativeClick(on: items[0].element, bundleIdentifier: "app", now: now)
        ordering.recordActivation(of: processes[0], bundleIdentifier: "app", now: now.addingTimeInterval(-0.1))
        #expect(ordering.hasPendingClick)
        #expect(ordering.processIdentifiers(for: processes, items: items, bundleIdentifier: "app") == [nil, nil])
        ordering.recordActivation(of: processes[1], bundleIdentifier: "app", now: now.addingTimeInterval(0.1))
        #expect(ordering.processIdentifiers(for: processes, items: items, bundleIdentifier: "app") == [202, 101])
    }
}
