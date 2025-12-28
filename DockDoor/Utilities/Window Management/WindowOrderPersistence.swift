import Defaults
import Foundation

/// Persists window access timestamps across app restarts to maintain "recently used" order
enum WindowOrderPersistence {
    /// Stored data for a window including its identifier
    struct PersistedWindowEntry: Codable, Defaults.Serializable {
        let bundleIdentifier: String
        let windowTitle: String
        let lastAccessedTime: Date
        let creationTime: Date

        /// Unique key for lookup
        var key: String {
            "\(bundleIdentifier)|\(windowTitle)"
        }
    }

    /// Get the persisted timestamp for a window, if available
    static func getPersistedTimestamp(bundleIdentifier: String, windowTitle: String?) -> PersistedWindowEntry? {
        let targetKey = "\(bundleIdentifier)|\(windowTitle ?? "")"
        return Defaults[.persistedWindowOrder].first { $0.key == targetKey }
    }

    static func saveOrder(from allWindows: [WindowInfo]) {
        var entries: [PersistedWindowEntry] = []

        for window in allWindows {
            guard let bundleId = window.app.bundleIdentifier else { continue }

            let entry = PersistedWindowEntry(
                bundleIdentifier: bundleId,
                windowTitle: window.windowName ?? "",
                lastAccessedTime: window.lastAccessedTime,
                creationTime: window.creationTime
            )
            entries.append(entry)
        }

        // Remove duplicates, keeping the most recently accessed
        var seenKeys = Set<String>()
        var dedupedEntries: [PersistedWindowEntry] = []
        let sortedByRecent = entries.sorted { $0.lastAccessedTime > $1.lastAccessedTime }

        for entry in sortedByRecent {
            if !seenKeys.contains(entry.key) {
                seenKeys.insert(entry.key)
                dedupedEntries.append(entry)
            }
        }

        // Limit to reasonable size (e.g., last 500 windows)
        let limitedEntries = Array(dedupedEntries.prefix(500))

        Defaults[.persistedWindowOrder] = limitedEntries
    }

    /// Clean up old entries (call periodically or on save)
    static func cleanupOldEntries(olderThan days: Int = 30) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        var entries = Defaults[.persistedWindowOrder]

        entries = entries.filter { $0.lastAccessedTime > cutoffDate }

        Defaults[.persistedWindowOrder] = entries
    }
}
