import Cocoa

/// Reconstructs the order macOS uses for separate Dock items that share a
/// bundle identifier. Accessibility exposes each item's position, but not the
/// PID it represents, so launch order provides the identity bridge.
enum DockAppInstanceOrdering {
    typealias RunningApplicationIdentity = (processIdentifier: pid_t, launchDate: Date?)

    /// Returns how many persistent Dock tiles use a bundle identifier.
    static func persistentDockItemCount(for bundleIdentifier: String) -> Int {
        guard let persistentApps = UserDefaults(suiteName: "com.apple.dock")?
            .array(forKey: "persistent-apps") as? [[String: Any]]
        else {
            return 0
        }

        return persistentApps.count { item in
            guard let tileData = item["tile-data"] as? [String: Any] else {
                return false
            }
            return tileData["bundle-identifier"] as? String == bundleIdentifier
        }
    }

    /// Returns running application PIDs in the order represented by the Dock.
    /// Duplicate persistent tiles are filled in reverse launch order, followed
    /// by any additional transient tiles in launch order.
    static func processIdentifiers(
        for runningApplications: [RunningApplicationIdentity],
        persistentDockItemCount: Int
    ) -> [pid_t] {
        let processIdentifiers = runningApplications
            .sorted { lhs, rhs in
                let lhsDate = lhs.launchDate ?? .distantPast
                let rhsDate = rhs.launchDate ?? .distantPast

                if lhsDate == rhsDate {
                    return lhs.processIdentifier < rhs.processIdentifier
                }

                return lhsDate < rhsDate
            }
            .map(\.processIdentifier)

        let persistentProcessCount = min(
            persistentDockItemCount,
            processIdentifiers.count
        )
        let persistentProcessIdentifiers = processIdentifiers
            .prefix(persistentProcessCount)
            .reversed()
        let transientProcessIdentifiers = processIdentifiers
            .dropFirst(persistentProcessCount)

        return Array(persistentProcessIdentifiers) + Array(transientProcessIdentifiers)
    }

    /// Returns a PID assignment aligned with the matching Dock items. A nil
    /// entry represents an unoccupied tile whose application instance exited.
    static func processIdentifiersByDockItem(
        for runningApplications: [RunningApplicationIdentity],
        persistentDockItemCount: Int,
        dockItemRunningStates: [Bool?]
    ) -> [pid_t?] {
        let runningDockItemIndices = dockItemRunningStates.indices.filter {
            dockItemRunningStates[$0] == true
        }

        // Trust the Accessibility occupancy flags when they account for every
        // process. Otherwise retain the previous prefix-based behavior while
        // the Dock and NSWorkspace are between updates.
        let occupiedDockItemIndices = if runningDockItemIndices.count == runningApplications.count {
            runningDockItemIndices
        } else {
            Array(dockItemRunningStates.indices.prefix(runningApplications.count))
        }
        let occupiedPersistentDockItemCount = occupiedDockItemIndices.count {
            $0 < persistentDockItemCount
        }
        let processIdentifiers = processIdentifiers(
            for: runningApplications,
            persistentDockItemCount: occupiedPersistentDockItemCount
        )

        var processIdentifiersByDockItem = [pid_t?](
            repeating: nil,
            count: dockItemRunningStates.count
        )
        for (dockItemIndex, processIdentifier) in zip(
            occupiedDockItemIndices,
            processIdentifiers
        ) {
            processIdentifiersByDockItem[dockItemIndex] = processIdentifier
        }

        return processIdentifiersByDockItem
    }
}
