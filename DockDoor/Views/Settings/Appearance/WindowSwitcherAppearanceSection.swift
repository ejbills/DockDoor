import Defaults
import SwiftUI

struct WindowSwitcherAppearanceSection: View {
    @Default(.windowSwitcherControlPosition) var windowSwitcherControlPosition
    @Default(.switcherShowAppHeader) var switcherShowAppHeader
    @Default(.switcherShowWindowTitle) var switcherShowWindowTitle
    @Default(.switcherWindowTitleVisibility) var switcherWindowTitleVisibility
    @Default(.switcherAppIconSize) var switcherAppIconSize
    @Default(.switcherTrafficLightButtonsVisibility) var switcherTrafficLightButtonsVisibility
    @Default(.switcherEnabledTrafficLightButtons) var switcherEnabledTrafficLightButtons
    @Default(.switcherUseMonochromeTrafficLights) var switcherUseMonochromeTrafficLights
    @Default(.switcherUseEmbeddedDockPreviewElements) var switcherUseEmbeddedDockPreviewElements
    @Default(.switcherDisableDockStyleTrafficLights) var switcherDisableDockStyleTrafficLights
    @Default(.switcherMaxRows) var switcherMaxRows
    @Default(.switcherIgnoreScreenLimit) var switcherIgnoreScreenLimit
    @Default(.windowSwitcherScrollDirection) var windowSwitcherScrollDirection

    private var automaticAppIconSizeBinding: Binding<Bool> {
        Binding(
            get: { switcherAppIconSize == 0 },
            set: { useAutomaticSize in
                switcherAppIconSize = useAutomaticSize ? 0 : 35
            }
        )
    }

    private var customAppIconSizeBinding: Binding<CGFloat> {
        Binding(
            get: { switcherAppIconSize > 0 ? switcherAppIconSize : 35 },
            set: { switcherAppIconSize = $0 }
        )
    }

    var body: some View {
        SettingsSection("Appearance") {
            Toggle("Show app header", isOn: $switcherShowAppHeader)
                .settingsSearchTarget("appearance.switcherShowAppHeader")

            if switcherShowAppHeader {
                Toggle("Automatic app icon size", isOn: automaticAppIconSizeBinding)
                    .settingsSearchTarget("appearance.switcherAppIconSize")

                if switcherAppIconSize > 0 {
                    SettingsSliderRow(
                        title: "App icon size",
                        value: customAppIconSizeBinding,
                        range: 16 ... 64,
                        defaultValue: 35,
                        unit: " pt",
                        step: 1
                    )
                }
            }

            if switcherShowAppHeader {
                Picker("Window title", selection: WindowTitleMode.binding(showTitle: $switcherShowWindowTitle, visibility: $switcherWindowTitleVisibility)) {
                    ForEach(WindowTitleMode.allCases) { mode in
                        Text(mode.localizedName).tag(mode)
                    }
                }
                .settingsSearchTarget("appearance.switcherWindowTitle")
            }

            Picker("Controls position", selection: $windowSwitcherControlPosition) {
                ForEach(WindowSwitcherControlPosition.allCases, id: \.self) { position in
                    Text(position.localizedName)
                        .tag(position)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .settingsSearchTarget("appearance.switcherControlPosition")
        }

        SettingsSection("Traffic light buttons") {
            Picker("Visibility", selection: $switcherTrafficLightButtonsVisibility) {
                ForEach(TrafficLightButtonsVisibility.allCases, id: \.self) { visibility in
                    Text(visibility.localizedName)
                        .tag(visibility)
                }
            }
            .settingsSearchTarget("appearance.switcherTrafficLightVisibility")

            if switcherTrafficLightButtonsVisibility != .never {
                EnabledButtonsPicker(enabledButtons: $switcherEnabledTrafficLightButtons) {
                    switcherTrafficLightButtonsVisibility = .never
                }
                Toggle("Use monochrome colors", isOn: $switcherUseMonochromeTrafficLights)
                    .settingsSearchTarget("appearance.switcherMonochrome")

                Toggle(isOn: $switcherDisableDockStyleTrafficLights) {
                    Text("Disable dock styling on traffic light buttons")
                }
                .settingsSearchTarget("appearance.switcherDisableTrafficLightStyling")
                .settingsAnnotation("Removes the pill-shaped background styling from traffic light buttons.")
            }
        }

        SettingsSection("Layout") {
            Toggle(isOn: $switcherUseEmbeddedDockPreviewElements) {
                Text("Embed controls in preview frames")
            }
            .settingsSearchTarget("appearance.switcherEmbedControls")
            .settingsAnnotation("Places traffic light buttons and window titles directly inside the window switcher preview frames.")

            Picker("Scroll direction", selection: $windowSwitcherScrollDirection) {
                ForEach(WindowSwitcherScrollDirection.allCases, id: \.self) { direction in
                    Text(direction.localizedName).tag(direction)
                }
            }
            .settingsSearchTarget("appearance.switcherScrollDirection")

            let switcherMaxRowsBinding = Binding<Double>(
                get: { Double(switcherMaxRows) },
                set: { switcherMaxRows = Int($0) }
            )
            SettingsSliderRow(
                title: windowSwitcherScrollDirection == .horizontal
                    ? "Max Rows"
                    : "Max Columns",
                value: switcherMaxRowsBinding,
                range: 1 ... 8,
                step: 1
            )
            .settingsSearchTarget("appearance.switcherMaxRows")
            .settingsAnnotation(windowSwitcherScrollDirection == .horizontal
                ? "Controls how many rows of windows are shown in the window switcher. Windows are distributed across rows automatically."
                : "Controls how many columns of windows are shown in the window switcher. Windows are distributed across columns automatically.")

            Toggle(isOn: $switcherIgnoreScreenLimit) {
                Text("Ignore screen size limit")
            }
            .settingsSearchTarget("appearance.switcherIgnoreScreenLimit")
            .settingsAnnotation("Allow columns/rows to exceed what fits on screen. May cause previews to extend beyond screen edges.")
        }
    }
}
