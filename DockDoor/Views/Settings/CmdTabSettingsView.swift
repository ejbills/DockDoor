import Defaults
import SwiftUI

struct CmdTabSettingsView: View {
    @Default(.enableCmdTabEnhancements) var enableCmdTabEnhancements
    @Default(.cmdTabCycleKey) var cmdTabCycleKey
    @Default(.cmdTabBackwardCycleKey) var cmdTabBackwardCycleKey
    @Default(.showWindowsFromCurrentSpaceOnlyInCmdTab) var showWindowsFromCurrentSpaceOnlyInCmdTab
    @Default(.showWindowsFromCurrentMonitorOnlyInCmdTab) var showWindowsFromCurrentMonitorOnlyInCmdTab
    @Default(.cmdTabSortOrder) var cmdTabSortOrder
    @Default(.cmdTabAutoSelectFirstWindow) var cmdTabAutoSelectFirstWindow
    @Default(.includeHiddenWindowsInCmdTab) var includeHiddenWindowsInCmdTab
    @Default(.showWindowlessAppsInCmdTab) var showWindowlessAppsInCmdTab
    @Default(.ignoreAppsWithSingleWindowInCmdTab) var ignoreAppsWithSingleWindowInCmdTab

    var body: some View {
        BaseSettingsView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection

                if enableCmdTabEnhancements {
                    configurationSection
                    windowDisplaySection

                    SettingsMockPreview(context: .cmdTab)

                    appearanceSection
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        SettingsGroup {
            SettingsIllustratedToggle(
                isOn: $enableCmdTabEnhancements,
                title: "Enable Cmd+Tab Enhancements",
                imageName: "CmdTab"
            ) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show previews while holding Cmd+Tab.")
                    Text("Cmd+\(KeyboardLabel.localizedKey(for: cmdTabCycleKey)) cycles forward, Cmd+\(KeyboardLabel.localizedKey(for: cmdTabBackwardCycleKey)) or Shift+Tab cycles backward, Left/Right navigate, Down clears selection.")
                }
            }
            .settingsSearchTarget("cmdTab.enable")
            .onChange(of: enableCmdTabEnhancements) { _ in askUserToRestartApplication() }
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        SettingsGroup(header: "Appearance") {
            CmdTabAppearanceSection()
        }
    }

    // MARK: - Configuration

    private var configurationSection: some View {
        SettingsGroup(header: "Configuration") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("Preview cycle key:")
                    HStack(spacing: 4) {
                        Text("⌘")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        KeyCaptureButton(keyCode: $cmdTabCycleKey)
                    }
                }
                .settingsSearchTarget("cmdTab.cycleKey")

                HStack(spacing: 8) {
                    Text("Backward cycle key:")
                    HStack(spacing: 4) {
                        Text("⌘")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        KeyCaptureButton(keyCode: $cmdTabBackwardCycleKey)
                    }
                }
                .settingsSearchTarget("cmdTab.backwardKey")

                Toggle(isOn: $cmdTabAutoSelectFirstWindow) { Text("Automatically select first window") }
                    .settingsSearchTarget("cmdTab.autoSelect")
                Text("When Cmd+Tab opens, highlight the first window preview automatically.")
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
                SharedWindowDisplayRows(
                    currentSpaceOnly: $showWindowsFromCurrentSpaceOnlyInCmdTab,
                    currentSpaceOnlyTarget: "cmdTab.currentSpaceOnly",
                    monitorCaption: "Only display windows that are on the same display as the mouse cursor.",
                    currentMonitorOnly: $showWindowsFromCurrentMonitorOnlyInCmdTab,
                    currentMonitorOnlyTarget: "cmdTab.currentMonitorOnly",
                    includeHidden: $includeHiddenWindowsInCmdTab,
                    includeHiddenTarget: "cmdTab.includeHidden",
                    showWindowless: $showWindowlessAppsInCmdTab,
                    showWindowlessTarget: "cmdTab.showWindowless",
                    windowlessTitle: "Show preview for apps with no open windows",
                    windowlessCaption: "Show a placeholder preview when Cmd+Tab lands on an app that has no windows.",
                    ignoreSingleWindow: $ignoreAppsWithSingleWindowInCmdTab,
                    ignoreSingleWindowTarget: "cmdTab.ignoreSingleWindow",
                    ignoreSingleWindowCaption: "Prevents apps with a single window from appearing in Cmd+Tab previews."
                )

                Picker("Window sort order", selection: $cmdTabSortOrder) {
                    ForEach(WindowPreviewSortOrder.allCases.filter { !$0.isWindowSwitcherOnly }) { order in
                        Text(order.localizedName).tag(order)
                    }
                }
                .pickerStyle(.menu)
                .settingsSearchTarget("cmdTab.sortOrder")
            }
        }
    }
}
