import Defaults
import SwiftUI

struct GeneralAppearanceSection: View {
    @Default(.uniformCardRadius) var uniformCardRadius
    @Default(.previewCornerRadius) var previewCornerRadius
    @Default(.globalPaddingMultiplier) var globalPaddingMultiplier
    @Default(.unselectedContentOpacity) var unselectedContentOpacity
    @Default(.titleOverflowStyle) var titleOverflowStyle
    @Default(.showMinimizedHiddenLabels) var showMinimizedHiddenLabels
    @Default(.showSpaceNumber) var showSpaceNumber
    @Default(.showWindowlessAppQuitButton) var showWindowlessAppQuitButton
    @Default(.hidePreviewCardBackground) var hidePreviewCardBackground
    @Default(.hideHoverContainerBackground) var hideHoverContainerBackground
    @Default(.hideWidgetContainerBackground) var hideWidgetContainerBackground
    @Default(.showActiveWindowBorder) var showActiveWindowBorder
    @Default(.appAppearanceMode) var appAppearanceMode

    var body: some View {
        SettingsSection("General Appearance") {
            Picker("Appearance", selection: $appAppearanceMode) {
                ForEach(AppAppearanceMode.allCases) { mode in
                    Text(mode.localizedName).tag(mode)
                }
            }
            .settingsSearchTarget("appearance.theme")
            .onChange(of: appAppearanceMode) { newMode in
                applyAppearanceMode(newMode)
            }

            SettingsSliderRow(
                title: "Spacing Scale",
                value: $globalPaddingMultiplier,
                range: 0.5 ... 2.0,
                unit: "×",
                step: 0.1
            )
            .settingsSearchTarget("appearance.spacingScale")

            SettingsSliderRow(
                title: "Unselected Content Opacity",
                value: $unselectedContentOpacity,
                range: 0 ... 1,
                step: 0.05
            )
            .settingsSearchTarget("appearance.unselectedOpacity")

            Toggle(isOn: $uniformCardRadius) {
                Text("Rounded corners")
            }
            .settingsSearchTarget("appearance.roundedCorners")
            .settingsAnnotation("Round the corners of window preview images for a modern look.")

            if uniformCardRadius {
                SettingsSliderRow(
                    title: "Corner Radius",
                    value: $previewCornerRadius,
                    range: 0 ... 40,
                    unit: " pt",
                    step: 1
                )
                .settingsSearchTarget("appearance.cornerRadius")
            }

            Picker("Long title overflow", selection: $titleOverflowStyle) {
                ForEach(TitleOverflowStyle.allCases, id: \.self) { style in
                    Text(style.localizedName).tag(style)
                }
            }
            .settingsSearchTarget("appearance.marquee")
            .settingsAnnotation("How to display window titles that are too long to fit.")

            Toggle(isOn: $showMinimizedHiddenLabels) {
                Text("Distinguish minimized/hidden windows")
            }
            .settingsSearchTarget("appearance.distinguishMinimized")
            .settingsAnnotation("When enabled, shows visual indicators and dims minimized/hidden windows. When disabled, treats them as normal windows with full functionality.")

            Toggle(isOn: $showSpaceNumber) {
                Text("Show Space number on previews")
            }
            .settingsSearchTarget("appearance.spaceNumber")
            .settingsAnnotation("Labels each preview with the number of the desktop (Space) its window is on. Only shown when you have more than one desktop.")

            Toggle(isOn: $showWindowlessAppQuitButton) {
                Text("Show quit button for apps with no open windows")
            }
            .settingsSearchTarget("appearance.windowlessQuitButton")
            .settingsAnnotation("Shows a quit-only control on previews for running apps with no open windows.")

            Toggle(isOn: $hidePreviewCardBackground) {
                Text("Hide preview card background")
            }
            .settingsSearchTarget("appearance.hidePreviewBackground")
            .settingsAnnotation("Removes the background panel from individual window previews.")

            Toggle(isOn: $hideHoverContainerBackground) {
                Text("Hide hover container background")
            }
            .settingsSearchTarget("appearance.hideContainerBackground")
            .settingsAnnotation("Removes the container background from window preview panels.")

            Toggle(isOn: $hideWidgetContainerBackground) {
                Text("Hide widget container background")
            }
            .settingsSearchTarget("appearance.hideWidgetBackground")
            .settingsAnnotation("Removes the container background from widget panels (media controls, calendar).")

            Toggle(isOn: $showActiveWindowBorder) {
                Text("Show active window border")
            }
            .settingsSearchTarget("appearance.activeBorder")
            .settingsAnnotation("Highlights the currently focused window with a colored border.")
        }
    }
}
