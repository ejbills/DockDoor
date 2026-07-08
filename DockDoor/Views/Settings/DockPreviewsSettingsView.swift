import Defaults
import SwiftUI

struct DockPreviewsSettingsView: View {
    @Default(.enableDockPreviews) var enableDockPreviews
    @Default(.showWindowsFromCurrentSpaceOnly) var showWindowsFromCurrentSpaceOnly
    @Default(.showWindowsFromCurrentMonitorOnly) var showWindowsFromCurrentMonitorOnly
    @Default(.windowPreviewSortOrder) var windowPreviewSortOrder
    @Default(.keepPreviewOnAppTerminate) var keepPreviewOnAppTerminate
    @Default(.groupAppInstancesInDock) var groupAppInstancesInDock
    @Default(.collapseNativeTabsIntoSingleWindow) var collapseNativeTabsIntoSingleWindow
    @Default(.includeHiddenWindowsInDockPreview) var includeHiddenWindowsInDockPreview
    @Default(.showWindowlessAppsInDockPreview) var showWindowlessAppsInDockPreview
    @Default(.dockPreviewActivationMode) var dockPreviewActivationMode
    @Default(.dockPreviewActivationModifier) var dockPreviewActivationModifier
    @Default(.previewHoverAction) var previewHoverAction
    @Default(.tapEquivalentInterval) var tapEquivalentInterval
    @Default(.shouldHideOnDockItemClick) var shouldHideOnDockItemClick
    @Default(.dockClickAction) var dockClickAction
    @Default(.restoreAllMinimizedWindowsOnDockClick) var restoreAllMinimizedWindowsOnDockClick
    @Default(.enableCmdRightClickQuit) var enableCmdRightClickQuit
    @Default(.quitAppOnWindowClose) var quitAppOnWindowClose
    @Default(.bufferFromDock) var bufferFromDock
    @Default(.ignoreAppsWithSingleWindow) var ignoreAppsWithSingleWindow
    @Default(.enableFolderWidget) var enableFolderWidget
    @Default(.folderWidgetDefaultSortOrder) var folderWidgetDefaultSortOrder
    @Default(.folderWidgetDefaultSortReversed) var folderWidgetDefaultSortReversed
    @Default(.folderWidgetRememberSortPerFolder) var folderWidgetRememberSortPerFolder
    @Default(.folderWidgetShowHiddenFiles) var folderWidgetShowHiddenFiles

    var body: some View {
        BaseSettingsView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection

                if enableDockPreviews {
                    windowDisplaySection
                    dockInteractionSection
                    folderWidgetSection

                    SettingsMockPreview(context: .dock)

                    dockAppearanceSection
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        SettingsGroup {
            SettingsIllustratedToggle(
                isOn: $enableDockPreviews,
                title: "Enable Dock Previews",
                imageName: "DockPreviews"
            ) {
                Text("Show window previews for Dock icons.")
            }
            .settingsSearchTarget("dockPreviews.enable")
            .onChange(of: enableDockPreviews) { _ in askUserToRestartApplication() }
        }
    }

    // MARK: - Window Display

    private var windowDisplaySection: some View {
        SettingsGroup(header: "Window Display") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $showWindowsFromCurrentSpaceOnly) { Text("Show windows from current Space only") }
                    .settingsSearchTarget("dockPreviews.currentSpaceOnly")
                Text("Only display windows that are in the current virtual desktop/Space.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                Toggle(isOn: $showWindowsFromCurrentMonitorOnly) { Text("Show windows from current monitor only") }
                    .settingsSearchTarget("dockPreviews.currentMonitorOnly")
                Text("Only display windows that are on the same display as the Dock icon you're hovering.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                Picker("Window sort order", selection: $windowPreviewSortOrder) {
                    ForEach(WindowPreviewSortOrder.allCases.filter { !$0.isWindowSwitcherOnly }) { order in
                        Text(order.localizedName).tag(order)
                    }
                }
                .pickerStyle(.menu)
                .settingsSearchTarget("dockPreviews.sortOrder")

                Toggle(isOn: $includeHiddenWindowsInDockPreview) { Text("Include hidden/minimized windows") }
                    .settingsSearchTarget("dockPreviews.includeHidden")

                Toggle(isOn: $showWindowlessAppsInDockPreview) { Text("Show preview for apps with no open windows") }
                    .settingsSearchTarget("dockPreviews.showWindowless")
                Text("Show a placeholder preview when hovering dock apps that have no windows.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                Toggle(isOn: $keepPreviewOnAppTerminate) { Text("Keep preview when app terminates") }
                    .settingsSearchTarget("dockPreviews.keepOnTerminate")
                Text("Remove only terminated app's windows instead of hiding the entire preview.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                Toggle(isOn: $groupAppInstancesInDock) { Text("Group multiple app instances together") }
                    .settingsSearchTarget("dockPreviews.groupInstances")
                Text("Show windows from all instances of an app when hovering its dock icon.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                Toggle(isOn: $collapseNativeTabsIntoSingleWindow) { Text("Collapse native tabs into a single window") }
                    .settingsSearchTarget("dockPreviews.collapseNativeTabs")
                Text("Show one preview for apps that use native macOS window tabs (e.g. Ghostty, Finder, Terminal) instead of one preview per tab. Restart the app for this to take effect.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                Toggle(isOn: $ignoreAppsWithSingleWindow) { Text("Ignore apps with one window") }
                    .settingsSearchTarget("dockPreviews.ignoreSingleWindow")
                Text("Prevents apps that only ever have a single window from appearing in previews.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)
            }
        }
    }

    // MARK: - Folder Previews

    private var folderWidgetSection: some View {
        SettingsGroup(header: "Folder Previews") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $enableFolderWidget) { Text("Show folder contents on hover") }
                    .settingsSearchTarget("widgets.folder")
                Text("Preview a folder's contents when hovering it in the Dock.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                if enableFolderWidget {
                    Picker("Default sort:", selection: $folderWidgetDefaultSortOrder) {
                        ForEach(FolderWidgetSortOrder.allCases, id: \.self) { order in
                            Text(order.localizedName).tag(order)
                        }
                    }
                    .pickerStyle(.menu)
                    .settingsSearchTarget("widgets.folderSort")
                    .padding(.leading, 20)

                    Toggle(isOn: $folderWidgetDefaultSortReversed) { Text("Sort descending by default") }
                        .settingsSearchTarget("widgets.folderSortDirection")
                        .padding(.leading, 20)

                    Toggle(isOn: $folderWidgetRememberSortPerFolder) { Text("Remember sorting per folder") }
                        .settingsSearchTarget("widgets.folderRememberSort")
                        .padding(.leading, 20)

                    Toggle(isOn: $folderWidgetShowHiddenFiles) { Text("Show hidden files") }
                        .settingsSearchTarget("widgets.folderHiddenFiles")
                        .padding(.leading, 20)
                }
            }
        }
    }

    // MARK: - Appearance

    private var dockAppearanceSection: some View {
        SettingsGroup(header: "Appearance") {
            DockPreviewAppearanceSection()
        }
    }

    // MARK: - Dock Interaction

    private var dockInteractionSection: some View {
        SettingsGroup(header: "Dock Interaction") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Dock Preview Trigger", selection: $dockPreviewActivationMode) {
                    ForEach(DockPreviewActivationMode.allCases, id: \.self) {
                        Text($0.localizedName).tag($0)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .settingsSearchTarget("dockPreviews.activationTrigger")

                Text("Show previews automatically on hover, or require a click trigger on the Dock icon.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                if dockPreviewActivationMode == .modifierClick {
                    Picker("Dock Preview Modifier", selection: $dockPreviewActivationModifier) {
                        ForEach(DockPreviewActivationModifier.allCases, id: \.self) {
                            Text($0.localizedName).tag($0)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .settingsSearchTarget("dockPreviews.activationModifier")
                    .padding(.leading, 20)
                }

                Picker("Dock Preview Hover Action", selection: $previewHoverAction) {
                    ForEach(PreviewHoverAction.allCases, id: \.self) { Text($0.localizedName).tag($0) }
                }
                .pickerStyle(MenuPickerStyle())
                .settingsSearchTarget("dockPreviews.hoverAction")

                sliderSetting(title: "Preview Hover Action Delay", value: $tapEquivalentInterval, range: 0 ... 2, step: 0.1, unit: "seconds", formatter: NumberFormatter.oneDecimalFormatter)
                    .disabled(previewHoverAction == .none)
                    .settingsSearchTarget("dockPreviews.hoverDelay")

                Toggle(isOn: $shouldHideOnDockItemClick) { Text("Hide all app windows on dock icon click") }
                    .settingsSearchTarget("dockPreviews.hideOnClick")
                if shouldHideOnDockItemClick {
                    Picker("Dock Click Action", selection: $dockClickAction) {
                        ForEach(DockClickAction.allCases, id: \.self) {
                            Text($0.localizedName).tag($0)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .padding(.leading, 20)

                    if dockClickAction == .minimize {
                        Toggle(isOn: $restoreAllMinimizedWindowsOnDockClick) { Text("Restore all minimized windows on dock icon click") }
                            .settingsSearchTarget("dockPreviews.restoreAllMinimizedOnClick")
                            .padding(.leading, 20)
                    }
                }

                Toggle(isOn: $enableCmdRightClickQuit) { Text("CMD + Right Click on dock icon to quit app") }
                    .settingsSearchTarget("dockPreviews.cmdRightClickQuit")

                Toggle(isOn: $quitAppOnWindowClose) { Text("Quit app when closing its last window") }
                    .settingsSearchTarget("dockPreviews.quitOnClose")
                Text("When an app has only one window left, closing it will quit the app. Useful as a replacement for Swift Quit.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                sliderSetting(title: "Window Buffer from Dock (pixels)", value: $bufferFromDock, range: -100 ... 100, step: 5, unit: "px", formatter: { let f = NumberFormatter(); f.allowsFloats = false; f.minimumIntegerDigits = 1; f.maximumFractionDigits = 0; return f }())
                    .settingsSearchTarget("dockPreviews.buffer")
            }
        }
    }
}
