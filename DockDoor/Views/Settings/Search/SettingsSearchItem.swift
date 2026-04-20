import Foundation

struct SettingsSearchItem: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let keywords: [String]
    let tab: String
    let section: String
    let icon: String

    init(
        id: String,
        title: String,
        description: String = "",
        keywords: [String] = [],
        tab: String,
        section: String = "",
        icon: String = "gearshape"
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.keywords = keywords
        self.tab = tab
        self.section = section
        self.icon = icon
    }
}

struct SettingsSearchResult: Identifiable {
    let item: SettingsSearchItem
    let score: Int
    var id: String { item.id }
}
