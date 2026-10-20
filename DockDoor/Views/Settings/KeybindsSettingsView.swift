import Defaults
import SwiftUI

struct KeybindsSettingsView: View {
    var body: some View {
        BaseSettingsView {
            VStack(alignment: .leading, spacing: 16) {
                MouseActionsSection()
                CmdKeyShortcutsSection()
                WindowSwitcherKeybindSection()
            }
        }
    }
}
