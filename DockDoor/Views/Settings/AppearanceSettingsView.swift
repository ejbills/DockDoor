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
                        WindowSizeSliderView()

                        Toggle(isOn: Binding(
                            get: { !showAnimations },
                            set: { showAnimations = !$0 }
                        )) {
                            Text("Reduce motion")
                        }

                        VStack(alignment: .leading) {
                            Toggle(isOn: $uniformCardRadius) {
                                Text("Rounded image corners")
                            }
                            Text("When enabled, all preview images will be cropped to a rounded rectangle.")
                                .font(.footnote)
                                .foregroundColor(.gray)
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

struct WindowSizeSliderView: View {
    @Default(.sizingMultiplier) var sizingMultiplier

    private var visualScaleFactor: CGFloat {
        let maxWidth: CGFloat = 450
        let maxHeight: CGFloat = 120
        let widthScale = maxWidth / optimisticScreenSizeWidth
        let heightScale = maxHeight / optimisticScreenSizeHeight
        return min(widthScale, heightScale) * 0.9
    }

    private var scaledPreviewSize: CGSize {
        CGSize(
            width: optimisticScreenSizeWidth / sizingMultiplier,
            height: optimisticScreenSizeHeight / sizingMultiplier
        )
    }

    private var visualScreenSize: CGSize {
        CGSize(
            width: optimisticScreenSizeWidth * visualScaleFactor,
            height: optimisticScreenSizeHeight * visualScaleFactor
        )
    }

    private var visualPreviewSize: CGSize {
        CGSize(
            width: scaledPreviewSize.width * visualScaleFactor,
            height: scaledPreviewSize.height * visualScaleFactor
        )
    }

    private func getSizeDescription(_ value: Int) -> String {
        switch value {
        case 2: String(localized: "Large (1/2)")
        case 3, 4: String(localized: "Medium (1/\(value))")
        case 5, 6: String(localized: "Small (1/\(value))")
        default: String(localized: "Tiny (1/\(value))")
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                    .frame(width: visualScreenSize.width, height: visualScreenSize.height)
                    .overlay(
                        Text(String(localized: "Screen"))
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 4),
                        alignment: .top
                    )

                Rectangle()
                    .fill(Color.blue.opacity(0.35))
                    .frame(width: visualPreviewSize.width, height: visualPreviewSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "Preview Size"))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 4)

                Menu {
                    ForEach(2 ... 10, id: \.self) { value in
                        Button(action: { sizingMultiplier = Double(value) }) {
                            HStack {
                                Rectangle()
                                    .fill(Color.accentColor.opacity(0.2))
                                    .frame(width: 60 / Double(value), height: 16)
                                    .cornerRadius(2)

                                Text(getSizeDescription(value))
                                    .frame(width: 100, alignment: .leading)

                                if sizingMultiplier == Double(value) {
                                    Image(systemName: "checkmark")
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(getSizeDescription(Int(sizingMultiplier)))
                            .frame(width: 100, alignment: .leading)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
                }
            }
        }
        .onChange(of: sizingMultiplier) { _ in
            SharedPreviewWindowCoordinator.shared.windowSize = getWindowSize()
        }
    }
}
