@testable import DockDoor
import Foundation
import Testing

struct DockAppInstanceOrderingTests {
    private let olderLaunchDate = Date(timeIntervalSince1970: 100)
    private let newerLaunchDate = Date(timeIntervalSince1970: 200)

    @Test func duplicatePersistentItemsUseReverseLaunchOrder() {
        let processIdentifiers = DockAppInstanceOrdering.processIdentifiers(
            for: [
                (processIdentifier: 101, launchDate: olderLaunchDate),
                (processIdentifier: 202, launchDate: newerLaunchDate),
            ],
            persistentDockItemCount: 2
        )

        #expect(processIdentifiers == [202, 101])
    }

    @Test func inputOrderDoesNotAffectPersistentItemOrder() {
        let processIdentifiers = DockAppInstanceOrdering.processIdentifiers(
            for: [
                (processIdentifier: 202, launchDate: newerLaunchDate),
                (processIdentifier: 101, launchDate: olderLaunchDate),
            ],
            persistentDockItemCount: 2
        )

        #expect(processIdentifiers == [202, 101])
    }

    @Test func transientItemsUseLaunchOrder() {
        let processIdentifiers = DockAppInstanceOrdering.processIdentifiers(
            for: [
                (processIdentifier: 202, launchDate: newerLaunchDate),
                (processIdentifier: 101, launchDate: olderLaunchDate),
            ],
            persistentDockItemCount: 0
        )

        #expect(processIdentifiers == [101, 202])
    }

    @Test func onePersistentItemKeepsLaunchOrder() {
        let processIdentifiers = DockAppInstanceOrdering.processIdentifiers(
            for: [
                (processIdentifier: 202, launchDate: newerLaunchDate),
                (processIdentifier: 101, launchDate: olderLaunchDate),
            ],
            persistentDockItemCount: 1
        )

        #expect(processIdentifiers == [101, 202])
    }

    @Test func transientItemsFollowTheReversedPersistentPrefix() {
        let processIdentifiers = DockAppInstanceOrdering.processIdentifiers(
            for: [
                (processIdentifier: 303, launchDate: Date(timeIntervalSince1970: 300)),
                (processIdentifier: 101, launchDate: olderLaunchDate),
                (processIdentifier: 202, launchDate: newerLaunchDate),
            ],
            persistentDockItemCount: 2
        )

        #expect(processIdentifiers == [202, 101, 303])
    }

    @Test func missingLaunchDatesUseProcessIdentifiersAsATieBreak() {
        let processIdentifiers = DockAppInstanceOrdering.processIdentifiers(
            for: [
                (processIdentifier: 202, launchDate: nil),
                (processIdentifier: 101, launchDate: nil),
            ],
            persistentDockItemCount: 0
        )

        #expect(processIdentifiers == [101, 202])
    }
}
