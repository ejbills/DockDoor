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
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Show App Header", isOn: $switcherShowAppHeader)
                .settingsSearchTarget("appearance.switcherShowAppHeader")

            if switcherShowAppHeader {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("App Icon Size")
                        Spacer()
                        Toggle("Automatic", isOn: automaticAppIconSizeBinding)
                    }

                    if switcherAppIconSize > 0 {
                        sliderSetting(
                            title: "Size",
                            value: customAppIconSizeBinding,
                            range: 16.0 ... 64.0,
                            step: 1.0,
                            unit: "pt",
                            formatter: {
                                let f = NumberFormatter()
                                f.minimumFractionDigits = 0
                                f.maximumFractionDigits = 0
                                return f
                            }()
                        )
                    }
                }
                .settingsSearchTarget("appearance.switcherAppIconSize")
            }

            Divider().padding(.vertical, 2)
            Text("Window Switcher Toolbar").font(.headline).padding(.bottom, -2)

            Picker("Position Window Controls", selection: $windowSwitcherControlPosition) {
                ForEach(WindowSwitcherControlPosition.allCases, id: \.self) { position in
                    Text(position.localizedName)
                        .tag(position)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .settingsSearchTarget("appearance.switcherControlPosition")

            Divider().padding(.vertical, 2)
            Text("Traffic Light Buttons").font(.headline).padding(.bottom, -2)

            Picker("Visibility", selection: $switcherTrafficLightButtonsVisibility) {
                ForEach(TrafficLightButtonsVisibility.allCases, id: \.self) { visibility in
                    Text(visibility.localizedName)
                        .tag(visibility)
                }
            }
            .settingsSearchTarget("appearance.switcherTrafficLightVisibility")

            if switcherTrafficLightButtonsVisibility != .never {
                Text("Enabled Buttons")
                VStack(alignment: .leading) {
                    if !switcherEnabledTrafficLightButtons.isEmpty {
                        TrafficLightButtons(
                            displayMode: switcherTrafficLightButtonsVisibility,
                            hoveringOverParentWindow: true,
                            onWindowAction: { _ in },
                            pillStyling: !switcherDisableDockStyleTrafficLights,
                            mockPreviewActive: false,
                            enabledButtons: switcherEnabledTrafficLightButtons,
                            useMonochrome: switcherUseMonochromeTrafficLights,
                            backgroundAppearance: .resolve()
                        )
                    }
                    EnabledButtonsCheckboxes(
                        enabledButtons: $switcherEnabledTrafficLightButtons,
                        visibilityBinding: $switcherTrafficLightButtonsVisibility,
                        useMonochrome: switcherUseMonochromeTrafficLights
                    )
                }
                Toggle("Use Monochrome Colors", isOn: $switcherUseMonochromeTrafficLights)
                    .settingsSearchTarget("appearance.switcherMonochrome")

                VStack(alignment: .leading) {
                    Toggle(isOn: $switcherDisableDockStyleTrafficLights) {
                        Text("Disable dock styling on traffic light buttons")
                    }
                    .settingsSearchTarget("appearance.switcherDisableTrafficLightStyling")
                    Text("Removes the pill-shaped background styling from traffic light buttons.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
            }

            Group {
                Divider().padding(.vertical, 2)
                Text("Window Title").font(.headline).padding(.bottom, -2)

                Toggle("Show Window Title", isOn: $switcherShowWindowTitle)
                    .settingsSearchTarget("appearance.switcherShowWindowTitle")

                if switcherShowWindowTitle {
                    Picker("Visibility", selection: $switcherWindowTitleVisibility) {
                        ForEach(WindowTitleVisibility.allCases, id: \.self) { visibility in
                            Text(visibility.localizedName)
                                .tag(visibility)
                        }
                    }
                    .settingsSearchTarget("appearance.switcherWindowTitleVisibility")
                }
            }
            .disabled(!switcherShowAppHeader)

            Divider().padding(.vertical, 2)
            Text("Preview Layout (Switcher)").font(.headline).padding(.bottom, -2)

            VStack(alignment: .leading) {
                Toggle(isOn: $switcherUseEmbeddedDockPreviewElements) {
                    Text("Embed controls in preview frames")
                }
                .settingsSearchTarget("appearance.switcherEmbedControls")
                Text("Places traffic light buttons and window titles directly inside the window switcher preview frames.")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .padding(.leading, 20)
            }

            Picker("Scroll Direction", selection: $windowSwitcherScrollDirection) {
                ForEach(WindowSwitcherScrollDirection.allCases, id: \.self) { direction in
                    Text(direction.localizedName).tag(direction)
                }
            }
            .settingsSearchTarget("appearance.switcherScrollDirection")

            VStack(alignment: .leading, spacing: 4) {
                let switcherMaxRowsBinding = Binding<Double>(
                    get: { Double(switcherMaxRows) },
                    set: { switcherMaxRows = Int($0) }
                )
                sliderSetting(
                    title: windowSwitcherScrollDirection == .horizontal
                        ? "Max Rows"
                        : "Max Columns",
                    value: switcherMaxRowsBinding,
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
                .settingsSearchTarget("appearance.switcherMaxRows")

                Text(windowSwitcherScrollDirection == .horizontal
                    ? String(localized: "Controls how many rows of windows are shown in the window switcher. Windows are distributed across rows automatically.")
                    : String(localized: "Controls how many columns of windows are shown in the window switcher. Windows are distributed across columns automatically."))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle(isOn: $switcherIgnoreScreenLimit) {
                    Text("Ignore screen size limit")
                }
                .settingsSearchTarget("appearance.switcherIgnoreScreenLimit")
                Text("Allow columns/rows to exceed what fits on screen. May cause previews to extend beyond screen edges.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
