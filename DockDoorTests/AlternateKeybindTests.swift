import Defaults
@testable import DockDoor
import Foundation
import Testing

struct AlternateKeybindTests {
    private let suiteName = "com.ethanbills.DockDoorTests.AlternateKeybind"
    private let primaryModifierFlags = 524_576

    @Test func unsetKeyResolvesToNoShortcut() {
        let alternate = AlternateKeybind(keyCode: 0, modifierFlags: 262_401, mode: .currentSpaceOnly)

        #expect(alternate.resolved(primaryModifierFlags: primaryModifierFlags) == nil)
    }

    @Test func zeroModifierInheritsPrimaryModifier() throws {
        let alternate = AlternateKeybind(keyCode: 50, modifierFlags: 0, mode: .activeAppOnly)

        let resolved = try #require(alternate.resolved(primaryModifierFlags: primaryModifierFlags))
        #expect(resolved.keyCode == 50)
        #expect(resolved.modifierFlags == primaryModifierFlags)
    }

    @Test func explicitModifierIsKept() throws {
        let alternate = AlternateKeybind(keyCode: 48, modifierFlags: 262_401, mode: .activeAppOnly)

        let resolved = try #require(alternate.resolved(primaryModifierFlags: primaryModifierFlags))
        #expect(resolved.keyCode == 48)
        #expect(resolved.modifierFlags == 262_401)
    }

    @Test func alternateListRoundTripsThroughDefaults() throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let key = Defaults.Key<[AlternateKeybind]>("additionalAlternateKeybinds", default: [], suite: defaults)
        let alternates = [
            AlternateKeybind(keyCode: 50, modifierFlags: 0, mode: .activeAppOnly),
            AlternateKeybind(keyCode: 48, modifierFlags: 262_401, mode: .activeAppCurrentSpace),
        ]

        #expect(Defaults[key].isEmpty)
        Defaults[key] = alternates
        #expect(Defaults[key] == alternates)
    }

    @Test func invocationModeIsStillStoredAsRawString() throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let key = Defaults.Key<SwitcherInvocationMode>("alternateKeybindMode", default: .activeAppOnly, suite: defaults)

        Defaults[key] = .currentSpaceOnly
        #expect(defaults.string(forKey: "alternateKeybindMode") == "currentSpaceOnly")

        defaults.set("activeAppCurrentSpace", forKey: "alternateKeybindMode")
        #expect(Defaults[key] == .activeAppCurrentSpace)
    }
}
