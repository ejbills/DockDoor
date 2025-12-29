import Defaults
import Foundation

enum WindowOrderPersistence {
    struct PersistedWindowEntry: Codable, Defaults.Serializable {
        let bundleIdentifier: String
        let windowTitle: String
        let lastAccessedTime: Date
        let creationTime: Date

        var key: String {
            "\(bundleIdentifier)|\(windowTitle)"
        }
    }

    private static var cache: [String: PersistedWindowEntry]?

    static func getPersistedTimestamp(bundleIdentifier: String, windowTitle: String?) -> PersistedWindowEntry? {
        if cache == nil {
            let entries = Defaults[.persistedWindowOrder]
            cache = Dictionary(entries.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
        }
        let targetKey = "\(bundleIdentifier)|\(windowTitle ?? "")"
        return cache?[targetKey]
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

        var seenKeys = Set<String>()
        var dedupedEntries: [PersistedWindowEntry] = []
        let sortedByRecent = entries.sorted { $0.lastAccessedTime > $1.lastAccessedTime }

        for entry in sortedByRecent {
            if !seenKeys.contains(entry.key) {
                seenKeys.insert(entry.key)
                dedupedEntries.append(entry)
            }
        }

        Defaults[.persistedWindowOrder] = Array(dedupedEntries.prefix(500))
    }
}
