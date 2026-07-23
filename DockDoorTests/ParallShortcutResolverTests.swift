@testable import DockDoor
import Foundation
import Testing

struct ParallShortcutResolverTests {
    @Test func parallShortcutResultCanDisableBundleInstanceGrouping() {
        let result = ApplicationReturnType(
            status: .notFound,
            dockItemElement: nil,
            allowsBundleInstanceGrouping: false
        )

        #expect(!result.allowsBundleInstanceGrouping)
    }

    @Test func matchesTargetWhoseParentIsShortcut() {
        let parentPaths: [pid_t: String] = [
            200: "/Applications/Other.app/Contents/MacOS/Other",
            201: "/Applications/Claude Personal.app/Contents/MacOS/Claude Personal",
        ]

        let result = ParallShortcutResolver.matchingTargetProcessIdentifier(
            shortcutExecutablePath: "/Applications/Claude Personal.app/Contents/MacOS/Claude Personal",
            targetProcessIdentifiers: [200, 201],
            parentExecutablePath: { parentPaths[$0] }
        )

        #expect(result == 201)
    }

    @Test func ignoresTargetsLaunchedOutsideShortcut() {
        let result = ParallShortcutResolver.matchingTargetProcessIdentifier(
            shortcutExecutablePath: "/Applications/Claude Personal.app/Contents/MacOS/Claude Personal",
            targetProcessIdentifiers: [200],
            parentExecutablePath: { _ in "/Applications/Other.app/Contents/MacOS/Other" }
        )

        #expect(result == nil)
    }

    @Test func ignoresTargetWhenParentCannotBeRead() {
        let result = ParallShortcutResolver.matchingTargetProcessIdentifier(
            shortcutExecutablePath: "/Applications/Claude Personal.app/Contents/MacOS/Claude Personal",
            targetProcessIdentifiers: [200],
            parentExecutablePath: { _ in nil }
        )

        #expect(result == nil)
    }
}
