import Defaults
import SwiftUI

struct WindowSwitcherAppearanceSection: View {
    @Default(.windowSwitcherControlPosition) var windowSwitcherControlPosition
    @Default(.switcherShowWindowTitle) var switcherShowWindowTitle
    @Default(.switcherWindowTitleVisibility) var switcherWindowTitleVisibility
    @Default(.switcherTrafficLightButtonsVisibility) var switcherTrafficLightButtonsVisibility
    @Default(.switcherEnabledTrafficLightButtons) var switcherEnabledTrafficLightButtons
    @Default(.switcherUseMonochromeTrafficLights) var switcherUseMonochromeTrafficLights
    @Default(.switcherDisableDockStyleTrafficLights) var switcherDisableDockStyleTrafficLights
    @Default(.switcherMaxItemsPerLine) var switcherMaxItemsPerLine

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Position Window Controls", selection: $windowSwitcherControlPosition) {
                ForEach(WindowSwitcherControlPosition.allCases, id: \.self) { position in
                    Text(position.localizedName)
                        .tag(position)
                }
            }
            .pickerStyle(MenuPickerStyle())

            Divider().padding(.vertical, 2)
            Text("Traffic Light Buttons").font(.headline).padding(.bottom, -2)

            Picker("Visibility", selection: $switcherTrafficLightButtonsVisibility) {
                ForEach(TrafficLightButtonsVisibility.allCases, id: \.self) { visibility in
                    Text(visibility.localizedName)
                        .tag(visibility)
                }
            }

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
                            useMonochrome: switcherUseMonochromeTrafficLights
                        )
                    }
                    EnabledButtonsCheckboxes(
                        enabledButtons: $switcherEnabledTrafficLightButtons,
                        visibilityBinding: $switcherTrafficLightButtonsVisibility,
                        useMonochrome: switcherUseMonochromeTrafficLights
                    )
                }
                Toggle("Use Monochrome Colors", isOn: $switcherUseMonochromeTrafficLights)

                VStack(alignment: .leading) {
                    Toggle(isOn: $switcherDisableDockStyleTrafficLights) {
                        Text("Disable dock styling on traffic light buttons")
                    }
                    Text("Removes the pill-shaped background styling from traffic light buttons.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
            }

            Divider().padding(.vertical, 2)
            Text("Window Title").font(.headline).padding(.bottom, -2)

            Toggle("Show Window Title", isOn: $switcherShowWindowTitle)

            if switcherShowWindowTitle {
                Picker("Visibility", selection: $switcherWindowTitleVisibility) {
                    ForEach(WindowTitleVisibility.allCases, id: \.self) { visibility in
                        Text(visibility.localizedName)
                            .tag(visibility)
                    }
                }
            }

            Divider().padding(.vertical, 2)
            Text("Preview Layout (Switcher)").font(.headline).padding(.bottom, -2)

            VStack(alignment: .leading, spacing: 4) {
                let maxItemsBinding = Binding<Double>(
                    get: { Double(switcherMaxItemsPerLine) },
                    set: { switcherMaxItemsPerLine = Int($0) }
                )
                sliderSetting(
                    title: "Max Items Per Row",
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

                Text(switcherMaxItemsPerLine == 0
                    ? String(localized: "Auto: items per row determined by available screen space.")
                    : String(localized: "Limits the number of window previews per row in the window switcher."))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
