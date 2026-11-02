import Defaults
import SwiftUI

struct KeybindsSettingsView: View {
    @Default(.enableWindowSwitcher) var enableWindowSwitcher
    @Default(.enableCmdTabEnhancements) var enableCmdTabEnhancements

    var body: some View {
        SettingsFormView {
            if enableWindowSwitcher {
                WindowSwitcherKeybindSection()
            } else {
                Section {
                    SettingsNote(icon: "info.circle", text: "Turn on the Window Switcher to change its shortcuts.")
                }
            }

            if enableWindowSwitcher || enableCmdTabEnhancements {
                CmdKeyShortcutsSection()
            }
        }
    }
}
