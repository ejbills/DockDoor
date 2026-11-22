import AppKit
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

    @Test func appKitModifierFlagsDecodeToSameModifiers() {
        let flags: NSEvent.ModifierFlags = [.control, .option, .shift]

        #expect(ShortcutModifier.contained(in: Int(flags.rawValue)) == [.control, .option])
    }

    @Test func converterDescribesSingleAndCombinedModifiers() {
        #expect(modifierConverter.toString(optionMask) == ShortcutModifier.option.localizedName)
        #expect(modifierConverter.toString(controlMask | commandMask) == "\(ShortcutModifier.control.localizedName) + \(ShortcutModifier.command.localizedName)")
        #expect(modifierConverter.toString(0).isEmpty)
    }
}

struct BackwardModifierTests {
    private let option = UserKeyBind(keyCode: 48, modifierFlags: Defaults.Keys.Int64maskAlternate.defaultValue)
    private let controlOption = UserKeyBind(
        keyCode: 48,
        modifierFlags: Defaults.Keys.Int64maskControl.defaultValue | Defaults.Keys.Int64maskAlternate.defaultValue
    )

    @Test func modifierKeyCodesMapToTheirModifier() {
        #expect(ShortcutModifier(keyCode: 59) == .control)
        #expect(ShortcutModifier(keyCode: 62) == .control)
        #expect(ShortcutModifier(keyCode: 58) == .option)
        #expect(ShortcutModifier(keyCode: 61) == .option)
        #expect(ShortcutModifier(keyCode: 55) == .command)
        #expect(ShortcutModifier(keyCode: 54) == .command)
    }

    @Test func shiftAndRegularKeysAreNotShortcutModifiers() {
        #expect(ShortcutModifier(keyCode: 56) == nil)
        #expect(ShortcutModifier(keyCode: 60) == nil)
        #expect(ShortcutModifier(keyCode: 50) == nil)
    }

    @Test func holdingModifierTurnsShortcutIntoCombination() {
        #expect(ShortcutModifier.control.turns(option, into: controlOption))
    }

    @Test func onlyTheShortcutWithoutTheModifierIsAffected() {
        #expect(!ShortcutModifier.control.turns(controlOption, into: option))
        #expect(!ShortcutModifier.control.turns(controlOption, into: controlOption))
    }

    @Test func otherKeysAndModifiersDoNotCount() {
        let otherKey = UserKeyBind(keyCode: 50, modifierFlags: controlOption.modifierFlags)
        let unset = UserKeyBind(keyCode: 0, modifierFlags: option.modifierFlags)

        #expect(!ShortcutModifier.control.turns(option, into: otherKey))
        #expect(!ShortcutModifier.command.turns(option, into: controlOption))
        #expect(!ShortcutModifier.control.turns(unset, into: UserKeyBind(keyCode: 0, modifierFlags: controlOption.modifierFlags)))
    }
}
