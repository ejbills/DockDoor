import SwiftUI

/// Every pane's id, title, subtitle, icon and group. The sidebar, the detail
/// router and search all derive from it, so a pane is added in one place.
enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case dockPreviews = "DockPreviews"
    case windowSwitcher = "WindowSwitcher"
    case gestures = "Gestures"
    case cmdTab = "CmdTab"
    case appearance = "Appearance"
    case keybinds = "Keybinds"
    case filters = "Filters"
    case widgets = "Widgets"
    case advanced = "Advanced"
    case support = "Support"

    var id: String {
        rawValue
    }

    enum Section: CaseIterable, Identifiable {
        case features
        case customization
        case system

        var id: Self {
            self
        }

        var localizedTitle: String {
            switch self {
            case .features: String(localized: "Features", comment: "Settings section header")
            case .customization: String(localized: "Customization", comment: "Settings section header")
            case .system: String(localized: "System", comment: "Settings section header")
            }
        }
    }

    var localizedTitle: String {
        switch self {
        case .general: String(localized: "General", comment: "Settings tab title")
        case .dockPreviews: String(localized: "Dock Previews", comment: "Settings tab title")
        case .windowSwitcher: String(localized: "Window Switcher", comment: "Settings tab title")
        case .gestures: String(localized: "Gestures", comment: "Settings tab title")
        case .cmdTab: String(localized: "Cmd+Tab", comment: "Settings tab title")
        case .appearance: String(localized: "Appearance", comment: "Settings Tab")
        case .keybinds: String(localized: "Keybinds", comment: "Settings tab title")
        case .filters: String(localized: "Filters", comment: "Filters tab title")
        case .widgets: String(localized: "Widgets", comment: "Widget settings tab title")
        case .advanced: String(localized: "Advanced", comment: "Settings tab title")
        case .support: String(localized: "Support", comment: "Settings tab title")
        }
    }

    /// The toolbar subtitle, so panes carry no description of their own.
    var localizedSubtitle: String {
        switch self {
        case .general: String(localized: "Startup, backups and support", comment: "Settings tab subtitle")
        case .dockPreviews: String(localized: "Previews shown when hovering the Dock", comment: "Settings tab subtitle")
        case .windowSwitcher: String(localized: "Keyboard-driven window switching", comment: "Settings tab subtitle")
        case .gestures: String(localized: "Scroll, swipe and mouse actions", comment: "Settings tab subtitle")
        case .cmdTab: String(localized: "An enhanced Cmd-Tab overlay", comment: "Settings tab subtitle")
        case .appearance: String(localized: "Backgrounds, sizes and titles", comment: "Settings tab subtitle")
        case .keybinds: String(localized: "Shortcut keys for window actions", comment: "Settings tab subtitle")
        case .filters: String(localized: "Which apps and titles appear", comment: "Settings tab subtitle")
        case .widgets: String(localized: "Media, calendar and folder panels", comment: "Settings tab subtitle")
        case .advanced: String(localized: "Performance, previews and the Dock position lock", comment: "Settings tab subtitle")
        case .support: String(localized: "Help, updates and donations", comment: "Settings tab subtitle")
        }
    }

    var systemImage: String {
        switch self {
        case .general: "gearshape.fill"
        case .dockPreviews: "dock.rectangle"
        case .windowSwitcher: "uiwindow.split.2x1"
        case .gestures: "hand.draw.fill"
        case .cmdTab: "command"
        case .appearance: "wand.and.stars.inverse"
        case .keybinds: "keyboard"
        case .filters: "air.purifier"
        case .widgets: "square.grid.2x2"
        case .advanced: "slider.horizontal.3"
        case .support: "lifepreserver.fill"
        }
    }

    var tileColor: Color {
        switch self {
        case .general: .teal
        case .dockPreviews, .windowSwitcher, .gestures, .cmdTab: .blue
        case .appearance, .keybinds, .filters, .widgets: .indigo
        case .advanced, .support: .gray
        }
    }

    var section: Section? {
        switch self {
        case .general: nil
        case .dockPreviews, .windowSwitcher, .gestures, .cmdTab: .features
        case .appearance, .keybinds, .filters, .widgets: .customization
        case .advanced, .support: .system
        }
    }

    static func tabs(in section: Section) -> [SettingsTab] {
        allCases.filter { $0.section == section }
    }
}

/// System Settings-style icon tile: a continuous-corner square filled with
/// the pane's hue behind a white glyph.
struct SettingsTabIconTile: View {
    let tab: SettingsTab
    var side: CGFloat = 20

    var body: some View {
        RoundedRectangle(cornerRadius: side * 0.28, style: .continuous)
            .fill(tab.tileColor.gradient)
            .frame(width: side, height: side)
            .overlay {
                Image(systemName: tab.systemImage)
                    .resizable()
                    .scaledToFit()
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .frame(width: side * 0.58, height: side * 0.58)
            }
    }
}
