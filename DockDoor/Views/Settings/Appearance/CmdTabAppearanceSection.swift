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
        SettingsSection("Appearance") {
            Picker("App Header Style", selection: AppHeaderMode.binding(showName: $cmdTabShowAppName, showIconOnly: $cmdTabShowAppIconOnly, style: $cmdTabAppNameStyle)) {
                ForEach(AppHeaderMode.allCases) { mode in
                    Text(mode.localizedName).tag(mode)
                }
            }
            .settingsSearchTarget("appearance.cmdTabAppHeader")

            Picker("Position Window Controls", selection: $cmdTabControlPosition) {
                ForEach(WindowSwitcherControlPosition.allCases, id: \.self) { position in
                    Text(position.localizedName)
                        .tag(position)
                }
            }
            .settingsSearchTarget("appearance.cmdTabControlPosition")

            Picker("Window Title", selection: WindowTitleMode.binding(showTitle: $cmdTabShowWindowTitle, visibility: $cmdTabWindowTitleVisibility)) {
                ForEach(WindowTitleMode.allCases) { mode in
                    Text(mode.localizedName).tag(mode)
                }
            }
            .settingsSearchTarget("appearance.cmdTabWindowTitle")

            Toggle(isOn: $cmdTabDisableDockStyleTitles) {
                Text("Disable dock styling on window titles")
            }
            .settingsSearchTarget("appearance.cmdTabDisableTitleStyling")
            .settingsAnnotation("Removes the pill-shaped background styling from window titles.")

            Toggle(isOn: $cmdTabUseEmbeddedDockPreviewElements) {
                Text("Embed controls in preview frames")
            }
            .settingsSearchTarget("appearance.cmdTabEmbedControls")
            .settingsAnnotation("Places traffic light buttons and window titles directly inside the preview frames.")
        }

        SettingsSection("Traffic Light Buttons") {
            Picker("Visibility", selection: $cmdTabTrafficLightButtonsVisibility) {
                ForEach(TrafficLightButtonsVisibility.allCases, id: \.self) { visibility in
                    Text(visibility.localizedName)
                        .tag(visibility)
                }
            }
            .settingsSearchTarget("appearance.cmdTabTrafficLightVisibility")

            if cmdTabTrafficLightButtonsVisibility != .never {
                EnabledButtonsPicker(enabledButtons: $cmdTabEnabledTrafficLightButtons) {
                    cmdTabTrafficLightButtonsVisibility = .never
                }
                Toggle("Use Monochrome Colors", isOn: $cmdTabUseMonochromeTrafficLights)
                    .settingsSearchTarget("appearance.cmdTabMonochrome")

                Toggle(isOn: $cmdTabDisableDockStyleTrafficLights) {
                    Text("Disable dock styling on traffic light buttons")
                }
                .settingsSearchTarget("appearance.cmdTabDisableTrafficLightStyling")
                .settingsAnnotation("Removes the pill-shaped background styling from traffic light buttons.")
            }
        }
    }
}
