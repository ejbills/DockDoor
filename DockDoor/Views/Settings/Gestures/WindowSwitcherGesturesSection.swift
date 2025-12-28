import Defaults
import SwiftUI

struct WindowSwitcherGesturesSection: View {
    @Default(.enableWindowSwitcherGestures) var enableWindowSwitcherGestures
    @Default(.switcherSwipeUpAction) var switcherSwipeUpAction
    @Default(.switcherSwipeDownAction) var switcherSwipeDownAction

    var body: some View {
        SettingsGroup(header: "Window Switcher Gestures") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $enableWindowSwitcherGestures) {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.3.group")
                            .foregroundColor(.accentColor)
                        Text("Enable gestures in window switcher")
                    }
                }

                if enableWindowSwitcherGestures {
                    Text("Swipe up or down on window previews in the keyboard-activated window switcher. Only vertical swipes are recognized, unless in compact mode.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)

                    Divider()

                    GestureDirectionRow(
                        direction: "Swipe Up",
                        icon: "arrow.up",
                        description: nil,
                        action: $switcherSwipeUpAction
                    )

                    GestureDirectionRow(
                        direction: "Swipe Down",
                        icon: "arrow.down",
                        description: nil,
                        action: $switcherSwipeDownAction
                    )

                    Button("Reset to Defaults") {
                        switcherSwipeUpAction = Defaults.Keys.switcherSwipeUpAction.defaultValue
                        switcherSwipeDownAction = Defaults.Keys.switcherSwipeDownAction.defaultValue
                    }
                    .buttonStyle(AccentButtonStyle(small: true))
                    .padding(.top, 4)
                }
            }
        }
    }
}
