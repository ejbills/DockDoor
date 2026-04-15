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

                HStack(spacing: 8) {
                    Text("Backward cycle key:")
                    HStack(spacing: 4) {
                        Text("⌘")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        KeyCaptureButton(keyCode: $cmdTabBackwardCycleKey)
                    }
                }

                Toggle(isOn: $cmdTabAutoSelectFirstWindow) { Text("Automatically select first window") }
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
                Toggle(isOn: $showWindowsFromCurrentSpaceOnlyInCmdTab) { Text("Show windows from current Space only") }
                Text("Only display windows that are in the current virtual desktop/Space.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                Toggle(isOn: $showWindowsFromCurrentMonitorOnlyInCmdTab) { Text("Show windows from current monitor only") }
                Text("Only display windows that are on the same display as the mouse cursor.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                Toggle(isOn: $includeHiddenWindowsInCmdTab) { Text("Include hidden/minimized windows") }

                Toggle(isOn: $showWindowlessAppsInCmdTab) { Text("Show preview for apps with no open windows") }
                Text("Show a placeholder preview when Cmd+Tab lands on an app that has no windows.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                Picker("Window sort order", selection: $cmdTabSortOrder) {
                    ForEach(WindowPreviewSortOrder.allCases.filter { !$0.isWindowSwitcherOnly }) { order in
                        Text(order.localizedName).tag(order)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }
}
