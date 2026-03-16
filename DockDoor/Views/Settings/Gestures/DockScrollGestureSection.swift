import Defaults
import SwiftUI

struct DockScrollGestureSection: View {
    @Default(.enableDockScrollGesture) var enableDockScrollGesture
    @Default(.dockIconMediaScrollBehavior) var dockIconMediaScrollBehavior

    var body: some View {
        SettingsGroup(header: "Dock Icon Scroll Gesture") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $enableDockScrollGesture) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.arrow.down")
                            .foregroundColor(.accentColor)
                        Text("Enable scroll gestures on dock icons")
                    }
                }

                if enableDockScrollGesture {
                    Text("Scroll up on a dock icon to bring the app to front, scroll down to hide all its windows.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)

                    Divider()

                    Picker("Music/Spotify behavior:", selection: $dockIconMediaScrollBehavior) {
                        ForEach(DockIconMediaScrollBehavior.allCases, id: \.self) { behavior in
                            Text(behavior.localizedName).tag(behavior)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
    }
}

struct TitleBarScrollGestureSection: View {
    @Default(.enableTitleBarScrollGesture) var enableTitleBarScrollGesture
    @Default(.titleBarScrollCenteredWindowScale) var titleBarScrollCenteredWindowScale
    @Default(.titleBarScrollCenteredWindowSizingMode) var titleBarScrollCenteredWindowSizingMode
    @Default(.titleBarScrollCenteredWindowWidthScale) var titleBarScrollCenteredWindowWidthScale
    @Default(.titleBarScrollCenteredWindowHeightScale) var titleBarScrollCenteredWindowHeightScale
    @Default(.titleBarScrollCenteredWindowLockAspectRatio) var titleBarScrollCenteredWindowLockAspectRatio
    @Default(.titleBarScrollRestoreWindowInterval) var titleBarScrollRestoreWindowInterval

    var body: some View {
        SettingsGroup(header: "Title Bar Scroll Gesture") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $enableTitleBarScrollGesture) {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.tophalf.inset.filled")
                            .foregroundColor(.accentColor)
                        Text("Enable scroll gestures on active window title bars")
                    }
                }

                if enableTitleBarScrollGesture {
                    let centeredWindowScaleBinding = Binding<Double>(
                        get: { Double(titleBarScrollCenteredWindowScale) },
                        set: { titleBarScrollCenteredWindowScale = CGFloat($0) }
                    )

                    let centeredWindowWidthBinding = Binding<Double>(
                        get: { Double(titleBarScrollCenteredWindowWidthScale) },
                        set: { titleBarScrollCenteredWindowWidthScale = CGFloat($0) }
                    )

                    let centeredWindowHeightBinding = Binding<Double>(
                        get: { Double(titleBarScrollCenteredWindowHeightScale) },
                        set: { titleBarScrollCenteredWindowHeightScale = CGFloat($0) }
                    )

                    let restoreIntervalBinding = Binding<Double>(
                        get: { Double(titleBarScrollRestoreWindowInterval) },
                        set: { titleBarScrollRestoreWindowInterval = CGFloat($0) }
                    )

                    Text("Scroll up on a focused window title bar to maximize it, scroll down to center it using the configured window size, and scroll left or right to switch desktop spaces. Repeat the same up/down scroll within the configured restore time to restore the previous window size.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker("Centered Window Sizing", selection: $titleBarScrollCenteredWindowSizingMode) {
                        ForEach(TitleBarCenteredWindowSizingMode.allCases, id: \.self) { mode in
                            Text(mode.localizedName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Group {
                        switch titleBarScrollCenteredWindowSizingMode {
                        case .uniform:
                            sliderSetting(
                                title: "Centered Window Size",
                                value: centeredWindowScaleBinding,
                                range: 0.5 ... 1,
                                step: 0.05,
                                unit: "",
                                formatter: NumberFormatter.percentFormatter
                            )

                        case .separate:
                            Toggle(isOn: $titleBarScrollCenteredWindowLockAspectRatio) {
                                Text(String(localized: "Lock aspect ratio (uniform scaling)", comment: "Keep current window aspect ratio when centering; results in uniform scaling"))
                            }

                            if titleBarScrollCenteredWindowLockAspectRatio {
                                Text(String(localized: "When enabled, the current window keeps its aspect ratio. The width and height percentages are treated as maximum bounds; if they differ, the result often matches uniform scaling to the smaller bound.", comment: "Explanation for lock aspect ratio behavior in title bar scroll centered window sizing"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            sliderSetting(
                                title: "Centered Window Width",
                                value: centeredWindowWidthBinding,
                                range: 0.5 ... 1,
                                step: 0.05,
                                unit: "",
                                formatter: NumberFormatter.percentFormatter
                            )

                            sliderSetting(
                                title: "Centered Window Height",
                                value: centeredWindowHeightBinding,
                                range: 0.5 ... 1,
                                step: 0.05,
                                unit: "",
                                formatter: NumberFormatter.percentFormatter
                            )
                        }
                    }

                    sliderSetting(
                        title: "Restore Window Time",
                        value: restoreIntervalBinding,
                        range: 0.5 ... 3,
                        step: 0.1,
                        unit: "seconds",
                        formatter: NumberFormatter.oneDecimalFormatter
                    )
                }
            }
        }
    }
}
