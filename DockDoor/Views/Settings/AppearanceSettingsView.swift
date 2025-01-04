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
    @Default(.windowSwitcherControlPosition) var windowSwitcherControlPosition
    @Default(.dimInSwitcherUntilSelected) var dimInSwitcherUntilSelected
    @Default(.selectionOpacity) var selectionOpacity
    @Default(.selectionColor) var selectionColor
    @Default(.maxRows) var maxRows
    @Default(.maxColumns) var maxColumns

    @State private var previousTrafficLightButtonsPosition: TrafficLightButtonsPosition
    @State private var previousWindowTitlePosition: WindowTitlePosition

    init() {
        _previousTrafficLightButtonsPosition = State(initialValue: Defaults[.trafficLightButtonsPosition])
        _previousWindowTitlePosition = State(initialValue: Defaults[.windowTitlePosition])
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                StyledGroupBox(label: "General") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(isOn: $showAnimations) {
                            Text("Enable Preview Window Sliding Animation")
                        }

                        Toggle(isOn: $uniformCardRadius) {
                            Text("Use Uniform Image Preview Radius")
                        }

                        Toggle(isOn: $showWindowTitle) {
                            Text("Show Window Title in Previews")
                        }

                        Picker("Show Window Title in", selection: $windowTitleDisplayCondition) {
                            ForEach(WindowTitleDisplayCondition.allCases, id: \.self) { condition in
                                Text(condition.localizedName)
                                    .tag(condition)
                            }
                        }

                        HStack {
                            ColorPicker("Window Selection Background Color", selection: Binding(
                                get: { selectionColor ?? .secondary },
                                set: { selectionColor = $0 }
                            ))
                            Button(action: {
                                Defaults.reset(.selectionColor)
                            }) {
                                Text("Reset")
                            }
                            .buttonStyle(AccentButtonStyle(small: true))
                        }

                        sliderSetting(title: String(localized: "Window Selection Background Opacity"),
                                      value: $selectionOpacity,
                                      range: 0 ... 1,
                                      step: 0.05,
                                      unit: "",
                                      formatter: NumberFormatter.percentFormatter)
                    }
                }

                StyledGroupBox(label: "Traffic Light Buttons") {
                    TrafficLightButtonsSettingsView()
                }

                StyledGroupBox(label: "Dock Previews") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(isOn: $showAppName) {
                            Text("Show App Name in Dock Previews")
                        }

                        Picker(String(localized: "App Name Style"), selection: $appNameStyle) {
                            ForEach(AppNameStyle.allCases, id: \.self) { style in
                                Text(style.localizedName)
                                    .tag(style)
                            }
                        }
                        .disabled(!showAppName)

                        Group {
                            Picker("Window Title Visibility", selection: $windowTitleVisibility) {
                                ForEach(WindowTitleVisibility.allCases, id: \.self) { visibility in
                                    Text(visibility.localizedName)
                                        .tag(visibility)
                                }
                            }

                            Picker("Window Title Position", selection: $windowTitlePosition) {
                                ForEach(WindowTitlePosition.allCases, id: \.self) { position in
                                    Text(position.localizedName)
                                        .tag(position)
                                }
                            }
                        }
                        .disabled(!showWindowTitle)
                    }
                }

                // Window Switcher Group
                StyledGroupBox(label: "Window Switcher") {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Position Window Controls", selection: $windowSwitcherControlPosition) {
                            ForEach(WindowSwitcherControlPosition.allCases, id: \.self) { position in
                                Text(position.localizedName)
                                    .tag(position)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())

                        VStack(alignment: .leading) {
                            Toggle(isOn: $dimInSwitcherUntilSelected) {
                                Text("Dim Unselected Windows")
                            }
                            Text("When enabled, dims all windows except those currently under selected.")
                                .font(.footnote)
                                .foregroundColor(.gray)
                        }
                    }
                }

                StyledGroupBox(label: "Window Preview Layout") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Layout Limits")
                            .font(.subheadline)

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
                    }
                }

                StyledGroupBox(label: "Colors") {
                    GradientColorPaletteSettingsView()
                }
            }
            .padding(20)
        }
        .frame(minWidth: 650, maxHeight: 700)
    }
}
