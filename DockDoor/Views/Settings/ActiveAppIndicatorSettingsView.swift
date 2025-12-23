import Defaults
import SwiftUI

/// Settings view for the Active App Indicator feature.
/// Shows a line below the currently active app in the dock.
struct ActiveAppIndicatorSettingsView: View {
    @Default(.showActiveAppIndicator) var showActiveAppIndicator
    @Default(.activeAppIndicatorColor) var activeAppIndicatorColor
    @Default(.activeAppIndicatorAutoSize) var activeAppIndicatorAutoSize
    @Default(.activeAppIndicatorAutoLength) var activeAppIndicatorAutoLength
    @Default(.activeAppIndicatorHeight) var activeAppIndicatorHeight
    @Default(.activeAppIndicatorOffset) var activeAppIndicatorOffset
    @Default(.activeAppIndicatorLength) var activeAppIndicatorLength
    @Default(.activeAppIndicatorShift) var activeAppIndicatorShift

    @State private var currentDockSize: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Toggle(isOn: $showActiveAppIndicator) {
                    EmptyView()
                }
                .toggleStyle(.switch)
                .scaleEffect(0.8)
                Text("Show active app indicator below dock icon")
                Spacer()
            }
            .onChange(of: showActiveAppIndicator) { _ in askUserToRestartApplication() }

            Text(
                "Displays a colored line below the currently active application's dock icon."
            )
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.leading, 20)

            if showActiveAppIndicator {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        ColorPicker(
                            "Indicator Color",
                            selection: $activeAppIndicatorColor
                        )
                        Button("Reset") {
                            Defaults.reset(.activeAppIndicatorColor)
                        }
                        .buttonStyle(AccentButtonStyle(small: true))
                    }
                    .padding(.leading, 20)

                    HStack {
                        Text("Current Dock Size:")
                            .foregroundColor(.secondary)
                        Text("\(Int(currentDockSize)) px")
                            .fontWeight(.medium)
                        Button {
                            currentDockSize = DockUtils.getDockSize()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.borderless)
                        .help("Refresh dock size")
                    }
                    .font(.caption)
                    .padding(.leading, 20)

                    HStack {
                        Toggle(isOn: $activeAppIndicatorAutoSize) {
                            EmptyView()
                        }
                        .toggleStyle(.switch)
                        .scaleEffect(0.8)
                        Text("Automatically set height and offset")
                        Spacer()
                    }
                    .padding(.leading, 20)

                    if !activeAppIndicatorAutoSize {
                        sliderSetting(
                            title: "Indicator Height",
                            value: $activeAppIndicatorHeight,
                            range: 1.0 ... 15.0,
                            step: 1,
                            unit: "px",
                            formatter: {
                                let f = NumberFormatter()
                                f.minimumFractionDigits = 0
                                f.maximumFractionDigits = 0
                                return f
                            }()
                        )
                        .padding(.leading, 40)

                        sliderSetting(
                            title: "Position Offset",
                            value: $activeAppIndicatorOffset,
                            range: -30.0 ... 30.0,
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
                        .padding(.leading, 40)
                    }

                    HStack {
                        Toggle(isOn: $activeAppIndicatorAutoLength) {
                            EmptyView()
                        }
                        .toggleStyle(.switch)
                        .scaleEffect(0.8)
                        Text("Automatically set length")
                        Spacer()
                    }
                    .padding(.leading, 20)

                    if !activeAppIndicatorAutoLength {
                        sliderSetting(
                            title: "Indicator Length",
                            value: $activeAppIndicatorLength,
                            range: 1.0 ... 110.0,
                            step: 1.0,
                            unit: "px",
                            formatter: {
                                let f = NumberFormatter()
                                f.minimumFractionDigits = 0
                                f.maximumFractionDigits = 0
                                return f
                            }()
                        )
                        .padding(.leading, 40)
                    }

                    sliderSetting(
                        title: "Shift Indicator",
                        value: $activeAppIndicatorShift,
                        range: -2.0 ... 2.0,
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
                        Text(
                            "The indicator appears next to the active app's dock icon. Note: This feature does not support auto-hiding docks."
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding(.leading, 20)
                    .padding(.top, 4)
                }
                .padding(.top, 4)
            }
        }
        .onAppear {
            currentDockSize = DockUtils.getDockSize()
        }
    }
}
