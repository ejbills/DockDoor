import Defaults
import SwiftUI

struct DockPreviewAppearanceSection: View {
    @Default(.showAppName) var showAppName
    @Default(.appNameStyle) var appNameStyle
    @Default(.showAppIconOnly) var showAppIconOnly
    @Default(.dockPreviewControlPosition) var dockPreviewControlPosition
    @Default(.showWindowTitle) var showWindowTitle
    @Default(.windowTitleVisibility) var windowTitleVisibility
    @Default(.disableDockStyleTitles) var disableDockStyleTitles
    @Default(.disableDockStyleTrafficLights) var disableDockStyleTrafficLights
    @Default(.useEmbeddedDockPreviewElements) var useEmbeddedDockPreviewElements
    @Default(.dockPreviewMaxItemsPerLine) var dockPreviewMaxItemsPerLine

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // App Header section
            Toggle(isOn: $showAppName) {
                Text("Show App Header")
            }

            if showAppName {
                Picker(String(localized: "App Header Style"), selection: $appNameStyle) {
                    ForEach(AppNameStyle.allCases, id: \.self) { style in
                        Text(style.localizedName)
                            .tag(style)
                    }
                }

                Toggle(isOn: $showAppIconOnly) {
                    Text("Show App Icon Only")
                }
            }

            Divider().padding(.vertical, 2)
            Text("Dock Preview Toolbar").font(.headline).padding(.bottom, -2)

            Picker("Position Dock Preview Controls", selection: $dockPreviewControlPosition) {
                ForEach(WindowSwitcherControlPosition.allCases, id: \.self) { position in
                    Text(position.localizedName)
                        .tag(position)
                }
            }
            .pickerStyle(MenuPickerStyle())

            Toggle(isOn: $showWindowTitle) {
                Text("Show Window Title")
            }

            if showWindowTitle {
                Picker("Window Title Visibility", selection: $windowTitleVisibility) {
                    ForEach(WindowTitleVisibility.allCases, id: \.self) { visibility in
                        Text(visibility.localizedName)
                            .tag(visibility)
                    }
                }

                VStack(alignment: .leading) {
                    Toggle(isOn: $disableDockStyleTitles) {
                        Text("Disable dock styling on window titles")
                    }
                    Text("Removes the pill-shaped background styling from window titles in dock previews for a cleaner look.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .padding(.leading, 20)
                }
            }

            Divider().padding(.vertical, 2)
            Text("Traffic Light Buttons in Previews").font(.headline).padding(.bottom, -2)
            AppearanceSettingsView.TrafficLightButtonsSettingsView()

            VStack(alignment: .leading) {
                Toggle(isOn: $disableDockStyleTrafficLights) {
                    Text("Disable dock styling on traffic light buttons")
                }
                Text("Removes the pill-shaped background styling from traffic light buttons in dock previews for a cleaner look.")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .padding(.leading, 20)
            }

            Divider().padding(.vertical, 2)
            Text("Dock Preview Layout").font(.headline).padding(.bottom, -2)

            VStack(alignment: .leading) {
                Toggle(isOn: $useEmbeddedDockPreviewElements) {
                    Text("Embed controls in preview frames")
                }
                Text("Places traffic light buttons and window titles directly inside the dock preview frames for a more compact and minimal appearance.")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .padding(.leading, 20)
            }

            VStack(alignment: .leading, spacing: 4) {
                let maxItemsBinding = Binding<Double>(
                    get: { Double(dockPreviewMaxItemsPerLine) },
                    set: { dockPreviewMaxItemsPerLine = Int($0) }
                )
                sliderSetting(
                    title: "Max Items Per Line",
                    value: maxItemsBinding,
                    range: 0.0 ... 8.0,
                    step: 1.0,
                    unit: "",
                    formatter: {
                        let f = NumberFormatter()
                        f.minimumFractionDigits = 0
                        f.maximumFractionDigits = 0
                        return f
                    }()
                )

                Text(dockPreviewMaxItemsPerLine == 0
                    ? String(localized: "Auto: items per line determined by available screen space.")
                    : String(localized: "Limits the number of window previews per line in dock previews."))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
