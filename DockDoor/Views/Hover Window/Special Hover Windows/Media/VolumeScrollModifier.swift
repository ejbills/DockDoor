import Defaults
import SwiftUI

struct MediaScrollModifier: ViewModifier {
    let bundleIdentifier: String
    @ObservedObject var mediaInfo: MediaInfo
    @State private var scrollMonitor: Any?
    @State private var seekDebounceWork: DispatchWorkItem?
    @State private var hitTestView: NSView?
    @State private var shortcutRegistration: MediaShortcutRegistration?

    func body(content: Content) -> some View {
        content
            .background(ScrollHitTestHelper(view: $hitTestView))
            .onAppear {
                setupMonitor()
                shortcutRegistration = MediaKeyboardShortcutCoordinator.shared.register(mediaInfo)
            }
            // hitTestView resolves asynchronously after onAppear, and is reset on disappear so this refires even when SwiftUI reuses the NSView.
            .onChange(of: hitTestView) { newView in
                shortcutRegistration?.hostView = newView
            }
            .onDisappear {
                removeMonitor()
                hitTestView = nil
                if let shortcutRegistration {
                    MediaKeyboardShortcutCoordinator.shared.unregister(shortcutRegistration)
                    self.shortcutRegistration = nil
                }
            }
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

/// One live media view's claim on the spacebar shortcut; `hostView` resolves which preview window it's rendered in.
final class MediaShortcutRegistration {
    let mediaInfo: MediaInfo
    weak var hostView: NSView?

    init(mediaInfo: MediaInfo) {
        self.mediaInfo = mediaInfo
    }
}

/// Tracks on-screen media views and toggles play/pause from the spacebar, but only when a single visible preview resolves to one distinct media source.
final class MediaKeyboardShortcutCoordinator {
    static let shared = MediaKeyboardShortcutCoordinator()

    private var registrations: [MediaShortcutRegistration] = []

    private init() {}

    func register(_ mediaInfo: MediaInfo) -> MediaShortcutRegistration {
        let registration = MediaShortcutRegistration(mediaInfo: mediaInfo)
        registrations.append(registration)
        return registration
    }

    func unregister(_ registration: MediaShortcutRegistration) {
        registrations.removeAll { $0 === registration }
    }

    /// Returns `true` when a media preview handled the spacebar, signalling the event tap to consume the event.
    func handleSpaceKeyDown() -> Bool {
        guard let mediaInfo = unambiguousVisibleSource() else { return false }

        Task { @MainActor in
            withAnimation(Defaults[.showAnimations] ? .easeInOut(duration: 0.2) : nil) {
                mediaInfo.isPlaying.toggle()
            }
            mediaInfo.playPause()
        }
        return true
    }

    /// The single media source to control, or `nil` when the target is ambiguous (multiple previews, or multiple sources in one preview).
    private func unambiguousVisibleSource() -> MediaInfo? {
        var window: NSWindow?
        var source: MediaInfo?

        for registration in registrations {
            guard let hostWindow = registration.hostView?.window else { continue }

            if window == nil { window = hostWindow }
            guard window === hostWindow else { return nil }

            if source == nil { source = registration.mediaInfo }
            guard source === registration.mediaInfo else { return nil }
        }

        return source
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
