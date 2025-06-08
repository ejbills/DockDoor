import AVKit
import SwiftUI

struct AirPlayPickerView: NSViewRepresentable {
    func makeNSView(context: Context) -> AVRoutePickerView {
        let routePickerView = AVRoutePickerView()
        // On macOS, AVRoutePickerView typically presents as an icon button
        // that shows a popover with route choices.
        // Set content hugging priority to allow it to size itself appropriately.
        routePickerView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        routePickerView.setContentHuggingPriority(.defaultHigh, for: .vertical)

        routePickerView.isRoutePickerButtonBordered = false

        return routePickerView
    }

    func updateNSView(_ nsView: AVRoutePickerView, context: Context) {
        // No specific updates needed from SwiftUI side for now.
    }
}
