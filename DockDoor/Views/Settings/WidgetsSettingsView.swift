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
                    }
                }

                TabView {
                    MyWidgetsView()
                        .tabItem { Text("My Widgets") }
                    DiscoverView()
                        .tabItem { Text("Discover") }
                }
                .tabViewStyle(.automatic)
            }
        }
    }
}
