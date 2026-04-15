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
    @Default(.showWindowsFromCurrentMonitorOnlyInSwitcher) var showWindowsFromCurrentMonitorOnlyInSwitcher
    @Default(.windowSwitcherSortOrder) var windowSwitcherSortOrder
    @Default(.windowSwitcherSortGroups) var windowSwitcherSortGroups
    @Default(.groupedAppsInSwitcher) var groupedAppsInSwitcher
    @Default(.windowSwitcherPlacementStrategy) var placementStrategy
    @Default(.pinnedScreenIdentifier) var pinnedScreenIdentifier
    @Default(.windowSwitcherHorizontalOffsetPercent) var windowSwitcherHorizontalOffsetPercent
    @Default(.windowSwitcherVerticalOffsetPercent) var windowSwitcherVerticalOffsetPercent
    @Default(.windowSwitcherAnchorToTop) var windowSwitcherAnchorToTop
    @Default(.enableShiftWindowSwitcherPlacement) var enableShiftWindowSwitcherPlacement
    @Default(.showWindowlessAppsInSwitcher) var showWindowlessAppsInSwitcher

    @State private var showGroupedAppsSheet: Bool = false
    @State private var showSortGroupSheet: Bool = false
    @State private var editingSortGroupIndex: Int?
    @State private var draftSortGroup = WindowSwitcherSortGroup()

    var body: some View {
        BaseSettingsView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection

                if enableWindowSwitcher {
                    behaviorSection
                    windowDisplaySection
                    searchAndInputSection
                    sortingAndGroupingSection
                    placementSection

                    SettingsMockPreview(context: .windowSwitcher)

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
        .sheet(isPresented: $showSortGroupSheet, onDismiss: commitSortGroupDraft) {
            AppPickerSheet(
                selectedApps: Binding(
                    get: { draftSortGroup.bundleIdentifiers },
                    set: { draftSortGroup.bundleIdentifiers = $0 }
                ),
                title: editingSortGroupIndex == nil ? "Create Custom Sort Group" : "Edit Custom Sort Group",
                description: "Select at least two apps. Apps in the same sort group stay adjacent in the Window Switcher, and apps already used in another group stay with the first group.",
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

                Toggle(isOn: Binding(
                    get: { !preventSwitcherHide },
                    set: { preventSwitcherHide = !$0 }
                )) { Text("Release initializer key to select window") }

                Toggle(isOn: $useClassicWindowOrdering) { Text("Start on second window") }
                Text("Highlight the second window instead of the first when opening.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)
            }
        }
    }

    // MARK: - Window Display

    private var windowDisplaySection: some View {
        SettingsGroup(header: "Window Display") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $showWindowsFromCurrentSpaceOnlyInSwitcher) { Text("Show windows from current Space only") }
                Text("Only display windows that are in the current virtual desktop/Space.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                Toggle(isOn: $showWindowsFromCurrentMonitorOnlyInSwitcher) { Text("Show windows from current monitor only") }
                Text("Only display windows that are on the same display as the mouse cursor.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                Toggle(isOn: $limitSwitcherToFrontmostApp) { Text("Limit to active app only") }
                Text("Only show windows from the currently active/frontmost application.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                Toggle(isOn: $includeHiddenWindowsInSwitcher) { Text("Include hidden/minimized windows") }

                Toggle(isOn: $showWindowlessAppsInSwitcher) { Text("Show running apps with no open windows") }
                Text("Dock-visible apps without any windows will appear as icon-only entries at the end.")
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

                Divider()
                    .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Custom app sort groups")
                        Spacer()
                        Button("Add Group") {
                            startCreatingSortGroup()
                        }
                        .buttonStyle(AccentButtonStyle(small: true))
                    }

                    if windowSwitcherSortGroups.isEmpty {
                        Text("No custom sort groups configured.")
                            .foregroundColor(.secondary)
                            .padding(.leading, 20)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(windowSwitcherSortGroups.enumerated()), id: \.element.id) { index, group in
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(sortGroupSummary(for: group))
                                            .lineLimit(2)

                                        Text(group.isPinned
                                            ? "\(group.appCount) app\(group.appCount == 1 ? "" : "s") (pinned)"
                                            : "\(group.appCount) app\(group.appCount == 1 ? "" : "s")")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    Button(group.isPinned ? "Unpin" : "Pin") {
                                        toggleSortGroupPin(at: index)
                                    }
                                    .buttonStyle(AccentButtonStyle(color: group.isPinned ? .orange : .accentColor, small: true))

                                    Button("Edit") {
                                        startEditingSortGroup(at: index)
                                    }
                                    .buttonStyle(AccentButtonStyle(small: true))

                                    DangerButton(
                                        action: {
                                            removeSortGroup(at: index)
                                        },
                                        label: {
                                            Text("Remove")
                                        },
                                        small: true
                                    )
                                }
                                .padding(.leading, 20)
                            }

                            HStack {
                                Spacer()
                                DangerButton(action: clearSortGroups) {
                                    Text("Clear All")
                                }
                            }
                            .padding(.leading, 20)
                        }
                    }

                    Text("When one app in a custom group appears in the sorted list, the rest of that group is kept next to it while preserving the selected sort order inside the group.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 20)

                    Text("Pinned custom groups always stay at the top of the switcher, ahead of unpinned groups and ungrouped windows.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 20)

                    Text("Each custom sort group needs at least two apps.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 20)
                }
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
                            Text(screen.displayName).tag(screen.uniqueIdentifier())
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

    private func startCreatingSortGroup() {
        editingSortGroupIndex = nil
        draftSortGroup = WindowSwitcherSortGroup()
        showSortGroupSheet = true
    }

    private func startEditingSortGroup(at index: Int) {
        guard windowSwitcherSortGroups.indices.contains(index) else { return }
        editingSortGroupIndex = index
        draftSortGroup = windowSwitcherSortGroups[index]
        showSortGroupSheet = true
    }

    private func commitSortGroupDraft() {
        defer {
            editingSortGroupIndex = nil
            draftSortGroup = WindowSwitcherSortGroup()
        }

        let trimmedBundleIdentifiers = uniqueBundleIdentifiers(from: draftSortGroup.bundleIdentifiers)
        guard !trimmedBundleIdentifiers.isEmpty || editingSortGroupIndex != nil else { return }

        var updatedGroups = windowSwitcherSortGroups

        if let editingSortGroupIndex, updatedGroups.indices.contains(editingSortGroupIndex) {
            if trimmedBundleIdentifiers.isEmpty {
                updatedGroups.remove(at: editingSortGroupIndex)
            } else {
                updatedGroups[editingSortGroupIndex].bundleIdentifiers = trimmedBundleIdentifiers
            }
        } else if !trimmedBundleIdentifiers.isEmpty {
            updatedGroups.append(WindowSwitcherSortGroup(bundleIdentifiers: trimmedBundleIdentifiers))
        }

        windowSwitcherSortGroups = normalizeSortGroups(updatedGroups)
    }

    private func normalizeSortGroups(_ groups: [WindowSwitcherSortGroup]) -> [WindowSwitcherSortGroup] {
        var seenBundleIdentifiers = Set<String>()

        return groups.compactMap { group in
            let filteredBundleIdentifiers = group.bundleIdentifiers.filter { bundleIdentifier in
                guard !bundleIdentifier.isEmpty else { return false }
                return seenBundleIdentifiers.insert(bundleIdentifier).inserted
            }

            guard filteredBundleIdentifiers.count >= 2 else { return nil }

            var updatedGroup = group
            updatedGroup.bundleIdentifiers = filteredBundleIdentifiers
            return updatedGroup
        }
    }

    private func uniqueBundleIdentifiers(from bundleIdentifiers: [String]) -> [String] {
        var seenBundleIdentifiers = Set<String>()
        return bundleIdentifiers.filter { bundleIdentifier in
            guard !bundleIdentifier.isEmpty else { return false }
            return seenBundleIdentifiers.insert(bundleIdentifier).inserted
        }
    }

    private func removeSortGroup(at index: Int) {
        guard windowSwitcherSortGroups.indices.contains(index) else { return }
        windowSwitcherSortGroups.remove(at: index)
    }

    private func toggleSortGroupPin(at index: Int) {
        guard windowSwitcherSortGroups.indices.contains(index) else { return }
        windowSwitcherSortGroups[index].isPinned.toggle()
    }

    private func clearSortGroups() {
        windowSwitcherSortGroups.removeAll()
    }

    private func sortGroupSummary(for group: WindowSwitcherSortGroup) -> String {
        let resolvedAppNames = group.bundleIdentifiers.map(resolveAppName(for:))
        let previewNames = Array(resolvedAppNames.prefix(2))
        let remainingCount = max(0, resolvedAppNames.count - previewNames.count)

        if previewNames.isEmpty {
            return "Unknown Apps"
        }

        if remainingCount > 0 {
            return previewNames.joined(separator: ", ") + " + \(remainingCount) more"
        }

        return previewNames.joined(separator: ", ")
    }

    private func resolveAppName(for bundleIdentifier: String) -> String {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier),
              let bundle = Bundle(url: appURL)
        else {
            return bundleIdentifier
        }

        return bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
            bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ??
            bundleIdentifier
    }
}
