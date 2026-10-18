import Defaults
import SwiftUI

struct TrafficLightButtonsSettingsView: View {
    @Default(.enabledTrafficLightButtons) private var enabledButtons
    @Default(.useMonochromeTrafficLights) private var useMonochrome
    @Default(.trafficLightButtonsVisibility) private var trafficLightButtonsVisibility
    @Default(.trafficLightButtonScale) private var buttonScale

    var body: some View {
        Picker("Traffic light visibility", selection: $trafficLightButtonsVisibility) {
            ForEach(TrafficLightButtonsVisibility.allCases, id: \.self) { visibility in
                Text(visibility.localizedName)
                    .tag(visibility)
            }
        }

        if trafficLightButtonsVisibility != .never {
            EnabledButtonsPicker(enabledButtons: $enabledButtons) {
                MessageUtil.showAlert(
                    title: String(localized: "All buttons removed"),
                    message: String(localized: "Your traffic lights will be set to disabled automatically."),
                    actions: [.ok, .cancel]
                ) { action in
                    if action == .ok {
                        trafficLightButtonsVisibility = .never
                    }
                }
            }

            Toggle("Use monochrome colors", isOn: $useMonochrome)

            SettingsSliderRow(
                title: "Button scale",
                value: $buttonScale,
                range: 0.75 ... 2.0,
                unit: "×",
                step: 0.05
            )
        }
    }
}
