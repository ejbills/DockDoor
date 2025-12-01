import Defaults
import SwiftUI

/// Settings view for the Active App Indicator feature.
/// Shows a line below the currently active app in the dock.
struct ActiveAppIndicatorSettingsView: View {
    @Default(.showActiveAppIndicator) var showActiveAppIndicator
    @Default(.activeAppIndicatorColor) var activeAppIndicatorColor
    @Default(.activeAppIndicatorHeight) var activeAppIndicatorHeight
    @Default(.activeAppIndicatorOffset) var activeAppIndicatorOffset

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $showActiveAppIndicator) {
                Text("Show active app indicator below dock icon")
            }

            Text("Displays a colored line below the currently active application's dock icon.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 20)

            if showActiveAppIndicator {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        ColorPicker("Indicator Color", selection: $activeAppIndicatorColor)
                        Button("Reset") {
                            Defaults.reset(.activeAppIndicatorColor)
                        }
                        .buttonStyle(AccentButtonStyle(small: true))
                    }
                    .padding(.leading, 20)

                    sliderSetting(
                        title: "Indicator Height",
                        value: $activeAppIndicatorHeight,
                        range: 1.0 ... 8.0,
                        step: 1,
                        unit: "px",
                        formatter: {
                            let f = NumberFormatter()
                            f.minimumFractionDigits = 0
                            f.maximumFractionDigits = 0
                            return f
                        }()
                    )
                    .padding(.leading, 20)

                    sliderSetting(
                        title: "Vertical Position Offset",
                        value: $activeAppIndicatorOffset,
                        range: -20.0 ... 20.0,
                        step: 1.0,
                        unit: "px",
                        formatter: {
                            let f = NumberFormatter()
                            f.minimumFractionDigits = 0
                            f.maximumFractionDigits = 0
                            f.positivePrefix = "+"
                            return f
                        }()
                    )
                    .padding(.leading, 20)

                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.secondary)
                        Text("This feature only works when the dock is positioned at the bottom of the screen.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 20)
                    .padding(.top, 4)
                }
                .padding(.top, 4)
            }
        }
    }
}
