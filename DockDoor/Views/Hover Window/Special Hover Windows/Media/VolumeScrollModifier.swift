import Defaults
import SwiftUI

struct MediaScrollModifier: ViewModifier {
    let bundleIdentifier: String
    @ObservedObject var mediaInfo: MediaInfo
    @State private var scrollMonitor: Any?
    @State private var seekDebounceWork: DispatchWorkItem?

    func body(content: Content) -> some View {
        content
            .onAppear { setupMonitor() }
            .onDisappear { removeMonitor() }
    }

    private func setupMonitor() {
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
        guard event.window != nil else { return }

        let isHorizontal = Defaults[.mediaWidgetScrollDirection] == .horizontal
        let delta: CGFloat = isHorizontal ? event.scrollingDeltaX : event.scrollingDeltaY
        guard abs(delta) > 0.5 else { return }

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
    }

    private func handleSeekScroll(deltaY: CGFloat) {
        if !mediaInfo.isSeeking {
            mediaInfo.isSeeking = true
            mediaInfo.seekBaseTime = mediaInfo.currentTime
            mediaInfo.seekAccumulatedDelta = 0
        }

        mediaInfo.seekAccumulatedDelta += deltaY * 0.5

        let newTime = max(0, min(mediaInfo.duration, mediaInfo.seekBaseTime + mediaInfo.seekAccumulatedDelta))
        mediaInfo.currentTime = newTime

        seekDebounceWork?.cancel()
        let work = DispatchWorkItem { [bundleIdentifier, mediaInfo] in
            let finalTime = mediaInfo.currentTime
            mediaInfo.isSeeking = false
            mediaInfo.seekAccumulatedDelta = 0

            let appName = bundleIdentifier == appleMusicAppIdentifier ? "Music" : "Spotify"

            let script = """
            tell application "\(appName)"
                if it is running then
                    try
                        set player position to \(finalTime)
                    end try
                end if
            end tell
            """

            OSAScriptRunner.shared.runFireAndForget(script)
        }
        seekDebounceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
    }
}

extension View {
    func mediaScrollable(bundleIdentifier: String, mediaInfo: MediaInfo) -> some View {
        modifier(MediaScrollModifier(bundleIdentifier: bundleIdentifier, mediaInfo: mediaInfo))
    }
}
