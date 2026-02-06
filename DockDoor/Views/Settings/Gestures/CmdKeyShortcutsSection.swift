import Defaults
import SwiftUI

struct CmdKeyShortcutsSection: View {
    @Default(.cmdShortcut1Key) var cmdShortcut1Key
    @Default(.cmdShortcut1Action) var cmdShortcut1Action
    @Default(.cmdShortcut2Key) var cmdShortcut2Key
    @Default(.cmdShortcut2Action) var cmdShortcut2Action
    @Default(.cmdShortcut3Key) var cmdShortcut3Key
    @Default(.cmdShortcut3Action) var cmdShortcut3Action

    var body: some View {
        SettingsGroup(header: "Window Preview Keyboard Shortcuts") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Cmd+key shortcuts for quick actions on the selected window preview. These work in both the window switcher and Cmd+Tab enhancement mode.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Divider()

                cmdShortcutRow(
                    slot: 1,
                    keyBinding: $cmdShortcut1Key,
                    actionBinding: $cmdShortcut1Action
                )

                cmdShortcutRow(
                    slot: 2,
                    keyBinding: $cmdShortcut2Key,
                    actionBinding: $cmdShortcut2Action
                )

                cmdShortcutRow(
                    slot: 3,
                    keyBinding: $cmdShortcut3Key,
                    actionBinding: $cmdShortcut3Action
                )

                Button("Reset to Defaults") {
                    cmdShortcut1Key = Defaults.Keys.cmdShortcut1Key.defaultValue
                    cmdShortcut1Action = Defaults.Keys.cmdShortcut1Action.defaultValue
                    cmdShortcut2Key = Defaults.Keys.cmdShortcut2Key.defaultValue
                    cmdShortcut2Action = Defaults.Keys.cmdShortcut2Action.defaultValue
                    cmdShortcut3Key = Defaults.Keys.cmdShortcut3Key.defaultValue
                    cmdShortcut3Action = Defaults.Keys.cmdShortcut3Action.defaultValue
                }
                .buttonStyle(AccentButtonStyle(small: true))
                .padding(.top, 4)
            }
        }
    }

    private func cmdShortcutRow(slot: Int, keyBinding: Binding<UInt16>, actionBinding: Binding<WindowAction>) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Text("⌘")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                KeyCaptureButton(keyCode: keyBinding)
            }
            .frame(minWidth: 80, alignment: .leading)

            Picker("", selection: actionBinding) {
                ForEach(WindowAction.gestureActions, id: \.self) { windowAction in
                    HStack(spacing: 6) {
                        Image(systemName: windowAction.iconName)
                        Text(windowAction.localizedName)
                    }
                    .tag(windowAction)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
    }
}
