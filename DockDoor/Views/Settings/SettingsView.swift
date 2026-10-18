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
            window.title = ""
            window.toolbarStyle = .unified

            let toolbar = NSToolbar(identifier: "SettingsToolbar")
            toolbar.delegate = self
            toolbar.showsBaselineSeparator = false
            toolbar.allowsUserCustomization = false
            toolbar.autosavesConfiguration = false
            window.toolbar = toolbar

            settingsWindowController = NSWindowController(window: window)
            installMainMenuIfNeeded()
        }

        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.center()
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.async {
            Task { await WindowUtil.updateNewWindowsForApp(.current) }
        }
    }

    private func installMainMenuIfNeeded() {
        guard NSApp.mainMenu == nil else { return }
        let mainMenu = NSMenu()

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: String(localized: "Quit DockDoor"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        mainMenu.addItem(NSMenuItem(submenu: appMenu))

        let editMenu = NSMenu(title: String(localized: "Edit"))
        editMenu.addItem(withTitle: String(localized: "Undo"), action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: String(localized: "Redo"), action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: String(localized: "Cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: String(localized: "Copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: String(localized: "Paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: String(localized: "Select All"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        mainMenu.addItem(NSMenuItem(submenu: editMenu))

        let windowMenu = NSMenu(title: String(localized: "Window"))
        windowMenu.addItem(withTitle: String(localized: "Close"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: String(localized: "Minimize"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        mainMenu.addItem(NSMenuItem(submenu: windowMenu))

        NSApp.mainMenu = mainMenu
        NSApp.windowsMenu = windowMenu
    }
}

private extension NSMenuItem {
    convenience init(submenu: NSMenu) {
        self.init(title: submenu.title, action: nil, keyEquivalent: "")
        self.submenu = submenu
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
                splitViewController.splitViewItems.first?.minimumThickness = 230
                splitViewController.splitViewItems.first?.maximumThickness = 230
            }
        }
    }

    func windowWillClose(_ notification: Notification) {
        let pid = ProcessInfo.processInfo.processIdentifier
        WindowUtil.purgeAppCache(with: pid)
        DispatchQueue.main.asyncAfter(deadline: .now() + 11) { [weak self] in
            if self?.settingsWindowController == nil {
                WindowUtil.purgeAppCache(with: pid)
            }
        }
        settingsWindowController?.window?.contentViewController = nil
        settingsWindowController = nil
        NSApp.setActivationPolicy(.accessory)
    }
}

struct SettingsView: View {
    @State private var selectedTab = SettingsTab.general
    @StateObject private var searchEngine = SettingsSearchEngine()
    @State private var scrollTarget: String?
    @FocusState private var isSearchFieldFocused: Bool
    @ObservedObject var updaterState: UpdaterState

    init(updaterState: UpdaterState) {
        self.updaterState = updaterState
    }

    private var isSearching: Bool {
        searchEngine.isSearching
    }

    private var toolbarTitle: String {
        isSearching
            ? String(localized: "Search", comment: "Toolbar title while searching settings")
            : selectedTab.localizedTitle
    }

    private var toolbarSubtitle: String {
        isSearching ? "" : selectedTab.localizedSubtitle
    }

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all), sidebar: {
            sidebar
        }, detail: {
            detail
        })
        .background {
            // ⌘F from anywhere in the window lands in the sidebar field.
            Button("Find") {
                isSearchFieldFocused = true
            }
            .keyboardShortcut("f", modifiers: .command)
            .hidden()
        }
    }

    private var sidebar: some View {
        List(selection: $selectedTab) {
            sidebarRow(.general)

            ForEach(SettingsTab.Section.allCases) { section in
                Section {
                    ForEach(SettingsTab.tabs(in: section)) { tab in
                        sidebarRow(tab)
                    }
                } header: {
                    Text(verbatim: section.localizedTitle)
                }
            }
        }
        .listStyle(.sidebar)
        // Medium rows regardless of the system sidebar size; Large crowds this window.
        .environment(\.sidebarRowSize, .medium)
        .safeAreaInset(edge: .top, spacing: 0) {
            searchField
        }
        .frame(minWidth: 230, maxWidth: 230)
        .modifier(HideSidebarToggleModifier())
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField(
                String(localized: "Search settings…", comment: "Settings search placeholder"),
                text: $searchEngine.query
            )
            .textFieldStyle(.plain)
            .font(.callout)
            .focused($isSearchFieldFocused)

            if !searchEngine.query.isEmpty {
                Button {
                    searchEngine.query = ""
                    isSearchFieldFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background {
            if #available(macOS 26.0, *) {
                Color.clear
                    .glassEffect(in: Capsule())
            } else {
                Capsule()
                    .fill(Color.primary.opacity(0.07))
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 2)
        .padding(.bottom, 8)
    }

    private func sidebarRow(_ tab: SettingsTab) -> some View {
        Label {
            Text(verbatim: tab.localizedTitle)
                .font(.callout)
        } icon: {
            Image(systemName: tab.systemImage)
        }
        .tag(tab)
    }

    private var detail: some View {
        Group {
            if isSearching {
                SettingsSearchResultsView(engine: searchEngine) { item in
                    selectedTab = SettingsTab(rawValue: item.tab) ?? .general
                    searchEngine.query = ""
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        scrollTarget = item.id
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                pane(for: selectedTab)
                    .environment(\.settingsScrollTarget, scrollTarget)
                    .onChange(of: scrollTarget) { newTarget in
                        if newTarget != nil {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                scrollTarget = nil
                            }
                        }
                    }
            }
        }
        // The toolbar names the pane, so no pane carries a heading of its own.
        .navigationTitle(Text(verbatim: toolbarTitle))
        .navigationSubtitle(Text(verbatim: toolbarSubtitle))
    }

    @ViewBuilder
    private func pane(for tab: SettingsTab) -> some View {
        switch tab {
        case .general: MainSettingsView()
        case .dockPreviews: DockPreviewsSettingsView()
        case .windowSwitcher: WindowSwitcherBehaviorSettingsView()
        case .gestures: GesturesSettingsView()
        case .cmdTab: CmdTabSettingsView()
        case .appearance: AppearanceSettingsView()
        case .filters: FiltersSettingsView()
        case .widgets: WidgetSettingsView()
        case .advanced: AdvancedSettingsView()
        case .support: SupportSettingsView(updaterState: updaterState)
        }
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
