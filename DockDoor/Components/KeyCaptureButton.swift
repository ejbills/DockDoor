import Carbon.HIToolbox.Events
import SwiftUI

struct KeyCaptureButton: View {
    @Binding var keyCode: UInt16
    var emptyLabel: String? = nil

    @State private var isCapturing = false
    @State private var keyMonitor: Any? = nil

    var body: some View {
        if isCapturing {
            Text("Press a key…")
                .font(.system(size: 12))
                .foregroundColor(.accentColor)
                .frame(minWidth: 50)
        } else {
            Button(action: startCapture) {
                Text(displayLabel)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(keyCode == 0 && emptyLabel != nil ? 0.1 : 0.2))
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
        }
    }

    private var displayLabel: String {
        if keyCode == 0, let emptyLabel {
            return emptyLabel
        }
        return KeyboardLabel.localizedKey(for: keyCode)
    }

    private func startCapture() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        isCapturing = true

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            defer {
                isCapturing = false
                if let monitor = keyMonitor {
                    NSEvent.removeMonitor(monitor)
                    keyMonitor = nil
                }
            }

            if event.keyCode == UInt16(kVK_Escape) { return nil }

            keyCode = event.keyCode
            return nil
        }
    }
}
