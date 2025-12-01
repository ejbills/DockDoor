import Defaults
import SwiftUI

/// Settings view for the Active App Indicator feature.
/// Shows a line below the currently active app in the dock.
struct ActiveAppIndicatorSettingsView: View {
    @Default(.showActiveAppIndicator) var showActiveAppIndicator
    @Default(.activeAppIndicatorColor) var activeAppIndicatorColor
    @Default(.activeAppIndicatorHeight) var activeAppIndicatorHeight
    @Default(.activeAppIndicatorOffset) var activeAppIndicatorOffset
    @Default(.adjustDockAutoHideAnimation) var adjustDockAutoHideAnimation
    @Default(.activeAppIndicatorFadeOutDuration) var fadeOutDuration
    @Default(.activeAppIndicatorFadeOutDelay) var fadeOutDelay
    @Default(.activeAppIndicatorFadeInDuration) var fadeInDuration
    @Default(.activeAppIndicatorFadeInDelay) var fadeInDelay

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
                        title: "Position Offset",
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

                    Divider()
                        .padding(.vertical, 4)

                    Toggle(isOn: $adjustDockAutoHideAnimation) {
                        Text("Adjust dock auto-hide animation values")
                    }
                    .padding(.leading, 20)

                    if adjustDockAutoHideAnimation {
                        Text("Auto-Hide Animation (when dock auto-hide is enabled)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 20)

                        sliderSetting(
                            title: "Fade In Delay",
                            value: $fadeInDelay,
                            range: 0.0 ... 2.0,
                            step: 0.1,
                            unit: "s",
                            formatter: NumberFormatter.oneDecimalFormatter
                        )
                        .padding(.leading, 20)

                        sliderSetting(
                            title: "Fade In Duration",
                            value: $fadeInDuration,
                            range: 0.0 ... 2.0,
                            step: 0.1,
                            unit: "s",
                            formatter: NumberFormatter.oneDecimalFormatter
                        )
                        .padding(.leading, 20)

                        sliderSetting(
                            title: "Fade Out Delay",
                            value: $fadeOutDelay,
                            range: 0.0 ... 2.0,
                            step: 0.1,
                            unit: "s",
                            formatter: NumberFormatter.oneDecimalFormatter
                        )
                        .padding(.leading, 20)

                        sliderSetting(
                            title: "Fade Out Duration",
                            value: $fadeOutDuration,
                            range: 0.0 ... 2.0,
                            step: 0.1,
                            unit: "s",
                            formatter: NumberFormatter.oneDecimalFormatter
                        )
                        .padding(.leading, 20)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.secondary)
                        Text("The indicator appears next to the active app's dock icon.")
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
