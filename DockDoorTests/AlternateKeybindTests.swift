import Defaults
@testable import DockDoor
import Foundation
import Testing

struct AlternateKeybindTests {
    // Tests run in parallel, so each test that writes defaults uses its own suite
    private let listSuiteName = "com.ethanbills.DockDoorTests.AlternateKeybind.list"
    private let modeSuiteName = "com.ethanbills.DockDoorTests.AlternateKeybind.mode"
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
        let defaults = try #require(UserDefaults(suiteName: listSuiteName))
        defaults.removePersistentDomain(forName: listSuiteName)
        defer { defaults.removePersistentDomain(forName: listSuiteName) }

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
        let defaults = try #require(UserDefaults(suiteName: modeSuiteName))
        defaults.removePersistentDomain(forName: modeSuiteName)
        defer { defaults.removePersistentDomain(forName: modeSuiteName) }

        let key = Defaults.Key<SwitcherInvocationMode>("alternateKeybindMode", default: .activeAppOnly, suite: defaults)

        Defaults[key] = .currentSpaceOnly
        #expect(defaults.string(forKey: "alternateKeybindMode") == "currentSpaceOnly")

        defaults.set("activeAppCurrentSpace", forKey: "alternateKeybindMode")
        #expect(Defaults[key] == .activeAppCurrentSpace)
    }
}
