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
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.minSize = NSSize(width: 750, height: 400)

            window.contentViewController = hostingController
            window.isReleasedWhenClosed = true

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

        DispatchQueue.main.async {
            Task { await WindowUtil.updateNewWindowsForApp(.current) }
        }
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
                splitViewController.splitViewItems.first?.minimumThickness = 270
                splitViewController.splitViewItems.first?.maximumThickness = 270
            }
        }
    }

    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            let windowID = CGWindowID(window.windowNumber)
            WindowUtil.removeWindowFromDesktopSpaceCache(with: windowID, in: ProcessInfo.processInfo.processIdentifier)
        }
        settingsWindowController?.window?.contentViewController = nil
        settingsWindowController = nil
        NSApp.setActivationPolicy(.accessory)
    }
}

struct SettingsView: View {
    @State private var selectedTab = "General"
    @StateObject private var searchEngine = SettingsSearchEngine()
    @State private var scrollTarget: String?
    @ObservedObject var updaterState: UpdaterState

    init(updaterState: UpdaterState) {
        self.updaterState = updaterState
    }

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all), sidebar: {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                    TextField(String(localized: "Search settings…", comment: "Settings search placeholder"), text: $searchEngine.query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    if !searchEngine.query.isEmpty {
                        Button {
                            searchEngine.query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider()

                if searchEngine.isSearching {
                    SettingsSearchResultsView(engine: searchEngine) { item in
                        selectedTab = item.tab
                        searchEngine.query = ""
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            scrollTarget = item.id
                        }
                    }
                } else {
                    List(selection: $selectedTab) {
                        Spacer()
                            .frame(height: 1)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)

                        Label(String(localized: "General", comment: "Settings tab title"), systemImage: "gearshape.fill")
                            .tag("General")

                        Section(String(localized: "Features", comment: "Settings section header")) {
                            Label(String(localized: "Dock Previews", comment: "Settings tab title"), systemImage: "dock.rectangle")
                                .tag("DockPreviews")
                            Label(String(localized: "Window Switcher", comment: "Settings tab title"), systemImage: "uiwindow.split.2x1")
                                .tag("WindowSwitcher")
                            Label(String(localized: "Cmd+Tab", comment: "Settings tab title"), systemImage: "command")
                                .tag("CmdTab")
                            Label(String(localized: "Dock Locking", comment: "Settings tab title"), systemImage: "lock.fill")
                                .tag("DockLocking")
                        }

                        Section(String(localized: "Customization", comment: "Settings section header")) {
                            Label(String(localized: "Appearance", comment: "Settings Tab"), systemImage: "wand.and.stars.inverse")
                                .tag("Appearance")
                            Label(String(localized: "Gestures & Keybinds", comment: "Settings tab title"), systemImage: "hand.draw.fill")
                                .tag("GesturesKeybinds")
                            Label(String(localized: "Filters", comment: "Filters tab title"), systemImage: "air.purifier")
                                .tag("Filters")
                            Label(String(localized: "Widgets", comment: "Widget settings tab title"), systemImage: "square.grid.2x2")
                                .tag("Widgets")
                        }

                        Section(String(localized: "System", comment: "Settings section header")) {
                            Label(String(localized: "Advanced", comment: "Settings tab title"), systemImage: "slider.horizontal.3")
                                .tag("Advanced")
                            Label(String(localized: "Support", comment: "Settings tab title"), systemImage: "lifepreserver.fill")
                                .tag("Support")
                        }
                    }
                    .listStyle(.sidebar)
                }
            }
            .frame(minWidth: 270, maxWidth: 270)
            .modifier(HideSidebarToggleModifier())
        }, detail: {
            Group {
                switch selectedTab {
                case "General":
                    MainSettingsView()
                case "DockPreviews":
                    DockPreviewsSettingsView()
                case "WindowSwitcher":
                    WindowSwitcherBehaviorSettingsView()
                case "CmdTab":
                    CmdTabSettingsView()
                case "DockLocking":
                    DockLockingSettingsView()
                case "Appearance":
                    AppearanceSettingsView()
                case "GesturesKeybinds":
                    GesturesAndKeybindsSettingsView()
                case "Filters":
                    FiltersSettingsView()
                case "Widgets":
                    WidgetSettingsView()
                case "Advanced":
                    AdvancedSettingsView()
                case "Support":
                    SupportSettingsView(updaterState: updaterState)
                default:
                    MainSettingsView()
                }
            }
            .environment(\.settingsScrollTarget, scrollTarget)
            .onChange(of: scrollTarget) { newTarget in
                if newTarget != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        scrollTarget = nil
                    }
                }
            }
        })
    }
}

private struct HideSidebarToggleModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content.toolbar(removing: .sidebarToggle)
        } else {
            content
        }
    }
}
