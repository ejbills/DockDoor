import Defaults
import SwiftUI

struct KeybindsSettingsView: View {
    var body: some View {
        SettingsFormView {
            MouseActionsSection()
            CmdKeyShortcutsSection()
            WindowSwitcherKeybindSection()
        }
    }
}
