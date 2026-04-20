import SwiftUI

final class SettingsSearchEngine: ObservableObject {
    @Published var query: String = "" {
        didSet { recompute() }
    }

    @Published private(set) var results: [SettingsSearchResult] = []

    var isSearching: Bool { !query.isEmpty }

    private let items: [SettingsSearchItem]

    private static let tabDisplayOrder = [
        "General", "DockPreviews", "WindowSwitcher", "CmdTab",
        "DockLocking", "Appearance", "GesturesKeybinds", "Filters",
        "Widgets", "Advanced", "Support",
    ]

    static let tabDisplayNames: [String: String] = [
        "General": String(localized: "General", comment: "Settings tab title"),
        "DockPreviews": String(localized: "Dock Previews", comment: "Settings tab title"),
        "WindowSwitcher": String(localized: "Window Switcher", comment: "Settings tab title"),
        "CmdTab": String(localized: "Cmd+Tab", comment: "Settings tab title"),
        "DockLocking": String(localized: "Dock Locking", comment: "Settings tab title"),
        "Appearance": String(localized: "Appearance", comment: "Settings Tab"),
        "GesturesKeybinds": String(localized: "Gestures & Keybinds", comment: "Settings tab title"),
        "Filters": String(localized: "Filters", comment: "Filters tab title"),
        "Widgets": String(localized: "Widgets", comment: "Widget settings tab title"),
        "Advanced": String(localized: "Advanced", comment: "Settings tab title"),
        "Support": String(localized: "Support", comment: "Settings tab title"),
    ]

    init(items: [SettingsSearchItem] = SettingsSearchCatalog.items) {
        self.items = items
    }

    var resultsByTab: [(tab: String, displayName: String, items: [SettingsSearchResult])] {
        let grouped = Dictionary(grouping: results) { $0.item.tab }
        return Self.tabDisplayOrder.compactMap { tab in
            guard let items = grouped[tab], !items.isEmpty else { return nil }
            let displayName = Self.tabDisplayNames[tab] ?? tab
            return (tab: tab, displayName: displayName, items: items)
        }
    }

    private func recompute() {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { results = []; return }

        let tokens = trimmed.lowercased().split(separator: " ").map(String.init)
        var scored: [SettingsSearchResult] = []

        for item in items {
            let titleLower = item.title.lowercased()
            let descLower = item.description.lowercased()
            let keywordsLower = item.keywords.map { $0.lowercased() }

            var totalScore = 0
            var allTokensMatch = true

            for token in tokens {
                var tokenScore = 0

                if titleLower.hasPrefix(token) {
                    tokenScore = max(tokenScore, 10)
                } else if titleLower.contains(token) {
                    tokenScore = max(tokenScore, 6)
                }

                for kw in keywordsLower where kw.contains(token) {
                    tokenScore = max(tokenScore, 4)
                }

                if descLower.contains(token) {
                    tokenScore = max(tokenScore, 3)
                }

                if tokenScore == 0 { allTokensMatch = false; break }
                totalScore += tokenScore
            }

            if allTokensMatch, totalScore > 0 {
                scored.append(SettingsSearchResult(item: item, score: totalScore))
            }
        }

        scored.sort { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.item.title.localizedCaseInsensitiveCompare(rhs.item.title) == .orderedAscending
        }

        results = scored
    }
}
