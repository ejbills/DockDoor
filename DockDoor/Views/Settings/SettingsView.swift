import Cocoa
import SwiftUI

class SettingsManager: NSObject, ObservableObject {
    private var settingsWindowController: NSWindowController?
    private var updaterState: UpdaterState

    init(updaterState: UpdaterState) {
        self.updaterState = updaterState
        super.init()
    }

    func close() {
        settingsWindowController?.close()
    }

    func showSettings() {
        if settingsWindowController == nil {
            let settingsView = SettingsView(updaterState: updaterState)
            let hostingController = NSHostingController(rootView: settingsView)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )

            window.contentViewController = hostingController
            window.isReleasedWhenClosed = false

            window.delegate = self
            window.titlebarAppearsTransparent = true
            window.title = ""
            window.toolbarStyle = .unified

            let toolbar = NSToolbar(identifier: "SettingsToolbar")
            toolbar.delegate = self
            toolbar.showsBaselineSeparator = false
            toolbar.allowsUserCustomization = false
            toolbar.autosavesConfiguration = false
            window.toolbar = toolbar

            settingsWindowController = NSWindowController(window: window)
        }

        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.center()
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension SettingsManager: NSToolbarDelegate {
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        []
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        []
    }
}

extension SettingsManager: NSWindowDelegate {
    func windowDidBecomeKey(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        guard let window = notification.object as? NSWindow else {
            return
        }

        func findSplitView(in view: NSView) -> NSSplitView? {
            if let splitView = view as? NSSplitView {
                return splitView
            }
            for subview in view.subviews {
                if let found = findSplitView(in: subview) {
                    return found
                }
            }
            return nil
        }

        DispatchQueue.main.async {
            if let contentView = window.contentView,
               let splitView = findSplitView(in: contentView),
               let splitViewController = splitView.delegate as? NSSplitViewController
            {
                splitViewController.splitViewItems.first?.isCollapsed = false
                splitViewController.splitViewItems.first?.canCollapse = false
                splitViewController.splitViewItems.first?.holdingPriority = .defaultHigh
                splitViewController.splitViewItems.first?.minimumThickness = 200
                splitViewController.splitViewItems.first?.maximumThickness = 200
            }
        }
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

struct SettingsView: View {
    @State private var selectedTab = "General"
    @ObservedObject var updaterState: UpdaterState

    init(updaterState: UpdaterState) {
        self.updaterState = updaterState
    }

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all), sidebar: {
            List(selection: $selectedTab) {
                Label(String(localized: "General", comment: "Settings tab title"), systemImage: "gearshape.fill")
                    .tag("General")
                Label(String(localized: "Appearance", comment: "Settings Tab"), systemImage: "wand.and.stars.inverse")
                    .tag("Appearance")
                Label(String(localized: "Gestures & Keybinds", comment: "Settings tab title"), systemImage: "hand.draw.fill")
                    .tag("GesturesKeybinds")
                Label(String(localized: "Filters", comment: "Filters tab title"), systemImage: "air.purifier")
                    .tag("Filters")
                Label(String(localized: "Widgets", comment: "Widget settings tab title"), systemImage: "square.grid.2x2")
                    .tag("Widgets")
                Label(String(localized: "Support", comment: "Settings tab title"), systemImage: "lifepreserver.fill")
                    .tag("Support")
            }
            .listStyle(.sidebar)
            .frame(width: 200)
        }, detail: {
            Group {
                switch selectedTab {
                case "General":
                    MainSettingsView()
                case "Appearance":
                    AppearanceSettingsView()
                case "GesturesKeybinds":
                    GesturesAndKeybindsSettingsView()
                case "Filters":
                    FiltersSettingsView()
                case "Widgets":
                    WidgetSettingsView()
                case "Support":
                    SupportSettingsView(updaterState: updaterState)
                default:
                    MainSettingsView()
                }
            }
            .navigationSplitViewColumnWidth(min: 700, ideal: 700)
        })
    }
}
