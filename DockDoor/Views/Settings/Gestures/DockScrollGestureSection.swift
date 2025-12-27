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
