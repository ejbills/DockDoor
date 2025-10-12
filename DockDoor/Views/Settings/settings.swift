import Cocoa
import Settings

extension Settings.PaneIdentifier {
    static let general = Self("general")
    static let appearance = Self("appearance")
    static let filters = Self("filters")
    static let support = Self("support")
}

let GeneralSettingsViewController: () -> SettingsPane = {
    let paneView = Settings.Pane(
        identifier: .general,
        title: String(localized: "General", comment: "Settings tab title"),
        toolbarIcon: NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: String(localized: "General settings"))!
    ) {
        MainSettingsView()
    }

    return Settings.PaneHostingController(pane: paneView)
}

let AppearanceSettingsViewController: () -> SettingsPane = {
    let paneView = Settings.Pane(
        identifier: .appearance,
        title: String(localized: "Appearance", comment: "Settings Tab"),
        toolbarIcon: NSImage(systemSymbolName: "wand.and.stars.inverse", accessibilityDescription: String(localized: "Appearance settings"))!
    ) {
        AppearanceSettingsView()
    }

    return Settings.PaneHostingController(pane: paneView)
}

let FiltersSettingsViewController: () -> SettingsPane = {
    let paneView = Settings.Pane(
        identifier: .filters,
        title: String(localized: "Filters", comment: "Filters tab title"),
        toolbarIcon: NSImage(systemSymbolName: "air.purifier", accessibilityDescription: String(localized: "Filters settings"))!
    ) {
        FiltersSettingsView()
    }

    return Settings.PaneHostingController(pane: paneView)
}

func SupportSettingsViewController(updaterState: UpdaterState) -> SettingsPane {
    let paneView = Settings.Pane(
        identifier: .support,
        title: String(localized: "Support", comment: "Settings tab title"),
        toolbarIcon: NSImage(systemSymbolName: "lifepreserver.fill", accessibilityDescription: String(localized: "Support settings"))!
    ) {
        SupportSettingsView(updaterState: updaterState)
    }

    return Settings.PaneHostingController(pane: paneView)
}
