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

    /// After a seek, we interpolate locally until the next track info event arrives.
    private var seekBase: (position: TimeInterval, date: Date, rate: Double)?

    var interpolatedElapsedTime: TimeInterval {
        if let seek = seekBase,
           let seekTime = lastSeekTime,
           Date().timeIntervalSince(seekTime) < seekDebounceInterval
        {
            let elapsed = Date().timeIntervalSince(seek.date)
            return max(0, seek.position + elapsed * seek.rate)
        }
        return currentTrackInfo?.payload.currentElapsedTime ?? 0
    }

    var hasActiveMedia: Bool { !title.isEmpty }

    var isUniversalSource: Bool {
        guard let id = activeBundleIdentifier else { return false }
        return id != spotifyAppIdentifier && id != appleMusicAppIdentifier
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
        controller.togglePlayPause()
    }

    func play() {
        controller.play()
    }

    func pause() {
        controller.pause()
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
            currentTrackInfo = nil
            seekBase = nil
            clearState()
            return
        }

        currentTrackInfo = trackInfo
        let payload = trackInfo.payload

        let incomingRate = payload.playbackRate ?? ((payload.isPlaying ?? false) ? 1.0 : 0.0)
        let incomingDuration = (payload.durationMicros ?? 0) / 1_000_000.0
        let incomingElapsed = payload.currentElapsedTime ?? 0

        let shouldIgnorePosition = lastSeekTime.map { Date().timeIntervalSince($0) < seekDebounceInterval } ?? false
        if !shouldIgnorePosition {
            seekBase = nil
        }

        let sameSource = payload.bundleIdentifier == activeBundleIdentifier
        let sameTrack = sameSource && payload.title == title && payload.artist == artist
        let resolvedArtwork: NSImage? = if let incoming = payload.artwork {
            incoming
        } else if sameTrack || sameSource {
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
            isPlaying = incomingRate > 0
            duration = incomingDuration
            artwork = resolvedArtwork
        } else if incomingRate != playbackRate {
            playbackRate = incomingRate
            isPlaying = incomingRate > 0
        }

        if !shouldIgnorePosition {
            elapsedTime = incomingElapsed
        }

        trackInfoDidChange.send()
    }

    private func clearState() {
        currentTrackInfo = nil
        seekBase = nil
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
