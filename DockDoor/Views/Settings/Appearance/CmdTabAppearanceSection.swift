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
            Picker("App header", selection: AppHeaderMode.binding(showName: $cmdTabShowAppName, showIconOnly: $cmdTabShowAppIconOnly, style: $cmdTabAppNameStyle)) {
                ForEach(AppHeaderMode.allCases) { mode in
                    Text(mode.localizedName).tag(mode)
                }
            }
            .settingsSearchTarget("appearance.cmdTabAppHeader")

            Picker("Controls position", selection: $cmdTabControlPosition) {
                ForEach(WindowSwitcherControlPosition.allCases, id: \.self) { position in
                    Text(position.localizedName)
                        .tag(position)
                }
            }
            .settingsSearchTarget("appearance.cmdTabControlPosition")

            Picker("Window title", selection: WindowTitleMode.binding(showTitle: $cmdTabShowWindowTitle, visibility: $cmdTabWindowTitleVisibility)) {
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

        SettingsSection("Traffic light buttons") {
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
                Toggle("Use monochrome colors", isOn: $cmdTabUseMonochromeTrafficLights)
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
