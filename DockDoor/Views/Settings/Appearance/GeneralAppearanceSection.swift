import Defaults
import SwiftUI

struct GeneralAppearanceSection: View {
    @Default(.uniformCardRadius) var uniformCardRadius
    @Default(.globalPaddingMultiplier) var globalPaddingMultiplier
    @Default(.unselectedContentOpacity) var unselectedContentOpacity
    @Default(.titleOverflowStyle) var titleOverflowStyle
    @Default(.showMinimizedHiddenLabels) var showMinimizedHiddenLabels
    @Default(.hidePreviewCardBackground) var hidePreviewCardBackground
    @Default(.hideHoverContainerBackground) var hideHoverContainerBackground
    @Default(.hideWidgetContainerBackground) var hideWidgetContainerBackground
    @Default(.showActiveWindowBorder) var showActiveWindowBorder
    @Default(.appAppearanceMode) var appAppearanceMode

    var body: some View {
        SettingsGroup(header: "General Appearance") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Appearance", selection: $appAppearanceMode) {
                    ForEach(AppAppearanceMode.allCases) { mode in
                        Text(mode.localizedName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .settingsSearchTarget("appearance.theme")
                .onChange(of: appAppearanceMode) { newMode in
                    applyAppearanceMode(newMode)
                }

                sliderSetting(
                    title: "Spacing Scale",
                    value: $globalPaddingMultiplier,
                    range: 0.5 ... 2.0,
                    step: 0.1,
                    unit: "×",
                    formatter: {
                        let f = NumberFormatter()
                        f.minimumFractionDigits = 1
                        f.maximumFractionDigits = 1
                        return f
                    }()
                )
                .settingsSearchTarget("appearance.spacingScale")

                sliderSetting(
                    title: "Unselected Content Opacity",
                    value: $unselectedContentOpacity,
                    range: 0 ... 1,
                    step: 0.05,
                    unit: "",
                    formatter: NumberFormatter.percentFormatter
                )
                .settingsSearchTarget("appearance.unselectedOpacity")

                VStack(alignment: .leading) {
                    Toggle(isOn: $uniformCardRadius) {
                        Text("Rounded corners")
                    }
                    .settingsSearchTarget("appearance.roundedCorners")
                    Text("Round the corners of window preview images for a modern look.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .padding(.leading, 20)
                }

                VStack(alignment: .leading) {
                    Picker("Long title overflow", selection: $titleOverflowStyle) {
                        ForEach(TitleOverflowStyle.allCases, id: \.self) { style in
                            Text(style.localizedName).tag(style)
                        }
                    }
                    .settingsSearchTarget("appearance.marquee")
                    Text("How to display window titles that are too long to fit.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .padding(.leading, 20)
                }

                VStack(alignment: .leading) {
                    Toggle(isOn: $showMinimizedHiddenLabels) {
                        Text("Distinguish minimized/hidden windows")
                    }
                    .settingsSearchTarget("appearance.distinguishMinimized")
                    Text("When enabled, shows visual indicators and dims minimized/hidden windows. When disabled, treats them as normal windows with full functionality.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .padding(.leading, 20)
                }

                VStack(alignment: .leading) {
                    Toggle(isOn: $hidePreviewCardBackground) {
                        Text("Hide preview card background")
                    }
                    .settingsSearchTarget("appearance.hidePreviewBackground")
                    Text("Removes the background panel from individual window previews.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .padding(.leading, 20)
                }

                VStack(alignment: .leading) {
                    Toggle(isOn: $hideHoverContainerBackground) {
                        Text("Hide hover container background")
                    }
                    .settingsSearchTarget("appearance.hideContainerBackground")
                    Text("Removes the container background from window preview panels.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .padding(.leading, 20)
                }

                VStack(alignment: .leading) {
                    Toggle(isOn: $hideWidgetContainerBackground) {
                        Text("Hide widget container background")
                    }
                    .settingsSearchTarget("appearance.hideWidgetBackground")
                    Text("Removes the container background from widget panels (media controls, calendar).")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .padding(.leading, 20)
                }

                VStack(alignment: .leading) {
                    Toggle(isOn: $showActiveWindowBorder) {
                        Text("Show active window border")
                    }
                    .settingsSearchTarget("appearance.activeBorder")
                    Text("Highlights the currently focused window with a colored border.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .padding(.leading, 20)
                }
            }
        }
    }
}
