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

    private static let delimiter = "〈♫DOCKDOOR♫〉"

    // MARK: - Public Methods

    func fetchMediaInfo(for bundleIdentifier: String) async {
        currentApp = bundleIdentifier

        switch bundleIdentifier {
        case spotifyAppIdentifier:
            appName = "Spotify"
        case appleMusicAppIdentifier:
            appName = "Music"
        default:
            clearMediaInfo()
            return
        }

        await fetchMediaData()
        startPeriodicUpdates()
    }

    func playPause() {
        executeMediaCommand("playpause")
    }

    func nextTrack() {
        executeMediaCommand("next track")
    }

    func previousTrack() {
        executeMediaCommand("previous track")
    }

    func seek(to position: TimeInterval) {
        let script = buildSeekScript(position: position)

        Task {
            let appleScript = NSAppleScript(source: script)
            appleScript?.executeAndReturnError(nil)
            currentTime = position
        }
    }

    // MARK: - Private Methods

    private func startPeriodicUpdates() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchMediaData()
            }
        }
    }

    private func fetchMediaData() async {
        guard !currentApp.isEmpty else { return }

        let script = buildMediaInfoScript()
        await executeAppleScript(script)
    }

    private func executeMediaCommand(_ command: String, delay: UInt64 = 250_000_000) {
        let script = buildMediaCommandScript(command: command)

        Task {
            let appleScript = NSAppleScript(source: script)
            appleScript?.executeAndReturnError(nil)
            try? await Task.sleep(nanoseconds: delay)
            await fetchMediaData()
        }
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

        guard let resultString = scriptResult else { return }

        if resultString == "not_running" {
            clearMediaInfo()
            return
        }

        if resultString == "error" {
            return
        }

        parseMediaInfo(from: resultString)
    }

    private func parseMediaInfo(from resultString: String) {
        let components = resultString.components(separatedBy: Self.delimiter)
        guard components.count >= 6 else { return }

        title = components[0]
        artist = components[1]
        album = components[2]
        isPlaying = components[3] == "playing"

        // Parse time values with locale-aware parsing
        currentTime = parseTimeValue(components[4])
        duration = parseTimeValue(components[5])

        // Handle artwork URL if present
        if components.count > 6, !components[6].isEmpty {
            Task {
                await fetchArtworkFromURL(components[6])
            }
        } else {
            Task {
                await setDefaultArtwork()
            }
        }
    }

    private func parseTimeValue(_ timeString: String) -> TimeInterval {
        // Handle different decimal separators (comma vs period)
        let normalizedString = timeString.replacingOccurrences(of: ",", with: ".")
        let timeValue = Double(normalizedString) ?? 0

        // Convert from milliseconds to seconds if needed
        return timeValue > 1000.0 ? timeValue / 1000.0 : timeValue
    }

    private func fetchArtworkFromURL(_ urlString: String) async {
        guard let url = URL(string: urlString) else {
            await setDefaultArtwork()
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = NSImage(data: data) {
                artwork = image
            } else {
                await setDefaultArtwork()
            }
        } catch {
            await setDefaultArtwork()
        }
    }

    private func setDefaultArtwork() async {
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

    // MARK: - Script Builders

    private func buildMediaInfoScript() -> String {
        """
        tell application "\(appName)"
            if it is running then
                try
                    set trackName to name of current track
                    set artistName to artist of current track
                    set albumName to album of current track
                    set playerState to player state as string
                    set currentPos to player position
                    set trackDuration to duration of current track
                    set artworkURL to artwork url of current track
                    return trackName & "\(Self.delimiter)" & artistName & "\(Self.delimiter)" & albumName & "\(Self.delimiter)" & playerState & "\(Self.delimiter)" & currentPos & "\(Self.delimiter)" & trackDuration & "\(Self.delimiter)" & artworkURL
                on error
                    return "error"
                end try
            else
                return "not_running"
            end if
        end tell
        """
    }

    private func buildMediaCommandScript(command: String) -> String {
        "tell application \"\(appName)\" to \(command)"
    }

    private func buildSeekScript(position: TimeInterval) -> String {
        "tell application \"\(appName)\" to set player position to \(position)"
    }

    deinit {
        updateTimer?.invalidate()
    }
}
