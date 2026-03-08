import Defaults
import SwiftUI

struct DockScrollGestureSection: View {
    @Default(.enableDockScrollGesture) var enableDockScrollGesture
    @Default(.dockIconMediaScrollBehavior) var dockIconMediaScrollBehavior

    var body: some View {
        SettingsGroup(header: "Dock Icon Scroll Gesture") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $enableDockScrollGesture) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.arrow.down")
                            .foregroundColor(.accentColor)
                        Text("Enable scroll gestures on dock icons")
                    }
                }

                if enableDockScrollGesture {
                    Text("Scroll up on a dock icon to bring the app to front, scroll down to hide all its windows.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)

                    Divider()

                    Picker("Music/Spotify behavior:", selection: $dockIconMediaScrollBehavior) {
                        ForEach(DockIconMediaScrollBehavior.allCases, id: \.self) { behavior in
                            Text(behavior.localizedName).tag(behavior)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
    }
}

struct TitleBarScrollGestureSection: View {
    @Default(.enableTitleBarScrollGesture) var enableTitleBarScrollGesture

    var body: some View {
        SettingsGroup(header: "Title Bar Scroll Gesture") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $enableTitleBarScrollGesture) {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.tophalf.inset.filled")
                            .foregroundColor(.accentColor)
                        Text("Enable scroll gestures on active window title bars")
                    }
                }

                if enableTitleBarScrollGesture {
                    Text("Scroll up on a focused window title bar to maximize it, scroll down to center it at 80% size, and scroll left or right to switch desktop spaces.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
