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
        Section {
            cmdShortcutRow(keyBinding: $cmdShortcut1Key, actionBinding: $cmdShortcut1Action)
                .settingsSearchTarget("gestures.cmdShortcuts")
            cmdShortcutRow(keyBinding: $cmdShortcut2Key, actionBinding: $cmdShortcut2Action)
            cmdShortcutRow(keyBinding: $cmdShortcut3Key, actionBinding: $cmdShortcut3Action)

            HStack {
                Spacer()
                Button("Reset to Defaults") {
                    cmdShortcut1Key = Defaults.Keys.cmdShortcut1Key.defaultValue
                    cmdShortcut1Action = Defaults.Keys.cmdShortcut1Action.defaultValue
                    cmdShortcut2Key = Defaults.Keys.cmdShortcut2Key.defaultValue
                    cmdShortcut2Action = Defaults.Keys.cmdShortcut2Action.defaultValue
                    cmdShortcut3Key = Defaults.Keys.cmdShortcut3Key.defaultValue
                    cmdShortcut3Action = Defaults.Keys.cmdShortcut3Action.defaultValue
                }
                .buttonStyle(.settings)
            }
        } header: {
            Text("Window preview keyboard shortcuts")
        } footer: {
            Text("Cmd+key shortcuts for quick actions on the selected window preview. These work in both the window switcher and Cmd+Tab enhancement mode.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func cmdShortcutRow(keyBinding: Binding<UInt16>, actionBinding: Binding<WindowAction>) -> some View {
        LabeledContent {
            Picker("Action", selection: actionBinding) {
                ForEach(WindowAction.gestureActions, id: \.self) { windowAction in
                    Label(windowAction.localizedName, systemImage: windowAction.iconName)
                        .tag(windowAction)
                }
            }
            .labelsHidden()
            .fixedSize()
        } label: {
            HStack(spacing: 4) {
                Text(verbatim: "⌘")
                    .foregroundStyle(.secondary)
                KeyCaptureButton(keyCode: keyBinding)
            }
        }
    }
}
