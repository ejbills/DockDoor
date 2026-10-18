import Defaults
import SwiftUI

struct CompactModeSection: View {
    @Default(.disableImagePreview) var disableImagePreview
    @Default(.compactModeTitleFormat) var compactModeTitleFormat
    @Default(.compactModeItemSize) var compactModeItemSize
    @Default(.compactModeHideTrafficLights) var compactModeHideTrafficLights
    @Default(.windowSwitcherCompactThreshold) var windowSwitcherCompactThreshold
    @Default(.dockPreviewCompactThreshold) var dockPreviewCompactThreshold
    @Default(.cmdTabCompactThreshold) var cmdTabCompactThreshold

    let hasScreenRecordingPermission: Bool

    private var isCompactModeForced: Bool {
        disableImagePreview || !hasScreenRecordingPermission
    }

    var body: some View {
        SettingsSection("Compact mode (titles only)", footer: "Compact mode displays windows as a streamlined vertical list with app icons and titles.") {
            Toggle(isOn: Binding(
                get: { !hasScreenRecordingPermission || disableImagePreview },
                set: { disableImagePreview = $0 }
            )) {
                Text("Always use compact mode")
            }
            .settingsSearchTarget("appearance.compactMode")
            .disabled(!hasScreenRecordingPermission)

            if !hasScreenRecordingPermission {
                SettingsCallout(icon: "lock.fill", message: Text("Screen Recording permission is required for window thumbnails."))
            }
        }

        if !isCompactModeForced {
            SettingsSection("Automatic compact mode", footer: "Set a threshold to automatically switch to compact mode when an app has that many or more windows. Set to 0 to disable.") {
                compactThresholdSlider(
                    title: "Window Switcher",
                    value: $windowSwitcherCompactThreshold,
                    description: "Switch to compact list in window switcher when window count reaches threshold."
                )
                .settingsSearchTarget("appearance.compactThresholdSwitcher")

                compactThresholdSlider(
                    title: "Dock Previews",
                    value: $dockPreviewCompactThreshold,
                    description: "Switch to compact list in dock previews when window count reaches threshold."
                )
                .settingsSearchTarget("appearance.compactThresholdDock")

                compactThresholdSlider(
                    title: "Cmd+Tab Enhancement",
                    value: $cmdTabCompactThreshold,
                    description: "Switch to compact list in Cmd+Tab overlay when window count reaches threshold."
                )
                .settingsSearchTarget("appearance.compactThresholdCmdTab")
            }
        }

        SettingsSection("Compact list appearance") {
            Picker("Item size", selection: $compactModeItemSize) {
                ForEach(CompactModeItemSize.allCases) { size in
                    Text(size.localizedName).tag(size)
                }
            }
            .settingsSearchTarget("appearance.compactItemSize")

            Picker("Title format", selection: $compactModeTitleFormat) {
                ForEach(CompactModeTitleFormat.allCases) { format in
                    Text(format.localizedName).tag(format)
                }
            }
            .settingsSearchTarget("appearance.compactTitleFormat")

            Toggle("Hide traffic lights", isOn: $compactModeHideTrafficLights)
                .settingsSearchTarget("appearance.hideTrafficLights")
                .settingsAnnotation("Hides the close, minimize, and other window control buttons in compact mode to provide more room for window titles.")
        }
    }

    private func compactThresholdSlider(title: String, value: Binding<Int>, description: String) -> some View {
        SettingsSliderRow(
            title: LocalizedStringKey(title),
            value: Binding(get: { Double(value.wrappedValue) }, set: { value.wrappedValue = Int($0) }),
            range: 0 ... 10,
            valueText: { $0 == 0 ? String(localized: "Disabled") : String(localized: "\(Int($0))+ windows") }
        )
        .settingsAnnotation(LocalizedStringKey(description))
    }
}
