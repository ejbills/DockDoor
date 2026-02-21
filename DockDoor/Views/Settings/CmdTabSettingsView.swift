import Defaults
import SwiftUI

struct CmdTabSettingsView: View {
    @Default(.enableCmdTabEnhancements) var enableCmdTabEnhancements
    @Default(.cmdTabCycleKey) var cmdTabCycleKey
    @Default(.showWindowsFromCurrentSpaceOnlyInCmdTab) var showWindowsFromCurrentSpaceOnlyInCmdTab
    @Default(.cmdTabSortOrder) var cmdTabSortOrder
    @Default(.cmdTabAutoSelectFirstWindow) var cmdTabAutoSelectFirstWindow
    @Default(.includeHiddenWindowsInCmdTab) var includeHiddenWindowsInCmdTab

    var body: some View {
        BaseSettingsView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection

                if enableCmdTabEnhancements {
                    configurationSection
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
                    Text("Cmd+\(KeyboardLabel.localizedKey(for: cmdTabCycleKey)) cycles through previews (Shift to reverse), Left/Right navigate, Down clears selection.")
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

                Toggle(isOn: $showWindowsFromCurrentSpaceOnlyInCmdTab) { Text("Show windows from current Space only") }
                Text("Only display windows that are in the current virtual desktop/Space.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                Toggle(isOn: $cmdTabAutoSelectFirstWindow) { Text("Automatically select first window") }
                Text("When Cmd+Tab opens, highlight the first window preview automatically.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                Toggle(isOn: $includeHiddenWindowsInCmdTab) { Text("Include hidden/minimized windows") }

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
