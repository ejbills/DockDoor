import Defaults
import SwiftUI

struct TrackpadSwitcherSwipeSection: View {
    @Default(.enableWindowSwitcher) var enableWindowSwitcher
    @Default(.enableTrackpadSwitcherSwipe) var enableTrackpadSwitcherSwipe
    @Default(.trackpadSwitcherSwipeFingers) var trackpadSwitcherSwipeFingers
    @Default(.trackpadSwitcherSwipeDirection) var trackpadSwitcherSwipeDirection
    @Default(.trackpadSwitcherSwipeSensitivity) var trackpadSwitcherSwipeSensitivity

    var body: some View {
        SettingsSection("Trackpad swipe for window switcher") {
            Group {
                Toggle(isOn: $enableTrackpadSwitcherSwipe) {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.draw")
                            .foregroundColor(.accentColor)
                        Text("Open window switcher with a trackpad swipe")
                    }
                }
                .settingsSearchTarget("gestures.trackpadSwitcherSwipe")
                .onChange(of: enableTrackpadSwitcherSwipe) { _ in askUserToRestartApplication() }
                .settingsAnnotation("Swipe to open the switcher, keep your fingers down and move left or right to change the selection, then lift your fingers to switch.")

                if enableTrackpadSwitcherSwipe {
                    Picker("Fingers:", selection: $trackpadSwitcherSwipeFingers) {
                        Text("3").tag(3)
                        Text("4").tag(4)
                    }
                    .fixedSize()
                    .settingsSearchTarget("gestures.trackpadSwitcherSwipeFingers")

                    Picker("Direction:", selection: $trackpadSwitcherSwipeDirection) {
                        ForEach(TrackpadSwipeDirection.allCases, id: \.self) { direction in
                            Text(direction.localizedName).tag(direction)
                        }
                    }
                    .fixedSize()
                    .settingsSearchTarget("gestures.trackpadSwitcherSwipeDirection")

                    let sensitivityBinding = Binding<Double>(
                        get: { Double(trackpadSwitcherSwipeSensitivity) },
                        set: { trackpadSwitcherSwipeSensitivity = CGFloat($0) }
                    )
                    SettingsSliderRow(
                        title: "Swipe Sensitivity",
                        value: sensitivityBinding,
                        range: Double(TrackpadSwipeDetector.sensitivityRange.lowerBound) ... Double(TrackpadSwipeDetector.sensitivityRange.upperBound),
                        step: 0.1
                    )
                    .settingsSearchTarget("gestures.trackpadSwitcherSwipeSensitivity")
                    .settingsAnnotation("Higher values open the switcher and change the selection with shorter swipes.")

                    Text("If macOS uses the same swipe for Mission Control, App Exposé or switching between full-screen apps, turn that gesture off in System Settings > Trackpad > More Gestures.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
