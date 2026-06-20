import AppKit
import Combine
import Foundation
import MediaRemoteAdapter

final class MediaRemoteService: ObservableObject {
    static let shared = MediaRemoteService()

    private let controller = MediaController()

    @Published private(set) var activeBundleIdentifier: String?
    @Published private(set) var activeAppName: String?
    @Published private(set) var title: String = ""
    @Published private(set) var artist: String = ""
    @Published private(set) var album: String = ""
    @Published private(set) var artwork: NSImage?
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var playbackRate: Double = 0
    @Published private(set) var elapsedTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0

    let trackInfoDidChange = PassthroughSubject<Void, Never>()

    private var isActive = false
    private var lastSeekTime: Date?
    private let seekDebounceInterval: TimeInterval = 1.5

    private var currentTrackInfo: TrackInfo?

    /// After a seek or pause, we interpolate locally instead of trusting the feed's reported
    /// position, which is briefly unreliable around transitions. A moving base (rate > 0) is honored
    /// only until `seekDebounceInterval` lapses; a paused base (rate 0) is held until playback
    /// resumes, since the feed's paused elapsed stays unreliable (it reports 0 or stale values).
    private var seekBase: (position: TimeInterval, date: Date, rate: Double)?

    /// After we issue a play/pause, the feed emits a few events still carrying the previous state.
    /// We record the state we asked for and ignore contradicting reports until the feed confirms it
    /// (or `seekDebounceInterval` lapses).
    private var playbackIntent: (isPlaying: Bool, date: Date)?

    var interpolatedElapsedTime: TimeInterval {
        if let seek = seekBase, seek.rate == 0 || isWithinSeekWindow {
            return max(0, seek.position + Date().timeIntervalSince(seek.date) * seek.rate)
        }
        return currentTrackInfo?.payload.currentElapsedTime ?? 0
    }

    private var isWithinSeekWindow: Bool {
        lastSeekTime.map { Date().timeIntervalSince($0) < seekDebounceInterval } ?? false
    }

    var hasActiveMedia: Bool { !title.isEmpty }

    var isUniversalSource: Bool {
        guard let id = activeBundleIdentifier else { return false }
        return id != spotifyAppIdentifier && id != appleMusicAppIdentifier
    }

    func matchesMediaSource(bundleIdentifier: String?) -> Bool {
        guard hasActiveMedia, let bundleIdentifier else { return false }

        if activeBundleIdentifier == bundleIdentifier {
            return true
        }

        if normalizedContains(activeBundleIdentifier, bundleIdentifier) ||
            normalizedContains(bundleIdentifier, activeBundleIdentifier)
        {
            return true
        }

        guard let dockAppName = appDisplayName(for: bundleIdentifier) else {
            return false
        }
        return normalizedContains(activeAppName, dockAppName) ||
            normalizedContains(dockAppName, activeAppName)
    }

    private init() {
        setupController()
    }

    private func setupController() {
        controller.onTrackInfoReceived = { [weak self] trackInfo in
            DispatchQueue.main.async {
                self?.handleTrackInfo(trackInfo)
            }
        }
    }

    func activate() {
        guard !isActive else { return }
        isActive = true
        controller.startListening()
    }

    func deactivate() {
        guard isActive else { return }
        isActive = false
        controller.stopListening()
    }

    // MARK: - Playback Controls

    func togglePlayPause() {
        beginPlaybackIntent(targetIsPlaying: !isPlaying)
        controller.togglePlayPause()
    }

    func play() {
        beginPlaybackIntent(targetIsPlaying: true)
        controller.play()
    }

    func pause() {
        beginPlaybackIntent(targetIsPlaying: false)
        controller.pause()
    }

    /// Optimistically applies a play/pause: records the expected state and pins the elapsed time so
    /// the feed's transient transition events don't flicker the state or jump the time.
    private func beginPlaybackIntent(targetIsPlaying: Bool) {
        let now = Date()
        let rate = targetIsPlaying ? (playbackRate > 0 ? playbackRate : 1.0) : 0.0
        playbackIntent = (isPlaying: targetIsPlaying, date: now)
        lastSeekTime = now
        seekBase = (position: interpolatedElapsedTime, date: now, rate: rate)
        isPlaying = targetIsPlaying
        playbackRate = rate
    }

    func nextTrack() {
        elapsedTime = 0
        controller.nextTrack()
    }

    func previousTrack() {
        elapsedTime = 0
        controller.previousTrack()
    }

    func seek(to seconds: TimeInterval) {
        let now = Date()
        lastSeekTime = now
        seekBase = (position: seconds, date: now, rate: playbackRate)
        elapsedTime = seconds
        controller.setTime(seconds: seconds)
    }

    // MARK: - Private

    private func handleTrackInfo(_ trackInfo: TrackInfo?) {
        guard let trackInfo else {
            clearState()
            return
        }

        let payload = trackInfo.payload
        let priorElapsed = interpolatedElapsedTime // capture before currentTrackInfo updates
        currentTrackInfo = trackInfo

        // Trust the explicit isPlaying flag: on the first pause event the player still reports a
        // playbackRate of 1.0, so deriving the state from the rate would misread a pause as playing.
        var incomingIsPlaying = payload.isPlaying ?? ((payload.playbackRate ?? 0) > 0)
        var incomingRate = incomingIsPlaying ? (payload.playbackRate ?? 1.0) : 0.0
        let incomingDuration = (payload.durationMicros ?? 0) / 1_000_000.0
        let incomingElapsed = payload.currentElapsedTime ?? 0

        // While a play/pause we issued is settling, ignore reports that contradict it; accept and
        // clear the intent once the feed confirms it (or the window lapses).
        if let intent = playbackIntent {
            if incomingIsPlaying == intent.isPlaying || Date().timeIntervalSince(intent.date) >= seekDebounceInterval {
                playbackIntent = nil
            } else {
                incomingIsPlaying = isPlaying
                incomingRate = playbackRate
            }
        }

        let sameSource = payload.bundleIdentifier == activeBundleIdentifier
        let sameTrack = sameSource && payload.title == title && payload.artist == artist

        // Hold the pre-pause position while paused (the feed's paused elapsed is unreliable); clear
        // the hold on resume so the live position flows again. Our own commands seed this above.
        if incomingIsPlaying {
            if seekBase?.rate == 0 { seekBase = nil }
        } else if isPlaying, sameTrack {
            lastSeekTime = Date()
            seekBase = (position: priorElapsed, date: Date(), rate: 0)
        }

        let shouldIgnorePosition = seekBase?.rate == 0 || isWithinSeekWindow
        if !shouldIgnorePosition {
            seekBase = nil
        }

        let resolvedArtwork: NSImage? = if let incoming = payload.artwork {
            incoming
        } else if sameTrack {
            artwork
        } else {
            nil
        }

        let metadataChanged = payload.title != title ||
            payload.artist != artist ||
            payload.album != album ||
            payload.applicationName != activeAppName ||
            payload.bundleIdentifier != activeBundleIdentifier ||
            incomingDuration != duration ||
            incomingRate != playbackRate ||
            resolvedArtwork !== artwork

        if metadataChanged {
            activeBundleIdentifier = payload.bundleIdentifier
            activeAppName = payload.applicationName
            title = payload.title ?? ""
            artist = payload.artist ?? ""
            album = payload.album ?? ""
            playbackRate = incomingRate
            isPlaying = incomingIsPlaying
            duration = incomingDuration
            artwork = resolvedArtwork
        } else if incomingRate != playbackRate {
            playbackRate = incomingRate
            isPlaying = incomingIsPlaying
        }

        if !shouldIgnorePosition {
            elapsedTime = incomingElapsed
        }

        trackInfoDidChange.send()
    }

    private func normalizedContains(_ haystack: String?, _ needle: String?) -> Bool {
        guard let haystack, let needle else { return false }
        let normalizedHaystack = haystack.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedNeedle = needle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedHaystack.isEmpty, !normalizedNeedle.isEmpty else { return false }
        return normalizedHaystack.contains(normalizedNeedle)
    }

    private func appDisplayName(for bundleIdentifier: String) -> String? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
            .flatMap { Bundle(url: $0) }
            .flatMap {
                $0.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
                    $0.object(forInfoDictionaryKey: "CFBundleName") as? String
            }
    }

    private func clearState() {
        currentTrackInfo = nil
        seekBase = nil
        playbackIntent = nil
        activeBundleIdentifier = nil
        activeAppName = nil
        title = ""
        artist = ""
        album = ""
        artwork = nil
        isPlaying = false
        playbackRate = 0
        elapsedTime = 0
        duration = 0
    }
}
