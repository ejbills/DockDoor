@testable import DockDoor
import Testing

struct SwitcherInitialSelectionTests {
    @Test func existingSettingsMapToFirstAndSecond() {
        #expect(SwitcherInitialSelection(useClassicWindowOrdering: false, startOnLastWindowWhenOpeningBackward: false) == .first)
        #expect(SwitcherInitialSelection(useClassicWindowOrdering: true, startOnLastWindowWhenOpeningBackward: false) == .second)
    }

    @Test func newKeyEnablesSecondOrLast() {
        #expect(SwitcherInitialSelection(useClassicWindowOrdering: true, startOnLastWindowWhenOpeningBackward: true) == .secondOrLast)
    }

    @Test func newKeyWithoutClassicOrderingIsFirst() {
        #expect(SwitcherInitialSelection(useClassicWindowOrdering: false, startOnLastWindowWhenOpeningBackward: true) == .first)
    }

    @Test(arguments: SwitcherInitialSelection.allCases)
    func selectionRoundTripsThroughStoredKeys(selection: SwitcherInitialSelection) {
        let restored = SwitcherInitialSelection(
            useClassicWindowOrdering: selection.usesClassicWindowOrdering,
            startOnLastWindowWhenOpeningBackward: selection.startsOnLastWindowWhenOpeningBackward
        )
        #expect(restored == selection)
    }
}
