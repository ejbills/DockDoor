import AppKit
import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case appearance
    case filters
    case support

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .general: "General"
        case .appearance: "Appearance"
        case .filters: "Filters"
        case .support: "Support"
        }
    }

    var systemImage: String {
        switch self {
        case .general: "gearshape.fill"
        case .appearance: "wand.and.stars.inverse"
        case .filters: "air.purifier"
        case .support: "lifepreserver.fill"
        }
    }
}

struct SettingsWindowView: View {
    @State private var selection: SettingsTab = .general
    @State private var searchText: String = ""
    @ObservedObject var updaterState: UpdaterState

    private var sidebarGroups: [(title: LocalizedStringKey, tabs: [SettingsTab])] {
        [
            (title: "General", tabs: [.general]),
            (title: "Personalization", tabs: [.appearance, .filters]),
            (title: "Support", tabs: [.support]),
        ]
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(Array(sidebarGroups.enumerated()), id: \.offset) { _, group in
                    Section(header: Text(group.title)) {
                        ForEach(group.tabs) { tab in
                            Label {
                                Text(tab.title)
                            } icon: {
                                Image(systemName: tab.systemImage)
                                    .frame(width: 18)
                            }
                            .tag(tab)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
        } detail: {
            contentView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        Button(action: toggleSidebar) {
                            Image(systemName: "sidebar.leading")
                        }
                        .help(String(localized: "Toggle Sidebar"))
                    }
                }
                .searchable(text: $searchText, placement: .toolbar, prompt: String(localized: "Search Settings")) {
                    ForEach(SettingsSearchIndex.searchSuggestions, id: \.self) { suggestion in
                        Text(LocalizedStringKey(suggestion)).searchCompletion(suggestion)
                    }
                }
                .onSubmit(of: .search, perform: routeSearch)
        }
        .frame(minWidth: 900, minHeight: 560)
    }

    @ViewBuilder
    private var contentView: some View {
        switch selection {
        case .general:
            MainSettingsView()
        case .appearance:
            AppearanceSettingsView()
        case .filters:
            FiltersSettingsView()
        case .support:
            SupportSettingsView(updaterState: updaterState)
        }
    }

    private func routeSearch() {
        guard let destination = SettingsSearchIndex.destination(for: searchText) else { return }
        selection = destination
    }

    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
}

private enum SettingsSearchIndex {
    static let index: [(keywords: [String], tab: SettingsTab)] = [
        (["general", "login", "launch", "menu bar", "dock previews", "window switcher", "pin", "performance"], .general),
        (["appearance", "style", "titles", "icons", "spacing", "opacity", "rounded"], .appearance),
        (["filters", "exclude", "ignore", "include"], .filters),
        (["support", "permissions", "updates", "help", "acknowledgments", "about"], .support),
    ]

    static var searchSuggestions: [String] {
        [
            "Launch at login",
            "Menu bar icon",
            "Dock previews",
            "Window Switcher",
            "Appearance",
            "Filters",
            "Permissions",
            "Updates",
            "Help",
        ]
    }

    static func destination(for text: String) -> SettingsTab? {
        let q = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return nil }
        for entry in index {
            if entry.keywords.contains(where: { q.contains($0) || $0.contains(q) }) {
                return entry.tab
            }
        }
        return nil
    }
}
