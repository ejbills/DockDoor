import Defaults
import SwiftUI

struct GestureSettingsSection: View {
    @Default(.gestureSwipeThreshold) var gestureSwipeThreshold

    var body: some View {
        SettingsSection("Gesture settings") {
            let thresholdBinding = Binding<Double>(
                get: { Double(gestureSwipeThreshold) },
                set: { gestureSwipeThreshold = CGFloat($0) }
            )
            SettingsSliderRow(
                title: "Gesture Sensitivity",
                value: thresholdBinding,
                range: 20 ... 100,
                unit: " px",
                step: 10,
                decimals: 0
            )
            .settingsSearchTarget("gestures.sensitivity")
            Text("Lower values make gestures more sensitive. Higher values require longer swipes. Applies to both dock previews and window switcher.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
