import Cocoa
import Settings
import Sparkle

extension Settings.PaneIdentifier {
    static let general = Self("general")
    static let dockpreviews = Self("dockpreviews")
    static let windowswitcher = Self("windowswitcher")
}

let MainSettingsViewController: () -> SettingsPane = {
    let paneView = Settings.Pane(
        identifier: .general,
        title: String(localized: "General", comment: "Settings tab title"),
        toolbarIcon: NSImage(systemSymbolName: "gearshape", accessibilityDescription: String(localized: "General settings"))!
    ) {
        MainSettingsView()
    }
    return Settings.PaneHostingController(pane: paneView)
}

let DockPreviewsViewController: () -> SettingsPane = {
    let paneView = Settings.Pane(
        identifier: .dockpreviews,
        title: String(localized: "Dock Previews", comment: "Settings tab title"),
        toolbarIcon: NSImage(systemSymbolName: "bubble.middle.bottom", accessibilityDescription: String(localized: "Dock previews settings"))!
    ) {
        DockPreviewsView()
    }
    return Settings.PaneHostingController(pane: paneView)
}

let WindowSwitcherViewController: () -> SettingsPane = {
    let paneView = Settings.Pane(
        identifier: .windowswitcher,
        title: String(localized: "Window Switcher", comment: "Settings tab title"),
        toolbarIcon: NSImage(systemSymbolName: "macwindow", accessibilityDescription: String(localized: "Window switcher settings"))!
    ) {
        WindowSwitcherView()
    }
    return Settings.PaneHostingController(pane: paneView)
}
