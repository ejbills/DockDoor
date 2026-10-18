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
        SettingsFormView {
            headerSection

            if enableCmdTabEnhancements {
                appearanceSection
                configurationSection
                windowDisplaySection
            }
        } pinnedHeader: {
            if enableCmdTabEnhancements {
                SettingsMockPreview(context: .cmdTab, maxHeight: 170)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        SettingsSection("Cmd+Tab enhancements") {
            Toggle(isOn: $enableCmdTabEnhancements) { Text("Enable Cmd+Tab Enhancements") }
                .settingsSearchTarget("cmdTab.enable")
                .settingsAnnotation(
                    "Show previews while holding Cmd+Tab.",
                    more: "Cmd+\(KeyboardLabel.localizedKey(for: cmdTabCycleKey)) cycles forward, Cmd+\(KeyboardLabel.localizedKey(for: cmdTabBackwardCycleKey)) or Shift+Tab cycles backward, Left/Right navigate, Down clears selection."
                )
                .onChange(of: enableCmdTabEnhancements) { _ in askUserToRestartApplication() }
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        CmdTabAppearanceSection()
    }

    // MARK: - Configuration

    private var configurationSection: some View {
        SettingsSection("Configuration") {
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
                .settingsAnnotation("When Cmd+Tab opens, highlight the first window preview automatically.")
        }
    }

    // MARK: - Window Display

    private var windowDisplaySection: some View {
        SettingsSection("Window display") {
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
            .settingsSearchTarget("cmdTab.sortOrder")
        }
    }
}
