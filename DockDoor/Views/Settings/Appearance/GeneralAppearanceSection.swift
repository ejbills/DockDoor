import Defaults
import SwiftUI

struct GeneralAppearanceSection: View {
    @Default(.uniformCardRadius) var uniformCardRadius
    @Default(.useLiquidGlass) var useLiquidGlass
    @Default(.globalPaddingMultiplier) var globalPaddingMultiplier
    @Default(.unselectedContentOpacity) var unselectedContentOpacity
    @Default(.enableTitleMarquee) var enableTitleMarquee
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
                .onChange(of: appAppearanceMode) { newMode in
                    applyAppearanceMode(newMode)
                }

                if #available(macOS 26.0, *) {
                    Toggle(isOn: $useLiquidGlass) {
                        Text("Use Liquid Glass (macOS 26+)")
                    }
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

                sliderSetting(
                    title: "Unselected Content Opacity",
                    value: $unselectedContentOpacity,
                    range: 0 ... 1,
                    step: 0.05,
                    unit: "",
                    formatter: NumberFormatter.percentFormatter
                )

                VStack(alignment: .leading) {
                    Toggle(isOn: $uniformCardRadius) {
                        Text("Rounded corners")
                    }
                    Text("Round the corners of window preview images for a modern look.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .padding(.leading, 20)
                }

                VStack(alignment: .leading) {
                    Toggle(isOn: $enableTitleMarquee) {
                        Text("Scroll long titles (marquee)")
                    }
                    Text("When disabled, long titles remain static instead of scrolling.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .padding(.leading, 20)
                }

                VStack(alignment: .leading) {
                    Toggle(isOn: $showMinimizedHiddenLabels) {
                        Text("Distinguish minimized/hidden windows")
                    }
                    Text("When enabled, shows visual indicators and dims minimized/hidden windows. When disabled, treats them as normal windows with full functionality.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .padding(.leading, 20)
                }

                VStack(alignment: .leading) {
                    Toggle(isOn: $hidePreviewCardBackground) {
                        Text("Hide preview card background")
                    }
                    Text("Removes the background panel from individual window previews.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .padding(.leading, 20)
                }

                VStack(alignment: .leading) {
                    Toggle(isOn: $hideHoverContainerBackground) {
                        Text("Hide hover container background")
                    }
                    Text("Removes the container background from window preview panels.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .padding(.leading, 20)
                }

                VStack(alignment: .leading) {
                    Toggle(isOn: $hideWidgetContainerBackground) {
                        Text("Hide widget container background")
                    }
                    Text("Removes the container background from widget panels (media controls, calendar).")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .padding(.leading, 20)
                }

                VStack(alignment: .leading) {
                    Toggle(isOn: $showActiveWindowBorder) {
                        Text("Show active window border")
                    }
                    Text("Highlights the currently focused window with a colored border.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .padding(.leading, 20)
                }
            }
        }
    }
}
