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
}

let GeneralSettingsViewController: () -> SettingsPane = {
    let paneView = Settings.Pane(
        identifier: .general,
        title: "General",
        toolbarIcon: NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: "General settings")!
    ) {
        SettingsView()
    }

    return Settings.PaneHostingController(pane: paneView)
}

let PermissionsSettingsViewController: () -> SettingsPane = {
    let paneView = Settings.Pane(
        identifier: .permissions,
        title: "Permissions",
        toolbarIcon: NSImage(systemSymbolName: "lock.shield", accessibilityDescription: "Permissions settings")!
    ) {
        PermView()
    }

    return Settings.PaneHostingController(pane: paneView)
}

func UpdatesSettingsViewController(updater: SPUUpdater) -> SettingsPane {
    let paneView = Settings.Pane(
        identifier: .updates,
        title: "Updates",
        toolbarIcon: NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: "Update settings")!
    ) {
        CheckForUpdatesView(updater: updater)
    }

    return Settings.PaneHostingController(pane: paneView)
}
