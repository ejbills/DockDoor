import Defaults
import SwiftUI

struct TrackpadSwitcherSwipeSection: View {
    @Default(.enableWindowSwitcher) var enableWindowSwitcher
    @Default(.enableTrackpadSwitcherSwipe) var enableTrackpadSwitcherSwipe
    @Default(.trackpadSwitcherSwipeFingers) var trackpadSwitcherSwipeFingers
    @Default(.trackpadSwitcherSwipeDirection) var trackpadSwitcherSwipeDirection
    @Default(.trackpadSwitcherSwipeSensitivity) var trackpadSwitcherSwipeSensitivity

    var body: some View {
        SettingsGroup(header: "Trackpad Swipe for Window Switcher") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $enableTrackpadSwitcherSwipe) {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.draw")
                            .foregroundColor(.accentColor)
                        Text("Open window switcher with a trackpad swipe")
                    }
                }
                .settingsSearchTarget("gestures.trackpadSwitcherSwipe")
                .onChange(of: enableTrackpadSwitcherSwipe) { _ in askUserToRestartApplication() }

                if enableTrackpadSwitcherSwipe {
                    Text("Swipe to open the switcher, keep your fingers down and move left or right to change the selection, then lift your fingers to switch.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)

                    Divider()

                    Picker("Fingers:", selection: $trackpadSwitcherSwipeFingers) {
                        Text("3").tag(3)
                        Text("4").tag(4)
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                    .settingsSearchTarget("gestures.trackpadSwitcherSwipeFingers")

                    Picker("Direction:", selection: $trackpadSwitcherSwipeDirection) {
                        ForEach(TrackpadSwipeDirection.allCases, id: \.self) { direction in
                            Text(direction.localizedName).tag(direction)
                        }
                    }
                    .pickerStyle(.menu)
                    .fixedSize()
                    .settingsSearchTarget("gestures.trackpadSwitcherSwipeDirection")

                    let sensitivityBinding = Binding<Double>(
                        get: { Double(trackpadSwitcherSwipeSensitivity) },
                        set: { trackpadSwitcherSwipeSensitivity = CGFloat($0) }
                    )
                    sliderSetting(
                        title: "Swipe Sensitivity",
                        value: sensitivityBinding,
                        range: 0.5 ... 2,
                        step: 0.1,
                        unit: "\u{00d7}",
                        formatter: {
                            let f = NumberFormatter()
                            f.minimumFractionDigits = 1
                            f.maximumFractionDigits = 1
                            return f
                        }()
                    )
                    .settingsSearchTarget("gestures.trackpadSwitcherSwipeSensitivity")
                    Text("Higher values open and cycle the switcher over shorter swipes. 1 is the default.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("If macOS uses the same swipe for Mission Control, App Exposé or switching between full-screen apps, turn that gesture off in System Settings > Trackpad > More Gestures.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .disabled(!enableWindowSwitcher)
            .opacity(enableWindowSwitcher ? 1.0 : 0.5)
        }
    }
}
