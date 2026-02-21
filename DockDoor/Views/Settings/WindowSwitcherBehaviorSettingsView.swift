import AppKit
import Defaults
import SwiftUI

struct WindowSwitcherBehaviorSettingsView: View {
    @Default(.enableWindowSwitcher) var enableWindowSwitcher
    @Default(.instantWindowSwitcher) var instantWindowSwitcher
    @Default(.enableWindowSwitcherSearch) var enableWindowSwitcherSearch
    @Default(.searchFuzziness) var searchFuzziness
    @Default(.preventSwitcherHide) var preventSwitcherHide
    @Default(.enableMouseHoverInSwitcher) var enableMouseHoverInSwitcher
    @Default(.mouseHoverAutoScrollSpeed) var mouseHoverAutoScrollSpeed
    @Default(.includeHiddenWindowsInSwitcher) var includeHiddenWindowsInSwitcher
    @Default(.useClassicWindowOrdering) var useClassicWindowOrdering
    @Default(.limitSwitcherToFrontmostApp) var limitSwitcherToFrontmostApp
    @Default(.showWindowsFromCurrentSpaceOnlyInSwitcher) var showWindowsFromCurrentSpaceOnlyInSwitcher
    @Default(.windowSwitcherSortOrder) var windowSwitcherSortOrder
    @Default(.groupedAppsInSwitcher) var groupedAppsInSwitcher
    @Default(.windowSwitcherPlacementStrategy) var placementStrategy
    @Default(.pinnedScreenIdentifier) var pinnedScreenIdentifier
    @Default(.windowSwitcherHorizontalOffsetPercent) var windowSwitcherHorizontalOffsetPercent
    @Default(.windowSwitcherVerticalOffsetPercent) var windowSwitcherVerticalOffsetPercent
    @Default(.windowSwitcherAnchorToTop) var windowSwitcherAnchorToTop
    @Default(.enableShiftWindowSwitcherPlacement) var enableShiftWindowSwitcherPlacement

    @State private var showGroupedAppsSheet: Bool = false

    var body: some View {
        BaseSettingsView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection

                if enableWindowSwitcher {
                    behaviorSection
                    searchAndInputSection
                    sortingAndGroupingSection
                    placementSection
                    appearanceSection
                }
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
        SettingsGroup {
            SettingsIllustratedToggle(
                isOn: $enableWindowSwitcher,
                title: "Enable Window Switcher",
                imageName: "WindowSwitcher"
            ) {
                Text("The Window Switcher (often Alt/Cmd-Tab) lets you quickly cycle between open app windows with a keyboard shortcut.")
            }
            .onChange(of: enableWindowSwitcher) { _ in askUserToRestartApplication() }
        }
    }

    // MARK: - Behavior

    private var behaviorSection: some View {
        SettingsGroup(header: "Behavior") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $instantWindowSwitcher) { Text("Show Window Switcher instantly") }
                Text("May feel snappier but can cause flickering if you quickly release the key.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                Toggle(isOn: $includeHiddenWindowsInSwitcher) { Text("Include hidden/minimized windows") }

                Toggle(isOn: Binding(
                    get: { !preventSwitcherHide },
                    set: { preventSwitcherHide = !$0 }
                )) { Text("Release initializer key to select window") }

                Toggle(isOn: $useClassicWindowOrdering) { Text("Start on second window") }
                Text("Highlight the second window instead of the first when opening.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                Toggle(isOn: $limitSwitcherToFrontmostApp) { Text("Limit to active app only") }
                Text("Only show windows from the currently active/frontmost application.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                Toggle(isOn: $showWindowsFromCurrentSpaceOnlyInSwitcher) { Text("Show windows from current Space only") }
                Text("Only display windows that are in the current virtual desktop/Space.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)
            }
        }
    }

    // MARK: - Search & Input

    private var searchAndInputSection: some View {
        SettingsGroup(header: "Search & Input") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $enableWindowSwitcherSearch) { Text("Enable search") }
                if enableWindowSwitcherSearch {
                    HStack {
                        Text("Search Fuzziness")
                        Slider(value: Binding(
                            get: { Double(searchFuzziness) },
                            set: { searchFuzziness = Int($0) }
                        ), in: 1 ... 5, step: 1)
                        Text("\(searchFuzziness)")
                            .frame(width: 20)
                    }
                    .padding(.leading, 20)
                    Text("Level 1 is exact match, level 5 is most lenient fuzzy matching.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 20)
                }

                Toggle(isOn: $enableMouseHoverInSwitcher) { Text("Enable mouse hover selection") }
                Text("Select and scroll to windows when hovering with mouse.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                if enableMouseHoverInSwitcher {
                    HStack {
                        Text("Auto-scroll speed:")
                        Slider(value: $mouseHoverAutoScrollSpeed, in: 1 ... 10, step: 0.5)
                        Text(String(format: "%.1f", mouseHoverAutoScrollSpeed))
                            .frame(width: 30)
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 20)
                }
            }
        }
    }

    // MARK: - Sorting & Grouping

    private var sortingAndGroupingSection: some View {
        SettingsGroup(header: "Sorting & Grouping") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Window sort order", selection: $windowSwitcherSortOrder) {
                    ForEach(WindowPreviewSortOrder.allCases) { order in
                        Text(order.localizedName).tag(order)
                    }
                }
                .pickerStyle(.menu)

                HStack {
                    Text("Group windows by app")
                    Spacer()
                    if !groupedAppsInSwitcher.isEmpty {
                        Text("\(groupedAppsInSwitcher.count) app\(groupedAppsInSwitcher.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Button("Select...") {
                        showGroupedAppsSheet = true
                    }
                    .buttonStyle(AccentButtonStyle(small: true))
                }
                Text("Selected apps show only their most recent window. All windows shown in active-app-only mode.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)
            }
        }
    }

    // MARK: - Placement

    private var placementSection: some View {
        SettingsGroup(header: "Placement") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Screen", selection: $placementStrategy) {
                    ForEach(WindowSwitcherPlacementStrategy.allCases, id: \.self) {
                        Text($0.localizedName).tag($0)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: placementStrategy) { newStrategy in
                    if newStrategy == .pinnedToScreen, pinnedScreenIdentifier.isEmpty {
                        pinnedScreenIdentifier = NSScreen.main?.uniqueIdentifier() ?? ""
                    }
                }

                if placementStrategy == .pinnedToScreen {
                    Picker("Pin to", selection: $pinnedScreenIdentifier) {
                        ForEach(NSScreen.screens, id: \.self) { screen in
                            Text(screenDisplayName(screen)).tag(screen.uniqueIdentifier())
                        }
                        if !pinnedScreenIdentifier.isEmpty,
                           !NSScreen.screens.contains(where: { $0.uniqueIdentifier() == pinnedScreenIdentifier })
                        {
                            Text("Disconnected Display").tag(pinnedScreenIdentifier)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.leading, 20)

                    if !pinnedScreenIdentifier.isEmpty,
                       !NSScreen.screens.contains(where: { $0.uniqueIdentifier() == pinnedScreenIdentifier })
                    {
                        Text("This display is currently disconnected.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 20)
                    }
                }

                Toggle(isOn: $enableShiftWindowSwitcherPlacement) {
                    Text("Offset position")
                }

                if enableShiftWindowSwitcherPlacement {
                    Toggle(isOn: $windowSwitcherAnchorToTop) {
                        Text("Anchor to top")
                    }
                    .padding(.leading, 20)
                    Text("Top edge stays fixed regardless of switcher size.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 40)

                    HStack {
                        Image(systemName: "arrow.up")
                            .foregroundColor(.secondary)
                            .frame(width: 16)
                        Slider(value: $windowSwitcherVerticalOffsetPercent, in: -80 ... 80)
                        Text("\(Int(windowSwitcherVerticalOffsetPercent))%")
                            .monospacedDigit()
                            .frame(width: 45, alignment: .trailing)
                    }
                    .padding(.leading, 20)

                    HStack {
                        Image(systemName: "arrow.right")
                            .foregroundColor(.secondary)
                            .frame(width: 16)
                        Slider(value: $windowSwitcherHorizontalOffsetPercent, in: -80 ... 80)
                        Text("\(Int(windowSwitcherHorizontalOffsetPercent))%")
                            .monospacedDigit()
                            .frame(width: 45, alignment: .trailing)
                    }
                    .padding(.leading, 20)
                }
            }
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        SettingsGroup(header: "Appearance") {
            WindowSwitcherAppearanceSection()
        }
    }

    // MARK: - Helper Functions

    private func screenDisplayName(_ screen: NSScreen) -> String {
        let isMain = screen == NSScreen.main
        var name = screen.localizedName
        if name.isEmpty {
            if let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
                name = String(format: NSLocalizedString("Display %u", comment: "Generic display name with CGDirectDisplayID"), displayID)
            } else {
                name = String(localized: "Unknown Display")
            }
        }
        return name + (isMain ? " (Main)" : "")
    }
}
