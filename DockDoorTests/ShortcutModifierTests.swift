import Defaults
@testable import DockDoor
import Testing

struct ShortcutModifierTests {
    private let controlMask = Defaults.Keys.Int64maskControl.defaultValue
    private let optionMask = Defaults.Keys.Int64maskAlternate.defaultValue
    private let commandMask = Defaults.Keys.Int64maskCommand.defaultValue

    @Test func singleModifierProducesExistingStoredValue() {
        #expect(ShortcutModifier.modifierFlags(for: [.control]) == controlMask)
        #expect(ShortcutModifier.modifierFlags(for: [.option]) == optionMask)
        #expect(ShortcutModifier.modifierFlags(for: [.command]) == commandMask)
    }

    @Test func existingStoredValuesDecodeToSingleModifier() {
        #expect(ShortcutModifier.contained(in: controlMask) == [.control])
        #expect(ShortcutModifier.contained(in: optionMask) == [.option])
        #expect(ShortcutModifier.contained(in: commandMask) == [.command])
        #expect(ShortcutModifier.contained(in: 0).isEmpty)
    }

    @Test func combinationRoundTrips() {
        let flags = ShortcutModifier.modifierFlags(for: [.option, .control])

        #expect(flags == controlMask | optionMask)
        #expect(ShortcutModifier.contained(in: flags) == [.control, .option])
        #expect(ShortcutModifier.contained(in: ShortcutModifier.modifierFlags(for: ShortcutModifier.allCases)) == ShortcutModifier.allCases)
    }

    @Test func removingModifierFromCombinationLeavesExactRemainder() {
        let combined = ShortcutModifier.modifierFlags(for: [.control, .option, .command])
        let remaining = ShortcutModifier.contained(in: combined).filter { $0 != .option }

        #expect(ShortcutModifier.modifierFlags(for: remaining) == controlMask | commandMask)
        #expect(ShortcutModifier.modifierFlags(for: remaining.filter { $0 != .command }) == controlMask)
    }

    @Test func converterDescribesSingleAndCombinedModifiers() {
        #expect(modifierConverter.toString(optionMask) == ShortcutModifier.option.localizedName)
        #expect(modifierConverter.toString(controlMask | commandMask) == "\(ShortcutModifier.control.localizedName) + \(ShortcutModifier.command.localizedName)")
        #expect(modifierConverter.toString(0).isEmpty)
    }
}
