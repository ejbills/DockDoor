//
//  settings.swift
//  DockDoor
//
//  Created by Ethan Bills on 6/18/24.
//

import Cocoa
import Settings

extension Settings.PaneIdentifier {
    static let general = Self("general")
    static let permissions = Self("permissions")
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
