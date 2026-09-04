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
}
