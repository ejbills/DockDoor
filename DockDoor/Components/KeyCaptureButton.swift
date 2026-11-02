import Carbon.HIToolbox.Events
import SwiftUI

struct KeyCaptureButton: View {
    @Binding var keyCode: UInt16
    var emptyLabel: String?
    var captureModifiers: Bool = false
    var allowsEscape: Bool = false

    @State private var isCapturing = false
    @State private var monitors: [Any] = []

    var body: some View {
        Button {
            if isCapturing {
                stopCapture()
            } else {
                startCapture()
            }
        } label: {
            Group {
                if isCapturing {
                    Text("Press a key…")
                        .foregroundStyle(Color.accentColor)
                } else {
                    Text(displayLabel)
                        .foregroundStyle(keyCode == 0 && emptyLabel != nil ? .secondary : .primary)
                }
            }
            .frame(minWidth: 36)
        }
        .buttonStyle(.settings)
        .onDisappear {
            stopCapture()
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
            if event.keyCode == UInt16(kVK_Escape), !allowsEscape {
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
