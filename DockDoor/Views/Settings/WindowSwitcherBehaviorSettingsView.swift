import AppKit
import Defaults
import SwiftUI

struct WindowSwitcherBehaviorSettingsView: View {
    @Default(.enableWindowSwitcher) var enableWindowSwitcher
    @Default(.enableCmdTabEnhancements) var enableCmdTabEnhancements
    @Default(.instantWindowSwitcher) var instantWindowSwitcher
    @Default(.enableWindowSwitcherSearch) var enableWindowSwitcherSearch
    @Default(.focusSearchOnWindowSwitcherOpen) var focusSearchOnWindowSwitcherOpen
    @Default(.searchFuzziness) var searchFuzziness
    @Default(.preventSwitcherHide) var preventSwitcherHide
    @Default(.enableMouseHoverInSwitcher) var enableMouseHoverInSwitcher
    @Default(.mouseHoverAutoScrollSpeed) var mouseHoverAutoScrollSpeed
    @Default(.includeHiddenWindowsInSwitcher) var includeHiddenWindowsInSwitcher
    @Default(.useClassicWindowOrdering) var useClassicWindowOrdering
    @Default(.limitSwitcherToFrontmostApp) var limitSwitcherToFrontmostApp
    @Default(.showWindowsFromCurrentSpaceOnlyInSwitcher) var showWindowsFromCurrentSpaceOnlyInSwitcher
    @Default(.showWindowsFromCurrentMonitorOnlyInSwitcher) var showWindowsFromCurrentMonitorOnlyInSwitcher
    @Default(.windowSwitcherSortOrder) var windowSwitcherSortOrder
    @Default(.groupedAppsInSwitcher) var groupedAppsInSwitcher
    @Default(.windowSwitcherPlacementStrategy) var placementStrategy
    @Default(.pinnedScreenIdentifier) var pinnedScreenIdentifier
    @Default(.windowSwitcherHorizontalOffsetPercent) var windowSwitcherHorizontalOffsetPercent
    @Default(.windowSwitcherVerticalOffsetPercent) var windowSwitcherVerticalOffsetPercent
    @Default(.windowSwitcherAnchorToTop) var windowSwitcherAnchorToTop
    @Default(.enableShiftWindowSwitcherPlacement) var enableShiftWindowSwitcherPlacement
    @Default(.showWindowlessAppsInSwitcher) var showWindowlessAppsInSwitcher
    @Default(.mouseFollowsFocusMode) var mouseFollowsFocusMode

    @State private var showGroupedAppsSheet: Bool = false

    var body: some View {
        SettingsFormView {
            headerSection

            if enableWindowSwitcher {
                appearanceSection
                WindowSwitcherKeybindSection()
                behaviorSection
                windowDisplaySection
                searchAndInputSection
                sortingAndGroupingSection
                placementSection
            }

            if enableWindowSwitcher || enableCmdTabEnhancements {
                CmdKeyShortcutsSection()
            }

            if enableWindowSwitcher {
                TrackpadSwitcherSwipeSection()
            }
        } pinnedHeader: {
            if enableWindowSwitcher {
                SettingsMockPreview(context: .windowSwitcher, maxHeight: 170)
            }
        }
        .sheet(isPresented: $showGroupedAppsSheet) {
            AppPickerSheet(
                selectedApps: $groupedAppsInSwitcher,
                title: "Group Windows by App",
                description: "Selected apps will show only their most recent window in the switcher.",
                selectionMode: AppPickerSheet.SelectionMode.include
            )
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        SettingsSection("Window Switcher") {
            Toggle(isOn: $enableWindowSwitcher) { Text("Enable Window Switcher") }
                .settingsSearchTarget("windowSwitcher.enable")
                .settingsAnnotation("The Window Switcher (often Alt/Cmd-Tab) lets you quickly cycle between open app windows with a keyboard shortcut.")
                .onChange(of: enableWindowSwitcher) { _ in askUserToRestartApplication() }
        }
    }

    // MARK: - Behavior

    private var behaviorSection: some View {
        SettingsSection("Behavior") {
            Toggle(isOn: $instantWindowSwitcher) { Text("Show Window Switcher instantly") }
                .settingsSearchTarget("windowSwitcher.instant")
                .settingsAnnotation("May feel snappier but can cause flickering if you quickly release the key.")

            Toggle(isOn: Binding(
                get: { !preventSwitcherHide },
                set: { preventSwitcherHide = !$0 }
            )) { Text("Release initializer key to select window") }
                .settingsSearchTarget("windowSwitcher.releaseToSelect")

            Toggle(isOn: $useClassicWindowOrdering) { Text("Start on second window") }
                .settingsSearchTarget("windowSwitcher.startOnSecond")
                .settingsAnnotation("Highlight the second window instead of the first when opening.")

            Picker(String(localized: "Mouse follows focus", comment: "Mouse follows focus setting label"), selection: $mouseFollowsFocusMode) {
                ForEach(MouseFollowsFocusMode.allCases, id: \.self) {
                    Text($0.localizedName).tag($0)
                }
            }
            .settingsSearchTarget("windowSwitcher.mouseFollowsFocus")
            .settingsAnnotation("Move the cursor to the center of the selected window.")
        }
    }

    // MARK: - Window Display

    private var windowDisplaySection: some View {
        SettingsSection("Window Display") {
            SharedWindowDisplayRows(
                currentSpaceOnly: $showWindowsFromCurrentSpaceOnlyInSwitcher,
                currentSpaceOnlyTarget: "windowSwitcher.currentSpaceOnly",
                monitorCaption: "Only display windows that are on the same display as the mouse cursor.",
                currentMonitorOnly: $showWindowsFromCurrentMonitorOnlyInSwitcher,
                currentMonitorOnlyTarget: "windowSwitcher.currentMonitorOnly",
                includeHidden: $includeHiddenWindowsInSwitcher,
                includeHiddenTarget: "windowSwitcher.includeHidden",
                showWindowless: $showWindowlessAppsInSwitcher,
                showWindowlessTarget: "windowSwitcher.showWindowless",
                windowlessTitle: "Show running apps with no open windows",
                windowlessCaption: "Dock-visible apps without any windows will appear as icon-only entries at the end."
            )

            Toggle(isOn: $limitSwitcherToFrontmostApp) { Text("Limit to active app only") }
                .settingsSearchTarget("windowSwitcher.limitToFrontmost")
                .settingsAnnotation("Only show windows from the currently active/frontmost application.")
        }
    }

    // MARK: - Search & Input

    private var searchAndInputSection: some View {
        SettingsSection("Search & Input") {
            Toggle(isOn: $enableWindowSwitcherSearch) { Text("Enable search") }
                .settingsSearchTarget("windowSwitcher.enableSearch")
            if enableWindowSwitcherSearch {
                Toggle(isOn: $focusSearchOnWindowSwitcherOpen) { Text("Focus search on open") }
                    .settingsSearchTarget("windowSwitcher.focusSearch")
                    .settingsAnnotation("Automatically focus the search bar when the window switcher opens.")

                SettingsSliderRow(
                    title: "Search Fuzziness",
                    value: Binding(get: { Double(searchFuzziness) }, set: { searchFuzziness = Int($0) }),
                    range: 1 ... 5
                )
                .settingsAnnotation("Level 1 is exact match, level 5 is most lenient fuzzy matching.")
            }

            Toggle(isOn: $enableMouseHoverInSwitcher) { Text("Enable mouse hover selection") }
                .settingsSearchTarget("windowSwitcher.mouseHover")
                .settingsAnnotation("Select and scroll to windows when hovering with mouse.")

            if enableMouseHoverInSwitcher {
                SettingsSliderRow(
                    title: "Auto-scroll speed:",
                    value: $mouseHoverAutoScrollSpeed,
                    range: 1 ... 10,
                    step: 0.5
                )
            }
        }
    }

    // MARK: - Sorting & Grouping

    private var sortingAndGroupingSection: some View {
        SettingsSection("Sorting & Grouping") {
            Picker("Window sort order", selection: $windowSwitcherSortOrder) {
                ForEach(WindowPreviewSortOrder.allCases) { order in
                    Text(order.localizedName).tag(order)
                }
            }
            .settingsSearchTarget("windowSwitcher.sortOrder")

            HStack {
                Text("Group windows by app")
                Spacer()
                if !groupedAppsInSwitcher.isEmpty {
                    Text("\(groupedAppsInSwitcher.count) app\(groupedAppsInSwitcher.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("Select...") {
                    showGroupedAppsSheet = true
                }
                .buttonStyle(.settings)
            }
            .settingsAnnotation("Selected apps show only their most recent window. All windows shown in active-app-only mode.")
            .settingsSearchTarget("windowSwitcher.groupByApp")
        }
    }

    // MARK: - Placement

    private var placementSection: some View {
        SettingsSection("Placement") {
            Picker("Screen", selection: $placementStrategy) {
                ForEach(WindowSwitcherPlacementStrategy.allCases, id: \.self) {
                    Text($0.localizedName).tag($0)
                }
            }
            .settingsSearchTarget("windowSwitcher.placement")
            .onChange(of: placementStrategy) { newStrategy in
                if newStrategy == .pinnedToScreen, pinnedScreenIdentifier.isEmpty {
                    pinnedScreenIdentifier = NSScreen.main?.uniqueIdentifier() ?? ""
                }
            }

            if placementStrategy == .pinnedToScreen {
                Picker("Pin to", selection: $pinnedScreenIdentifier) {
                    ForEach(NSScreen.screens, id: \.self) { screen in
                        Text(screen.displayName).tag(screen.uniqueIdentifier())
                    }
                    if !pinnedScreenIdentifier.isEmpty,
                       NSScreen.findScreen(byIdentifier: pinnedScreenIdentifier) == nil
                    {
                        Text("Disconnected Display").tag(pinnedScreenIdentifier)
                    }
                }
                .onAppear { NSScreen.migrateScreenIdentifier(.pinnedScreenIdentifier) }

                if !pinnedScreenIdentifier.isEmpty,
                   NSScreen.findScreen(byIdentifier: pinnedScreenIdentifier) == nil
                {
                    SettingsCallout(message: Text("This display is currently disconnected."))
                }
            }

            Toggle(isOn: $enableShiftWindowSwitcherPlacement) {
                Text("Offset position")
            }
            .settingsSearchTarget("windowSwitcher.offsetPosition")

            if enableShiftWindowSwitcherPlacement {
                Toggle(isOn: $windowSwitcherAnchorToTop) {
                    Text("Anchor to top")
                }
                .settingsAnnotation("Top edge stays fixed regardless of switcher size.")

                SettingsSliderRow(
                    title: "Vertical offset",
                    value: $windowSwitcherVerticalOffsetPercent,
                    range: -80 ... 80,
                    defaultValue: 0,
                    unit: "%"
                )

                SettingsSliderRow(
                    title: "Horizontal offset",
                    value: $windowSwitcherHorizontalOffsetPercent,
                    range: -80 ... 80,
                    defaultValue: 0,
                    unit: "%"
                )
            }
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        WindowSwitcherAppearanceSection()
    }
}
