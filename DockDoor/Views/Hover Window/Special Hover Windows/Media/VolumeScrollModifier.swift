import Defaults
import SwiftUI

struct VolumeScrollModifier: ViewModifier {
    @State private var scrollMonitor: Any?

    func body(content: Content) -> some View {
        content
            .onAppear { setupMonitor() }
            .onDisappear { removeMonitor() }
    }

    private func setupMonitor() {
        guard Defaults[.enableDockScrollGesture],
              Defaults[.mediaScrollBehavior] == .adjustVolume
        else { return }

        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            handleScroll(event)
            return event
        }
    }

    private func removeMonitor() {
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
        }
    }

    private func handleScroll(_ event: NSEvent) {
        let deltaY = event.scrollingDeltaY
        guard abs(deltaY) > 0.5 else { return }

        let normalizedDeltaY = event.isDirectionInvertedFromDevice ? -deltaY : deltaY

        let sensitivity: Float = 0.008
        let current = AudioDeviceManager.getSystemVolume()
        let newVolume = max(0, min(1, current + Float(normalizedDeltaY) * sensitivity))
        AudioDeviceManager.setSystemVolume(newVolume)
    }
}

extension View {
    func volumeScrollable() -> some View {
        modifier(VolumeScrollModifier())
    }
}
