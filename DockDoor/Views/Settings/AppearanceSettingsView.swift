import Defaults
import SwiftUI

struct AppearanceSettingsView: View {
    @Default(.showAnimations) var showAnimations
    @Default(.uniformCardRadius) var uniformCardRadius
    @Default(.showAppName) var showAppName
    @Default(.appNameStyle) var appNameStyle
    @Default(.showWindowTitle) var showWindowTitle
    @Default(.windowTitleDisplayCondition) var windowTitleDisplayCondition
    @Default(.windowTitleVisibility) var windowTitleVisibility
    @Default(.windowTitlePosition) var windowTitlePosition
    @Default(.trafficLightButtonsVisibility) var trafficLightButtonsVisibility
    @Default(.trafficLightButtonsPosition) var trafficLightButtonsPosition
    @Default(.selectionOpacity) var selectionOpacity
    @Default(.maxRows) var maxRows
    @Default(.maxColumns) var maxColumns

    @State private var previousTrafficLightButtonsPosition: TrafficLightButtonsPosition
    @State private var previousWindowTitlePosition: WindowTitlePosition

    init() {
        _previousTrafficLightButtonsPosition = State(initialValue: Defaults[.trafficLightButtonsPosition])
        _previousWindowTitlePosition = State(initialValue: Defaults[.windowTitlePosition])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $showAnimations, label: {
                Text("Enable Preview Window Sliding Animation")
            })

            Toggle(isOn: $uniformCardRadius, label: {
                Text("Use Uniform Image Preview Radius")
            })

            sliderSetting(title: String(localized: "Window Selection Background Opacity"),
                          value: $selectionOpacity,
                          range: 0 ... 1,
                          step: 0.05,
                          unit: "",
                          formatter: NumberFormatter.percentFormatter)

            Divider()

            Text("Window Preview Layout Limits")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text("Set to 0 for unlimited")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("• When hovering over the Dock at the bottom, windows flow in rows from left to right")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("• When hovering over the Dock on the sides, windows flow in columns from top to bottom")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("• When using the Window Switcher, windows always flow in rows from left to right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 4)

            sliderSetting(title: String(localized: "Maximum Horizontal Rows"),
                          value: $maxRows,
                          range: 0 ... 10,
                          step: 1,
                          unit: "")

            sliderSetting(title: String(localized: "Maximum Vertical Columns"),
                          value: $maxColumns,
                          range: 0 ... 10,
                          step: 1,
                          unit: "")

            Divider()

            Picker("Traffic Light Buttons Visibility", selection: $trafficLightButtonsVisibility) {
                ForEach(TrafficLightButtonsVisibility.allCases, id: \.self) { visibility in
                    Text(visibility.localizedName)
                        .tag(visibility)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .scaledToFit()
            .layoutPriority(1)

            Picker("Traffic Light Buttons Position", selection: $trafficLightButtonsPosition) {
                ForEach(TrafficLightButtonsPosition.allCases, id: \.self) { position in
                    Text(position.localizedName)
                        .tag(position)
                }
            }
            .onChange(of: trafficLightButtonsPosition) { newValue in
                if newValue.rawValue == windowTitlePosition.rawValue {
                    MessageUtil.showAlert(
                        title: String(localized: "Elements Overlap"),
                        message: String(localized: "The selected positions for Traffic Light Buttons and Window Title will overlap."),
                        actions: [.ok, .cancel],
                        completion: { result in
                            if result == .cancel {
                                trafficLightButtonsPosition = previousTrafficLightButtonsPosition
                            } else {
                                previousTrafficLightButtonsPosition = newValue
                            }
                        }
                    )
                } else {
                    previousTrafficLightButtonsPosition = newValue
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .scaledToFit()
            .layoutPriority(1)

            Divider()

            Toggle(isOn: $showAppName) {
                Text("Show App Name in Dock Previews")
            }

            Picker(String(localized: "App Name Style"), selection: $appNameStyle) {
                ForEach(AppNameStyle.allCases, id: \.self) { style in
                    Text(style.localizedName)
                        .tag(style)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .scaledToFit()
            .layoutPriority(1)
            .disabled(!showAppName)

            Divider()

            Toggle(isOn: $showWindowTitle) {
                Text("Show Window Title in Previews")
            }

            Group {
                Picker("Show Window Title in", selection: $windowTitleDisplayCondition) {
                    ForEach(WindowTitleDisplayCondition.allCases, id: \.self) { condtion in
                        if condtion == .all {
                            Text(condtion.localizedName)
                                .tag(condtion)
                            Divider() // Separate from Window Switcher & Dock Previews
                        } else {
                            Text(condtion.localizedName)
                                .tag(condtion)
                        }
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .scaledToFit()

                Picker("Window Title Visibility", selection: $windowTitleVisibility) {
                    ForEach(WindowTitleVisibility.allCases, id: \.self) { visibility in
                        Text(visibility.localizedName)
                            .tag(visibility)
                    }
                }
                .scaledToFit()
                .pickerStyle(MenuPickerStyle())

                Picker("Window Title Position", selection: $windowTitlePosition) {
                    ForEach(WindowTitlePosition.allCases, id: \.self) { position in
                        Text(position.localizedName)
                            .tag(position)
                    }
                }
                .onChange(of: windowTitlePosition) { newValue in
                    if newValue.rawValue == trafficLightButtonsPosition.rawValue {
                        MessageUtil.showAlert(
                            title: String(localized: "Elements Overlap"),
                            message: String(localized: "The selected positions for Traffic Light Buttons and Window Title will overlap."),
                            actions: [.ok, .cancel],
                            completion: { result in
                                if result == .cancel {
                                    windowTitlePosition = previousWindowTitlePosition
                                } else {
                                    previousWindowTitlePosition = newValue
                                }
                            }
                        )
                    } else {
                        previousWindowTitlePosition = newValue
                    }
                }
                .scaledToFit()
                .pickerStyle(SegmentedPickerStyle())
            }
            .disabled(!showWindowTitle)

            Divider()

            GradientColorPaletteSettingsView()
        }
        .padding(20)
        .frame(minWidth: 650)
    }
}
