import Defaults
import SwiftUI

struct WidgetsSettingsView: View {
    @Default(.widgetsEnabled) private var widgetsEnabled

    var body: some View {
        BaseSettingsView {
            VStack(alignment: .leading, spacing: 16) {
                StyledGroupBox(label: "Widgets") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: $widgetsEnabled) { Text("Enable Widgets") }
                        Text("Build, install, and discover widgets.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(spacing: 8) {
                            Menu("Install Defaults…") {
                                Button("All (Calendar, Apple Music, Spotify)") { DefaultWidgets.installAll() }
                                Divider()
                                Button("Calendar") { DefaultWidgets.installCalendar() }
                                Button("Apple Music") { DefaultWidgets.installAppleMusic() }
                                Button("Spotify") { DefaultWidgets.installSpotify() }
                            }
                        }
                    }
                }

                // Lay out both sections without a tab/segmented control
                MyWidgetsView()
                DiscoverView()
            }
        }
    }
}
