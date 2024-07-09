//
//  settings.swift
//  DockDoor
//
//  Created by Ethan Bills on 6/18/24.
//

import Cocoa
import Settings
import Sparkle

extension Settings.PaneIdentifier {
    static let general = Self("general")
    static let permissions = Self("permissions")
    static let updates = Self("updates")
    static let alttab = Self("alttab")
}

let GeneralSettingsViewController: () -> SettingsPane = {
    let paneView = Settings.Pane(
        identifier: .general,
        title: String(localized:"General", comment: "Settings Tab"),
        toolbarIcon: NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: "General settings")!
    ) {
        SettingsView()
    }

    return Settings.PaneHostingController(pane: paneView)
}

let WindowSwitcherSettingsViewController: () -> SettingsPane = {
    let paneView = Settings.Pane(
        identifier: .alttab,
        title: String(localized: "Window Switcher", comment: "Settings Tab"),
        toolbarIcon: NSImage(systemSymbolName: "text.and.command.macwindow", accessibilityDescription: "Windows switching settings")!
    ) {
        WindowSwitcherSettingsView()
    }

    return Settings.PaneHostingController(pane: paneView)
}

let PermissionsSettingsViewController: () -> SettingsPane = {
    let paneView = Settings.Pane(
        identifier: .permissions,
        title: String(localized:"Permissions", comment: "Settings Tab"),
        toolbarIcon: NSImage(systemSymbolName: "lock.shield", accessibilityDescription: "Permissions settings")!
    ) {
        PermView()
    }

    return Settings.PaneHostingController(pane: paneView)
}

func UpdatesSettingsViewController(updater: SPUUpdater) -> SettingsPane {
    let paneView = Settings.Pane(
        identifier: .updates,
        title: String(localized:"Updates", comment: "Settings Tab"),
        toolbarIcon: NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: "Update settings")!
    ) {
        UpdateView(updater: updater)
    }

    return Settings.PaneHostingController(pane: paneView)
}
