import Defaults
import SwiftUI

struct GesturesAndKeybindsSettingsView: View {
    var body: some View {
        BaseSettingsView {
            VStack(alignment: .leading, spacing: 16) {
                DockScrollGestureSection()
                DockPreviewGesturesSection()
                GestureSettingsSection()
                MouseActionsSection()
                CmdKeyShortcutsSection()
                WindowSwitcherKeybindSection()
            }
        }
    }
}
