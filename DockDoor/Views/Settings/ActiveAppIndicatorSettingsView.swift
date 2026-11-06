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
    @Default(.activeAppIndicatorStyle) var activeAppIndicatorStyle
    @Default(.activeAppIndicatorHighlightFrontmost) var activeAppIndicatorHighlightFrontmost

    @State private var currentDockSize: CGFloat = 0

    var body: some View {
        Group {
            Toggle(isOn: $showActiveAppIndicator) {
                Text("Show active app indicator below dock icon")
            }
            .settingsSearchTarget("general.activeAppIndicator")
            .onChange(of: showActiveAppIndicator) { _ in askUserToRestartApplication() }
            .settingsAnnotation("Displays a colored line below the currently active application's dock icon.")

            if showActiveAppIndicator {
                LabeledContent("Indicator Color") {
                    HStack(spacing: 8) {
                        ColorPicker("Indicator Color", selection: $activeAppIndicatorColor)
                            .labelsHidden()
                        SettingsResetButton(isModified: true) {
                            Defaults.reset(.activeAppIndicatorColor)
                        }
                    }
                }
                .settingsSearchTarget("general.indicatorColor")

                Picker("Indicator Style", selection: $activeAppIndicatorStyle) {
                    ForEach(ActiveAppIndicatorStyle.allCases, id: \.self) { style in
                        Text(style.localizedName).tag(style)
                    }
                }
                .settingsSearchTarget("general.indicatorStyle")

                if activeAppIndicatorStyle == .runningAppDots {
                    Toggle(isOn: $activeAppIndicatorHighlightFrontmost) {
                        Text("Highlight the frontmost app")
                    }
                    .settingsSearchTarget("general.indicatorHighlightFrontmost")
                    .settingsAnnotation(activeAppIndicatorHighlightFrontmost
                        ? "Shows a dot under every running application: bright for the frontmost app, dimmed for apps with open windows, black for apps with none."
                        : "Shows a dot under every running application: bright for apps with open windows, black for apps with none.")
                }

                Toggle(isOn: $activeAppIndicatorAutoSize) {
                    Text("Automatically set height and offset")
                }
                .settingsSearchTarget("general.indicatorAutoSize")

                if !activeAppIndicatorAutoSize {
                    LabeledContent("Current Dock Size:") {
                        HStack(spacing: 6) {
                            Text(verbatim: "\(Int(currentDockSize)) px")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                            Button {
                                currentDockSize = DockUtils.getDockSize()
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                            .buttonStyle(.plain)
                            .help("Refresh dock size")
                            .accessibilityLabel("Refresh dock size")
                        }
                    }

                    if activeAppIndicatorStyle == .bar {
                        SettingsSliderRow(
                            title: "Indicator Height",
                            value: $activeAppIndicatorHeight,
                            range: 1.0 ... 15.0,
                            unit: " px",
                            step: 1,
                            decimals: 0
                        )
                        .settingsSearchTarget("general.indicatorHeight")
                    }

                    SettingsSliderRow(
                        title: "Position Offset",
                        value: $activeAppIndicatorOffset,
                        range: -30.0 ... 30.0,
                        unit: " px",
                        step: 1.0,
                        decimals: 0
                    )
                    .settingsSearchTarget("general.indicatorOffset")
                }

                if activeAppIndicatorStyle == .bar {
                    Toggle(isOn: $activeAppIndicatorAutoLength) {
                        Text("Automatically set length")
                    }
                    .settingsSearchTarget("general.indicatorAutoLength")

                    if !activeAppIndicatorAutoLength {
                        SettingsSliderRow(
                            title: "Indicator Length",
                            value: $activeAppIndicatorLength,
                            range: 1.0 ... 110.0,
                            unit: " px",
                            step: 1.0,
                            decimals: 0
                        )
                        .settingsSearchTarget("general.indicatorLength")
                    }
                }

                SettingsSliderRow(
                    title: "Shift Indicator",
                    value: $activeAppIndicatorShift,
                    range: -2.0 ... 2.0,
                    unit: " px",
                    step: 1.0,
                    decimals: 0
                )
                .settingsSearchTarget("general.indicatorShift")
                .settingsAnnotation("The indicator appears next to the active app's dock icon. Note: This feature does not support auto-hiding docks.")
            }
        }
        .onAppear {
            currentDockSize = DockUtils.getDockSize()
        }
    }
}
