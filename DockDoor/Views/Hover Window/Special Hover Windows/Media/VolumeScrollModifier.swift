import Defaults
import SwiftUI

struct MediaScrollModifier: ViewModifier {
    let bundleIdentifier: String
    @ObservedObject var mediaInfo: MediaInfo
    @State private var scrollMonitor: Any?
    @State private var seekDebounceWork: DispatchWorkItem?
    @State private var hitTestView: NSView?

    func body(content: Content) -> some View {
        content
            .background(ScrollHitTestHelper(view: $hitTestView))
            .onAppear { setupMonitor() }
            .onDisappear { removeMonitor() }
    }

    private func setupMonitor() {
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            handleScroll(event) ? nil : event
        }
    }

    private func removeMonitor() {
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
        }
    }

    @discardableResult
    private func handleScroll(_ event: NSEvent) -> Bool {
        guard let hitTestView,
              let viewWindow = hitTestView.window,
              event.window == viewWindow else { return false }

        let locationInView = hitTestView.convert(event.locationInWindow, from: nil)
        guard hitTestView.bounds.contains(locationInView) else { return false }

        let isHorizontal = Defaults[.mediaWidgetScrollDirection] == .horizontal
        let delta: CGFloat = isHorizontal ? event.scrollingDeltaX : event.scrollingDeltaY
        guard abs(delta) > 0.5 else { return false }

        let normalizedDelta: CGFloat = if isHorizontal {
            event.isDirectionInvertedFromDevice ? delta : -delta
        } else {
            event.isDirectionInvertedFromDevice ? -delta : delta
        }

        switch Defaults[.mediaWidgetScrollBehavior] {
        case .adjustVolume:
            let sensitivity: Float = 0.008
            let current = AudioDeviceManager.getSystemVolume()
            let newVolume = max(0, min(1, current + Float(normalizedDelta) * sensitivity))
            AudioDeviceManager.setSystemVolume(newVolume)
        case .seekPlayback:
            handleSeekScroll(deltaY: normalizedDelta)
        }

        return true
    }

    private func handleSeekScroll(deltaY: CGFloat) {
        if !mediaInfo.isSeeking {
            mediaInfo.isSeeking = true
            mediaInfo.seekBaseTime = mediaInfo.displayTime
            mediaInfo.seekAccumulatedDelta = 0
        }

        mediaInfo.seekAccumulatedDelta += deltaY * 0.5

        let newTime = max(0, min(mediaInfo.duration, mediaInfo.seekBaseTime + mediaInfo.seekAccumulatedDelta))
        mediaInfo.currentTime = newTime

        seekDebounceWork?.cancel()
        let work = DispatchWorkItem { [mediaInfo] in
            let finalTime = mediaInfo.currentTime
            mediaInfo.isSeeking = false
            mediaInfo.seekAccumulatedDelta = 0
            mediaInfo.seek(to: finalTime)
        }
        seekDebounceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
    }
}

private struct ScrollHitTestHelper: NSViewRepresentable {
    @Binding var view: NSView?

    func makeNSView(context: Context) -> NSView {
        let nsView = NSView()
        DispatchQueue.main.async { view = nsView }
        return nsView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if view !== nsView {
            DispatchQueue.main.async { view = nsView }
        }
    }
}

extension View {
    func mediaScrollable(bundleIdentifier: String, mediaInfo: MediaInfo) -> some View {
        modifier(MediaScrollModifier(bundleIdentifier: bundleIdentifier, mediaInfo: mediaInfo))
    }
}
