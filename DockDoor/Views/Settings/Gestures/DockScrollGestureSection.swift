import Defaults
import SwiftUI

struct DockScrollGestureSection: View {
    @Default(.enableDockScrollGesture) var enableDockScrollGesture
    @Default(.dockIconScrollBehavior) var dockIconScrollBehavior
    @Default(.dockIconMediaScrollBehavior) var dockIconMediaScrollBehavior

    var body: some View {
        SettingsSection("Dock icon scroll gesture") {
            Toggle(isOn: $enableDockScrollGesture) {
                Text("Enable scroll gestures on dock icons")
            }
            .settingsSearchTarget("gestures.dockScroll")
            .settingsAnnotation("Choose what happens when scrolling directly on a dock icon.")

            if enableDockScrollGesture {
                Picker("Dock icon scroll", selection: $dockIconScrollBehavior) {
                    ForEach(DockIconScrollBehavior.allCases, id: \.self) { behavior in
                        Text(behavior.localizedName).tag(behavior)
                    }
                }
                .settingsSearchTarget("gestures.dockIconScroll")

                Picker("Music and Spotify icon scroll", selection: $dockIconMediaScrollBehavior) {
                    ForEach(DockIconMediaScrollBehavior.allCases, id: \.self) { behavior in
                        Text(behavior.localizedName).tag(behavior)
                    }
                }
                .settingsSearchTarget("gestures.musicScroll")
                .settingsAnnotation("Only applies when scrolling directly on Apple Music or Spotify dock icons.")
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
        SettingsSection("Title bar scroll gesture") {
            Toggle(isOn: $enableTitleBarScrollGesture) {
                Text("Enable scroll gestures on active window title bars")
            }
            .settingsSearchTarget("gestures.titleBarScroll")
            .settingsAnnotation("Scroll up on a focused window title bar to maximize it, scroll down to center it using the configured window size, and scroll left or right to switch desktop spaces. Repeat the same up/down scroll within the configured restore time to restore the previous window size.")

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

                Picker("Centered window sizing", selection: $titleBarScrollCenteredWindowSizingMode) {
                    ForEach(TitleBarCenteredWindowSizingMode.allCases, id: \.self) { mode in
                        Text(mode.localizedName).tag(mode)
                    }
                }
                .settingsSearchTarget("gestures.centeredSizingMode")

                Group {
                    switch titleBarScrollCenteredWindowSizingMode {
                    case .uniform:
                        SettingsSliderRow(
                            title: "Centered window size",
                            value: centeredWindowScaleBinding,
                            range: 0.5 ... 1,
                            step: 0.05
                        )
                        .settingsSearchTarget("gestures.centeredWindowSize")

                    case .separate:
                        Toggle(isOn: $titleBarScrollCenteredWindowLockAspectRatio) {
                            Text(String(localized: "Lock aspect ratio (uniform scaling)", comment: "Keep current window aspect ratio when centering; results in uniform scaling"))
                        }
                        .settingsSearchTarget("gestures.centeredLockAspect")

                        if titleBarScrollCenteredWindowLockAspectRatio {
                            Text(String(localized: "When enabled, the current window keeps its aspect ratio. The width and height percentages are treated as maximum bounds; if they differ, the result often matches uniform scaling to the smaller bound.", comment: "Explanation for lock aspect ratio behavior in title bar scroll centered window sizing"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        SettingsSliderRow(
                            title: "Centered window width",
                            value: centeredWindowWidthBinding,
                            range: 0.5 ... 1,
                            step: 0.05
                        )
                        .settingsSearchTarget("gestures.centeredWidth")

                        SettingsSliderRow(
                            title: "Centered window height",
                            value: centeredWindowHeightBinding,
                            range: 0.5 ... 1,
                            step: 0.05
                        )
                        .settingsSearchTarget("gestures.centeredHeight")
                    }
                }

                SettingsSliderRow(
                    title: "Restore window time",
                    value: restoreIntervalBinding,
                    range: 0.5 ... 3,
                    unit: " s",
                    step: 0.1,
                    decimals: 1
                )
                .settingsSearchTarget("gestures.restoreTime")
            }
        }
    }
}
