import Cocoa
import Settings
import Sparkle

extension Settings.PaneIdentifier {
    static let general = Self("general")
    static let appearance = Self("appearance")
    static let permissions = Self("permissions")
    #if !APPSTORE_BUILD
        static let updates = Self("updates")
    #endif
    static let alttab = Self("alttab")
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

let WindowSwitcherSettingsViewController: () -> SettingsPane = {
    let paneView = Settings.Pane(
        identifier: .alttab,
        title: String(localized: "Window Switcher", comment: "Settings tab title"),
        toolbarIcon: NSImage(systemSymbolName: "text.and.command.macwindow", accessibilityDescription: String(localized: "Windows switching settings"))!
    ) {
        WindowSwitcherSettingsView()
    }

    return Settings.PaneHostingController(pane: paneView)
}

let PermissionsSettingsViewController: () -> SettingsPane = {
    let paneView = Settings.Pane(
        identifier: .permissions,
        title: String(localized: "Permissions", comment: "Settings tab title"),
        toolbarIcon: NSImage(systemSymbolName: "lock.shield", accessibilityDescription: String(localized: "Permissions settings"))!
    ) {
        PermissionsSettingsView()
    }

    return Settings.PaneHostingController(pane: paneView)
}

#if !APPSTORE_BUILD
    func UpdatesSettingsViewController(updater: SPUUpdater) -> SettingsPane {
        let paneView = Settings.Pane(
            identifier: .updates,
            title: String(localized: "Updates", comment: "Settings tab title"),
            toolbarIcon: NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: String(localized: "Update settings"))!
        ) {
            UpdateSettingsView(updater: updater)
        }

        return Settings.PaneHostingController(pane: paneView)
    }
#endif
