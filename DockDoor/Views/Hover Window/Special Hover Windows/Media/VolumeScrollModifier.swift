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
            // `hitTestView` is populated asynchronously by ScrollHitTestHelper, so it's nil at
            // onAppear; onChange carries the resolved view into the registration. Resetting it on
            // disappear guarantees this fires again on every reappearance, even if SwiftUI reuses
            // the same NSView.
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

/// One live media view's claim on the spacebar shortcut. `hostView` resolves the preview
/// window the media is rendered in, so the coordinator can scope the shortcut per preview.
final class MediaShortcutRegistration: Hashable {
    let mediaInfo: MediaInfo
    weak var hostView: NSView?

    init(mediaInfo: MediaInfo) {
        self.mediaInfo = mediaInfo
    }

    static func == (lhs: MediaShortcutRegistration, rhs: MediaShortcutRegistration) -> Bool {
        lhs === rhs
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

/// Tracks the media views currently on screen and resolves the spacebar play/pause shortcut.
///
/// The decision runs from the global key event tap in `KeybindHelper` (on the main thread) so
/// the spacebar can be *consumed* — otherwise it would also reach the focused app and, when
/// that app is the media player, double-toggle playback. The shortcut acts only when a single
/// preview is on screen rendering exactly one distinct media source; two apps within one
/// preview (or several previews) is ambiguous, so it's left alone and the key passes through.
final class MediaKeyboardShortcutCoordinator {
    static let shared = MediaKeyboardShortcutCoordinator()

    private var registrations: Set<MediaShortcutRegistration> = []

    private init() {}

    func register(_ mediaInfo: MediaInfo) -> MediaShortcutRegistration {
        let registration = MediaShortcutRegistration(mediaInfo: mediaInfo)
        registrations.insert(registration)
        return registration
    }

    func unregister(_ registration: MediaShortcutRegistration) {
        registrations.remove(registration)
    }

    /// Called for a bare spacebar key-down from the global event tap. Returns `true` when an
    /// unambiguous media preview handled it, signalling the caller to consume the event. The
    /// toggle is hopped to the main actor since `MediaInfo` is main-actor isolated.
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

    /// The single media source to control, or `nil` when the target is ambiguous: the visible
    /// media views must all live in one preview window and resolve to one distinct source.
    private func unambiguousVisibleSource() -> MediaInfo? {
        var windowID: ObjectIdentifier?
        var sources: Set<ObjectIdentifier> = []
        var source: MediaInfo?

        for registration in registrations {
            guard let window = registration.hostView?.window else { continue }

            let id = ObjectIdentifier(window)
            if windowID == nil { windowID = id }
            guard windowID == id else { return nil } // spans multiple previews

            sources.insert(ObjectIdentifier(registration.mediaInfo))
            guard sources.count == 1 else { return nil } // multiple apps in one preview
            source = registration.mediaInfo
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
