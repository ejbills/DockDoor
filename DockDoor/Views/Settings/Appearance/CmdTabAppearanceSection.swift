import Defaults
import SwiftUI

struct CmdTabAppearanceSection: View {
    @Default(.cmdTabShowAppName) var cmdTabShowAppName
    @Default(.cmdTabAppNameStyle) var cmdTabAppNameStyle
    @Default(.cmdTabShowAppIconOnly) var cmdTabShowAppIconOnly
    @Default(.cmdTabShowWindowTitle) var cmdTabShowWindowTitle
    @Default(.cmdTabWindowTitleVisibility) var cmdTabWindowTitleVisibility
    @Default(.cmdTabDisableDockStyleTitles) var cmdTabDisableDockStyleTitles
    @Default(.cmdTabControlPosition) var cmdTabControlPosition
    @Default(.cmdTabTrafficLightButtonsVisibility) var cmdTabTrafficLightButtonsVisibility
    @Default(.cmdTabEnabledTrafficLightButtons) var cmdTabEnabledTrafficLightButtons
    @Default(.cmdTabUseMonochromeTrafficLights) var cmdTabUseMonochromeTrafficLights
    @Default(.cmdTabDisableDockStyleTrafficLights) var cmdTabDisableDockStyleTrafficLights
    @Default(.cmdTabUseEmbeddedDockPreviewElements) var cmdTabUseEmbeddedDockPreviewElements

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // App Header section
            Toggle("Show App Header", isOn: $cmdTabShowAppName)

            if cmdTabShowAppName {
                Picker("App Header Style", selection: $cmdTabAppNameStyle) {
                    ForEach(AppNameStyle.allCases, id: \.self) { style in
                        Text(style.localizedName)
                            .tag(style)
                    }
                }
                Toggle("Show App Icon Only", isOn: $cmdTabShowAppIconOnly)
            }

            // Toolbar section
            Divider().padding(.vertical, 2)
            Text("Cmd+Tab Toolbar").font(.headline).padding(.bottom, -2)

            Picker("Position Window Controls", selection: $cmdTabControlPosition) {
                ForEach(WindowSwitcherControlPosition.allCases, id: \.self) { position in
                    Text(position.localizedName)
                        .tag(position)
                }
            }
            .pickerStyle(MenuPickerStyle())

            Toggle("Show Window Title", isOn: $cmdTabShowWindowTitle)

            if cmdTabShowWindowTitle {
                Picker("Window Title Visibility", selection: $cmdTabWindowTitleVisibility) {
                    ForEach(WindowTitleVisibility.allCases, id: \.self) { visibility in
                        Text(visibility.localizedName)
                            .tag(visibility)
                    }
                }

                VStack(alignment: .leading) {
                    Toggle(isOn: $cmdTabDisableDockStyleTitles) {
                        Text("Disable dock styling on window titles")
                    }
                    Text("Removes the pill-shaped background styling from window titles.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .padding(.leading, 20)
                }
            }

            // Traffic Light Buttons section
            Divider().padding(.vertical, 2)
            Text("Traffic Light Buttons").font(.headline).padding(.bottom, -2)

            Picker("Visibility", selection: $cmdTabTrafficLightButtonsVisibility) {
                ForEach(TrafficLightButtonsVisibility.allCases, id: \.self) { visibility in
                    Text(visibility.localizedName)
                        .tag(visibility)
                }
            }

            if cmdTabTrafficLightButtonsVisibility != .never {
                Text("Enabled Buttons")
                VStack(alignment: .leading) {
                    if !cmdTabEnabledTrafficLightButtons.isEmpty {
                        TrafficLightButtons(
                            displayMode: cmdTabTrafficLightButtonsVisibility,
                            hoveringOverParentWindow: true,
                            onWindowAction: { _ in },
                            pillStyling: true,
                            mockPreviewActive: false,
                            enabledButtons: cmdTabEnabledTrafficLightButtons,
                            useMonochrome: cmdTabUseMonochromeTrafficLights
                        )
                    }
                    EnabledButtonsCheckboxes(
                        enabledButtons: $cmdTabEnabledTrafficLightButtons,
                        visibilityBinding: $cmdTabTrafficLightButtonsVisibility,
                        useMonochrome: cmdTabUseMonochromeTrafficLights
                    )
                }
                Toggle("Use Monochrome Colors", isOn: $cmdTabUseMonochromeTrafficLights)

                VStack(alignment: .leading) {
                    Toggle(isOn: $cmdTabDisableDockStyleTrafficLights) {
                        Text("Disable dock styling on traffic light buttons")
                    }
                    Text("Removes the pill-shaped background styling from traffic light buttons.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .padding(.leading, 20)
                }
            }

            // Layout section
            Divider().padding(.vertical, 2)
            Text("Cmd+Tab Layout").font(.headline).padding(.bottom, -2)

            VStack(alignment: .leading) {
                Toggle(isOn: $cmdTabUseEmbeddedDockPreviewElements) {
                    Text("Embed controls in preview frames")
                }
                Text("Places traffic light buttons and window titles directly inside the preview frames.")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .padding(.leading, 20)
            }
        }
    }
}
