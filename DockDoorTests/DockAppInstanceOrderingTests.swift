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
}
