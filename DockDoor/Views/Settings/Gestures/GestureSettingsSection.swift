import Defaults
import SwiftUI

struct GestureSettingsSection: View {
    @Default(.gestureSwipeThreshold) var gestureSwipeThreshold

    var body: some View {
        SettingsGroup(header: "Gesture Settings") {
            VStack(alignment: .leading, spacing: 4) {
                let thresholdBinding = Binding<Double>(
                    get: { Double(gestureSwipeThreshold) },
                    set: { gestureSwipeThreshold = CGFloat($0) }
                )
                sliderSetting(
                    title: "Gesture Sensitivity",
                    value: thresholdBinding,
                    range: 20 ... 100,
                    step: 10,
                    unit: "px",
                    formatter: {
                        let f = NumberFormatter()
                        f.minimumFractionDigits = 0
                        f.maximumFractionDigits = 0
                        return f
                    }()
                )
                Text("Lower values make gestures more sensitive. Higher values require longer swipes. Applies to both dock previews and window switcher.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
