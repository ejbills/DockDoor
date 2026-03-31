import AppKit
import Combine
import Defaults
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
    @Published private(set) var elapsedTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0

    let trackInfoDidChange = PassthroughSubject<Void, Never>()

    private var lastTrackIdentifier: String = ""

    var hasActiveMedia: Bool { title.isEmpty == false }

    var isUniversalSource: Bool {
        guard let id = activeBundleIdentifier else { return false }
        return id != spotifyAppIdentifier && id != appleMusicAppIdentifier
    }

    private init() {}

    func start() {
        controller.onTrackInfoReceived = { [weak self] trackInfo in
            Task { @MainActor in
                self?.handleTrackInfo(trackInfo)
            }
        }
        controller.onPlaybackTimeUpdate = { [weak self] elapsed in
            Task { @MainActor in
                self?.elapsedTime = elapsed
            }
        }
        controller.startListening()
    }

    func stop() {
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
        controller.nextTrack()
    }

    func previousTrack() {
        controller.previousTrack()
    }

    func seek(to seconds: TimeInterval) {
        elapsedTime = seconds
        controller.setTime(seconds: seconds)
    }

    // MARK: - Private

    private func handleTrackInfo(_ trackInfo: TrackInfo?) {
        guard let payload = trackInfo?.payload else {
            clearState()
            return
        }

        activeBundleIdentifier = payload.bundleIdentifier
        activeAppName = payload.applicationName
        isPlaying = payload.isPlaying ?? false
        duration = (payload.durationMicros ?? 0) / 1_000_000.0

        let newIdentifier = payload.uniqueIdentifier
        let trackChanged = newIdentifier != lastTrackIdentifier
        lastTrackIdentifier = newIdentifier

        title = payload.title ?? ""
        artist = payload.artist ?? ""
        album = payload.album ?? ""

        if trackChanged {
            artwork = payload.artwork
        } else if let incoming = payload.artwork, artwork == nil {
            artwork = incoming
        }

        trackInfoDidChange.send()
    }

    private func clearState() {
        activeBundleIdentifier = nil
        activeAppName = nil
        title = ""
        artist = ""
        album = ""
        artwork = nil
        isPlaying = false
        elapsedTime = 0
        duration = 0
        lastTrackIdentifier = ""
    }
}
