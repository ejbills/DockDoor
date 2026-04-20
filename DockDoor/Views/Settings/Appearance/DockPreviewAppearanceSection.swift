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
    @Default(.showMassActionButtons) var showMassActionButtons
    @Default(.useEmbeddedDockPreviewElements) var useEmbeddedDockPreviewElements
    @Default(.previewMaxColumns) var previewMaxColumns
    @Default(.previewMaxRows) var previewMaxRows
    @Default(.windowTitleFontSize) var windowTitleFontSize

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // App Header section
            Toggle(isOn: $showAppName) {
                Text("Show App Header")
            }
            .settingsSearchTarget("appearance.dockShowAppHeader")

            if showAppName {
                Picker(String(localized: "App Header Style"), selection: $appNameStyle) {
                    ForEach(AppNameStyle.allCases, id: \.self) { style in
                        Text(style.localizedName)
                            .tag(style)
                    }
                }
                .settingsSearchTarget("appearance.dockAppHeaderStyle")

                Toggle(isOn: $showAppIconOnly) {
                    Text("Show App Icon Only")
                }
                .settingsSearchTarget("appearance.dockShowAppIconOnly")
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
            .settingsSearchTarget("appearance.dockControlPosition")

            Toggle(isOn: $showWindowTitle) {
                Text("Show Window Title")
            }
            .settingsSearchTarget("appearance.dockShowWindowTitle")

            if showWindowTitle {
                Picker("Window Title Visibility", selection: $windowTitleVisibility) {
                    ForEach(WindowTitleVisibility.allCases, id: \.self) { visibility in
                        Text(visibility.localizedName)
                            .tag(visibility)
                    }
                }
                .settingsSearchTarget("appearance.dockWindowTitleVisibility")

                VStack(alignment: .leading) {
                    Toggle(isOn: $disableDockStyleTitles) {
                        Text("Disable dock styling on window titles")
                    }
                    .settingsSearchTarget("appearance.dockDisableTitleStyling")
                    Text("Removes the pill-shaped background styling from window titles in dock previews for a cleaner look.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .padding(.leading, 20)
                }

                Picker("Window Title Font Size", selection: $windowTitleFontSize) {
                    ForEach(WindowTitleFontSize.allCases) { size in
                        Text(size.localizedName)
                            .tag(size)
                    }
                }
                .settingsSearchTarget("appearance.dockWindowTitleFontSize")
            }

            Divider().padding(.vertical, 2)
            Text("Traffic Light Buttons in Previews").font(.headline).padding(.bottom, -2)
            AppearanceSettingsView.TrafficLightButtonsSettingsView()

            VStack(alignment: .leading) {
                Toggle(isOn: $disableDockStyleTrafficLights) {
                    Text("Disable dock styling on traffic light buttons")
                }
                .settingsSearchTarget("appearance.dockDisableTrafficLightStyling")
                Text("Removes the pill-shaped background styling from traffic light buttons in dock previews for a cleaner look.")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .padding(.leading, 20)
            }

            Divider().padding(.vertical, 2)
            Text("Mass Action Buttons").font(.headline).padding(.bottom, -2)

            VStack(alignment: .leading) {
                Toggle(isOn: $showMassActionButtons) {
                    Text("Show Close All and Minimize All buttons")
                }
                .settingsSearchTarget("appearance.dockMassActionButtons")
                Text("Displays Close All and Minimize All buttons when hovering the app icon in dock previews.")
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
                .settingsSearchTarget("appearance.dockEmbedControls")
                Text("Places traffic light buttons and window titles directly inside the dock preview frames for a more compact and minimal appearance.")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .padding(.leading, 20)
            }

            VStack(alignment: .leading, spacing: 4) {
                let previewMaxRowsBinding = Binding<Double>(
                    get: { Double(previewMaxRows) },
                    set: { previewMaxRows = Int($0) }
                )
                sliderSetting(
                    title: "Max Rows (Bottom Dock)",
                    value: previewMaxRowsBinding,
                    range: 1.0 ... 8.0,
                    step: 1.0,
                    unit: "",
                    formatter: {
                        let f = NumberFormatter()
                        f.minimumFractionDigits = 0
                        f.maximumFractionDigits = 0
                        return f
                    }()
                )
                .settingsSearchTarget("appearance.dockMaxRows")

                let previewMaxColumnsBinding = Binding<Double>(
                    get: { Double(previewMaxColumns) },
                    set: { previewMaxColumns = Int($0) }
                )
                sliderSetting(
                    title: "Max Columns (Left/Right Dock)",
                    value: previewMaxColumnsBinding,
                    range: 1.0 ... 8.0,
                    step: 1.0,
                    unit: "",
                    formatter: {
                        let f = NumberFormatter()
                        f.minimumFractionDigits = 0
                        f.maximumFractionDigits = 0
                        return f
                    }()
                )
                .settingsSearchTarget("appearance.dockMaxColumns")

                Text(String(localized: "Controls how many rows/columns of windows are shown in dock previews. Only the relevant setting applies based on dock position."))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
