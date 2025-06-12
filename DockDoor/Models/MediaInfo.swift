import AppKit
import Foundation

@MainActor
class MediaInfo: ObservableObject {
    @Published var title: String = ""
    @Published var artist: String = ""
    @Published var album: String = ""
    @Published var artwork: NSImage?
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var appName: String = ""

    private var currentApp: String = ""
    var updateTimer: Timer?

    func fetchMediaInfo(for bundleIdentifier: String) async {
        currentApp = bundleIdentifier
        switch bundleIdentifier {
        case spotifyAppIdentifier:
            await fetchSpotifyInfo()
            appName = "Spotify"
        case appleMusicAppIdentifier:
            await fetchAppleMusicInfo()
            appName = "Music"
        default:
            clearMediaInfo()
        }
        startPeriodicUpdates()
    }

    private func startPeriodicUpdates() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshMediaInfo()
            }
        }
    }

    private func refreshMediaInfo() async {
        switch currentApp {
        case spotifyAppIdentifier:
            await fetchSpotifyInfo()
        case appleMusicAppIdentifier:
            await fetchAppleMusicInfo()
        default:
            break
        }
    }

    deinit {
        updateTimer?.invalidate()
    }

    private func fetchSpotifyInfo() async {
        let script = """
        tell application "Spotify"
            if it is running then
                try
                    set trackName to name of current track
                    set artistName to artist of current track
                    set albumName to album of current track
                    set playerState to player state as string
                    set currentPos to player position
                    set trackDuration to duration of current track
                    set artworkURL to artwork url of current track
                    return trackName & "|||" & artistName & "|||" & albumName & "|||" & playerState & "|||" & currentPos & "|||" & trackDuration & "|||" & artworkURL
                on error
                    return "error"
                end try
            else
                return "not_running"
            end if
        end tell
        """

        await executeAppleScript(script)
    }

    private func fetchAppleMusicInfo() async {
        let script = """
        tell application "Music"
            if it is running then
                try
                    set trackName to name of current track
                    set artistName to artist of current track
                    set albumName to album of current track
                    set playerState to player state as string
                    set currentPos to player position
                    set trackDuration to duration of current track
                    return trackName & "|||" & artistName & "|||" & albumName & "|||" & playerState & "|||" & currentPos & "|||" & trackDuration & "|||"
                on error
                    return "error"
                end try
            else
                return "not_running"
            end if
        end tell
        """

        await executeAppleScript(script)
    }

    private func executeAppleScript(_ script: String) async {
        let scriptResult: String? = await Task.detached(priority: .utility) {
            let appleScript = NSAppleScript(source: script)
            var errorDict: NSDictionary?
            let executionResult = appleScript?.executeAndReturnError(&errorDict)

            if let error = errorDict {
                print("AppleScript error: \(error)")
                return nil
            }
            return executionResult?.stringValue
        }.value

        guard let resultString = scriptResult else {
            return
        }

        if resultString == "not_running" || resultString == "error" {
            if resultString == "not_running" {
                clearMediaInfo()
            }
            return
        }

        let components = resultString.components(separatedBy: "|||")
        if components.count >= 6 {
            title = components[0]
            artist = components[1]
            album = components[2]
            isPlaying = components[3] == "playing"
            let newCurrentTime = Double(components[4]) ?? 0
            let rawDuration = Double(components[5]) ?? 0

            if rawDuration > 1000.0 {
                duration = rawDuration / 1000.0
            } else {
                duration = rawDuration
            }

            if newCurrentTime > 1000.0 {
                currentTime = newCurrentTime / 1000.0
            } else {
                currentTime = newCurrentTime
            }

            if components.count > 6, !components[6].isEmpty {
                await fetchArtworkFromURL(components[6])
            } else {
                await fetchArtwork()
            }
        }
    }

    private func fetchArtworkFromURL(_ urlString: String) async {
        guard let url = URL(string: urlString) else {
            await fetchArtwork()
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = NSImage(data: data) {
                artwork = image
            } else {
                await fetchArtwork()
            }
        } catch {
            await fetchArtwork()
        }
    }

    private func fetchArtwork() async {
        artwork = NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)
    }

    private func clearMediaInfo() {
        title = ""
        artist = ""
        album = ""
        artwork = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        appName = ""
        updateTimer?.invalidate()
        updateTimer = nil
    }

    func playPause() {
        let script: String
        switch currentApp {
        case spotifyAppIdentifier:
            script = "tell application \"Spotify\" to playpause"
        case appleMusicAppIdentifier:
            script = "tell application \"Music\" to playpause"
        default:
            return
        }

        Task {
            let appleScript = NSAppleScript(source: script)
            appleScript?.executeAndReturnError(nil)
            try? await Task.sleep(nanoseconds: 250_000_000)
            await refreshMediaInfo()
        }
    }

    func nextTrack() {
        let script: String
        switch currentApp {
        case spotifyAppIdentifier:
            script = "tell application \"Spotify\" to next track"
        case appleMusicAppIdentifier:
            script = "tell application \"Music\" to next track"
        default:
            return
        }

        Task {
            let appleScript = NSAppleScript(source: script)
            appleScript?.executeAndReturnError(nil)
            try? await Task.sleep(nanoseconds: 500_000_000)
            await refreshMediaInfo()
        }
    }

    func previousTrack() {
        let script: String
        switch currentApp {
        case spotifyAppIdentifier:
            script = "tell application \"Spotify\" to previous track"
        case appleMusicAppIdentifier:
            script = "tell application \"Music\" to previous track"
        default:
            return
        }

        Task {
            let appleScript = NSAppleScript(source: script)
            appleScript?.executeAndReturnError(nil)
            try? await Task.sleep(nanoseconds: 500_000_000)
            await refreshMediaInfo()
        }
    }

    func seek(to position: TimeInterval) {
        let script: String
        switch currentApp {
        case spotifyAppIdentifier:
            script = "tell application \"Spotify\" to set player position to \(position)"
        case appleMusicAppIdentifier:
            script = "tell application \"Music\" to set player position to \(position)"
        default:
            return
        }

        Task {
            let appleScript = NSAppleScript(source: script)
            appleScript?.executeAndReturnError(nil)
            currentTime = position
        }
    }
}
