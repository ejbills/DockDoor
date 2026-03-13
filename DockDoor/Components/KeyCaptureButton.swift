import Carbon.HIToolbox.Events
import SwiftUI

struct KeyCaptureButton: View {
    @Binding var keyCode: UInt16
    var emptyLabel: String? = nil
    var captureModifiers: Bool = false

    @State private var isCapturing = false
    @State private var monitors: [Any] = []

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

    private func stopCapture() {
        isCapturing = false
        for monitor in monitors {
            NSEvent.removeMonitor(monitor)
        }
        monitors = []
    }

    private func startCapture() {
        stopCapture()
        isCapturing = true

        monitors.append(NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) {
                stopCapture()
                return nil
            }
            keyCode = event.keyCode
            stopCapture()
            return nil
        }!)

        if captureModifiers {
            monitors.append(NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
                let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
                if modifierKeyCodes.contains(event.keyCode) {
                    keyCode = event.keyCode
                    stopCapture()
                }
                return event
            }!)
        }
    }
}
