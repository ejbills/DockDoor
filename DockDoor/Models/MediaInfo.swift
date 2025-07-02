import AppKit
import Foundation

// NOTE: Borrows code from: https://github.com/aviwad/LyricFever

// MARK: - Lyric Data Structures

struct LyricLine: Identifiable, Hashable {
    let id = UUID()
    let startTime: TimeInterval
    let words: String

    var startTimeMS: TimeInterval {
        startTime * 1000
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: LyricLine, rhs: LyricLine) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - MusicBrainz Data Structures

struct MusicBrainzRecordingSearch: Codable {
    let recordings: [MusicBrainzRecording]
}

struct MusicBrainzRecording: Codable {
    let id: String
    let title: String
    let score: Int
    let releases: [MusicBrainzRelease]?

    enum CodingKeys: String, CodingKey {
        case id, title, score, releases = "release-list"
    }
}

struct MusicBrainzRelease: Codable {
    let id: String
    let title: String
}

struct LyricsOVHResponse: Codable {
    let lyrics: String
}

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

    // MARK: - Lyrics Properties

    @Published var lyrics: [LyricLine] = []
    @Published var currentLyricIndex: Int?
    @Published var isLoadingLyrics: Bool = false
    @Published var hasLyrics: Bool = false

    private var currentApp: String = ""
    var updateTimer: Timer?

    // MARK: - Lyrics Timer

    private var lyricsTimer: Timer?
    private var currentFetchTask: Task<[LyricLine], Error>?
    private var lastFetchedTrack: String = "" // Track to prevent duplicate fetches

    // MARK: - Timing Synchronization

    private var lastPolledTime: TimeInterval = 0
    private var lastPollDate: Date = .init()
    private var interpolatedTime: TimeInterval = 0

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

            // Reset interpolation timing after seeking
            lastPolledTime = position
            lastPollDate = Date()
            interpolatedTime = position

            updateCurrentLyricIndex()
        }
    }

    // MARK: - Lyrics Methods

    func fetchLyrics() async {
        let trackKey = "\(title)-\(artist)"

        guard !title.isEmpty, !artist.isEmpty else {
            clearLyrics()
            return
        }

        // Prevent duplicate fetches for the same track
        guard trackKey != lastFetchedTrack || lyrics.isEmpty else {
            return
        }

        // Cancel any existing fetch task
        currentFetchTask?.cancel()

        // Wait a moment to let any pending cancellations complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second

        isLoadingLyrics = true
        lastFetchedTrack = trackKey

        let fetchTask = Task {
            try await self.fetchLyricsFromNetwork()
        }

        currentFetchTask = fetchTask

        do {
            let fetchedLyrics = try await fetchTask.value
            lyrics = fetchedLyrics
            hasLyrics = !lyrics.isEmpty
            isLoadingLyrics = false

            if hasLyrics {
                startLyricsTimer()
                startPeriodicUpdates() // Restart with higher frequency
            }
        } catch {
            if !Task.isCancelled {
                clearLyrics()
            }
        }
    }

    func fetchLyricsIfNeeded(lyricsMode: Bool) async {
        guard lyricsMode else { return }
        await fetchLyrics()
    }

    private func fetchLyricsFromNetwork() async throws -> [LyricLine] {
        // Validate input before making any requests
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw NSError(domain: "LyricsError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid track info"])
        }

        // First try LRCLIB for synced lyrics (most reliable)
        do {
            let lrcLyrics = try await fetchFromLRCLIB()
            return lrcLyrics
        } catch {
            print("LRCLIB failed: \(error)")
        }

        // Then try LyricsOVH for simple lyrics
        do {
            let simpleLyrics = try await fetchFromLyricsOVH()
            return simpleLyrics
        } catch {
            print("LyricsOVH failed: \(error)")
        }
        return []
    }

    private func fetchFromLyricsOVH() async throws -> [LyricLine] {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanTitle.isEmpty, !cleanArtist.isEmpty else {
            throw NSError(domain: "LyricsError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Empty title or artist"])
        }

        let encodedArtist = cleanArtist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedTitle = cleanTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        guard let url = URL(string: "https://api.lyrics.ovh/v1/\(encodedArtist)/\(encodedTitle)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("DockDoor v1.0 (https://github.com/ethanbills/DockDoor)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10.0

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "LyricsError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "LyricsError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No lyrics found - HTTP \(httpResponse.statusCode)"])
        }

        let lyricsResponse = try JSONDecoder().decode(LyricsOVHResponse.self, from: data)

        // Convert plain lyrics to LyricLine objects with estimated timing
        return convertPlainLyricsToTimedLines(lyricsResponse.lyrics)
    }

    private func fetchFromLRCLIB() async throws -> [LyricLine] {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAlbum = album.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanTitle.isEmpty, !cleanArtist.isEmpty else {
            throw NSError(domain: "LyricsError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Empty title or artist"])
        }

        let encodedTitle = cleanTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedArtist = cleanArtist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedAlbum = cleanAlbum.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        guard let url = URL(string: "https://lrclib.net/api/get?artist_name=\(encodedArtist)&track_name=\(encodedTitle)&album_name=\(encodedAlbum)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("DockDoor v1.0 (https://github.com/ethanbills/DockDoor)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10.0

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "LyricsError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No synced lyrics available"])
        }

        let lrcResponse = try JSONDecoder().decode(LRCLyrics.self, from: data)

        guard let syncedLyrics = lrcResponse.syncedLyrics, !syncedLyrics.isEmpty else {
            throw NSError(domain: "LyricsError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No synced lyrics available"])
        }

        return parseLRCLyrics(syncedLyrics)
    }

    private func parseLRCLyrics(_ lrcString: String) -> [LyricLine] {
        let lines = lrcString.components(separatedBy: .newlines)
        var lyrics: [LyricLine] = []

        let timeRegex = try! NSRegularExpression(pattern: "\\[(\\d{2}):(\\d{2})\\.(\\d{2})\\](.+)", options: [])

        for line in lines {
            let range = NSRange(location: 0, length: line.utf16.count)
            if let match = timeRegex.firstMatch(in: line, options: [], range: range) {
                let minutesRange = Range(match.range(at: 1), in: line)!
                let secondsRange = Range(match.range(at: 2), in: line)!
                let millisecondsRange = Range(match.range(at: 3), in: line)!
                let textRange = Range(match.range(at: 4), in: line)!

                let minutes = Int(line[minutesRange]) ?? 0
                let seconds = Int(line[secondsRange]) ?? 0
                let milliseconds = Int(line[millisecondsRange]) ?? 0
                let text = String(line[textRange]).trimmingCharacters(in: .whitespaces)

                if !text.isEmpty {
                    let timeInterval = TimeInterval(minutes * 60 + seconds) + TimeInterval(milliseconds) / 100.0
                    lyrics.append(LyricLine(startTime: timeInterval, words: text))
                }
            }
        }

        return lyrics.sorted { $0.startTime < $1.startTime }
    }

    private func stringSimilarity(_ str1: String, _ str2: String) -> Double {
        let s1 = str1.lowercased()
        let s2 = str2.lowercased()

        if s1 == s2 { return 1.0 }
        if s1.isEmpty || s2.isEmpty { return 0.0 }

        let maxLen = max(s1.count, s2.count)
        let distance = levenshteinDistance(s1, s2)

        return 1.0 - (Double(distance) / Double(maxLen))
    }

    private func levenshteinDistance(_ str1: String, _ str2: String) -> Int {
        let s1 = Array(str1)
        let s2 = Array(str2)
        let m = s1.count
        let n = s2.count

        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)

        for i in 0 ... m {
            dp[i][0] = i
        }

        for j in 0 ... n {
            dp[0][j] = j
        }

        for i in 1 ... m {
            for j in 1 ... n {
                if s1[i - 1] == s2[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1]
                } else {
                    dp[i][j] = 1 + min(dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1])
                }
            }
        }

        return dp[m][n]
    }

    private func startLyricsTimer() {
        lyricsTimer?.invalidate()

        lyricsTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateInterpolatedTime()
                self?.updateCurrentLyricIndex()
            }
        }
    }

    private func updateInterpolatedTime() {
        guard isPlaying else {
            interpolatedTime = currentTime
            return
        }

        let now = Date()
        let timeSinceLastPoll = now.timeIntervalSince(lastPollDate)

        // Only interpolate if the last poll was recent (within 2 seconds)
        if timeSinceLastPoll < 2.0 {
            interpolatedTime = lastPolledTime + timeSinceLastPoll
        } else {
            interpolatedTime = currentTime
        }
    }

    private func updateCurrentLyricIndex() {
        guard hasLyrics, !lyrics.isEmpty else {
            currentLyricIndex = nil
            return
        }

        let currentTimeSeconds = interpolatedTime

        // Find the current lyric line with improved timing calculation
        var newIndex: Int?

        for (index, lyric) in lyrics.enumerated() {
            if currentTimeSeconds >= lyric.startTime {
                newIndex = index
            } else {
                break
            }
        }

        if currentLyricIndex != newIndex {
            currentLyricIndex = newIndex
        }
    }

    private func clearLyrics() {
        lyrics = []
        currentLyricIndex = nil
        hasLyrics = false
        isLoadingLyrics = false
        lyricsTimer?.invalidate()
        lyricsTimer = nil
        lastFetchedTrack = ""

        // Reset timing interpolation
        lastPolledTime = currentTime
        lastPollDate = Date()
        interpolatedTime = currentTime

        // Restart with slower polling frequency
        if !currentApp.isEmpty {
            startPeriodicUpdates()
        }
    }

    // MARK: - Private Methods

    private func startPeriodicUpdates() {
        updateTimer?.invalidate()

        // Use more frequent updates when lyrics are active for better sync
        let updateInterval: TimeInterval = hasLyrics ? 0.5 : 1.0

        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
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
        guard components.count >= 6 else {
            return
        }

        let newTitle = components[0]
        let newArtist = components[1]
        let newAlbum = components[2]

        // Check if track changed
        let trackChanged = newTitle != title || newArtist != artist || newAlbum != album

        if trackChanged {
            clearLyrics()
        }

        title = newTitle
        artist = newArtist
        album = newAlbum
        isPlaying = components[3] == "playing"

        // Parse time values with locale-aware parsing
        let newCurrentTime = parseTimeValue(components[4])

        // Update timing tracking for interpolation
        if abs(newCurrentTime - currentTime) > 0.5 || !isPlaying {
            // Significant time change or not playing - reset interpolation
            lastPolledTime = newCurrentTime
            lastPollDate = Date()
            interpolatedTime = newCurrentTime
        } else {
            // Small change - just update the baseline
            lastPolledTime = newCurrentTime
            lastPollDate = Date()
        }

        currentTime = newCurrentTime
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
        clearLyrics()
    }

    // MARK: - Script Builders

    private func buildMediaInfoScript() -> String {
        let artworkScript = appName == "Music" ? """
        try
            set artData to data of artwork 1 of current track
            set tempPath to "/tmp/aw.jpg"
            set fileRef to open for access tempPath with write permission
            set eof fileRef to 0
            write artData to fileRef
            close access fileRef
            set base64String to do shell script "base64 -i /tmp/aw.jpg | tr -d '\\n'"
            set artworkURLString to "data:image/jpeg;base64," & base64String
        on error
            set artworkURLString to ""
        end try
        try
            do shell script "rm /tmp/aw.jpg 2>/dev/null"
        end try
        """ : "set artworkURLString to artwork url of current track"

        return """
        tell application "\(appName)"
            if it is running then
                try
                    set trackName to name of current track
                    set artistName to artist of current track
                    set albumName to album of current track
                    set playerState to player state as string
                    set currentPos to player position
                    set trackDuration to duration of current track

                    set artworkURLString to ""
                    try
                        \(artworkScript)
                    on error
                    end try

                    return trackName & "\(Self.delimiter)" & artistName & "\(Self.delimiter)" & albumName & "\(Self.delimiter)" & playerState & "\(Self.delimiter)" & currentPos & "\(Self.delimiter)" & trackDuration & "\(Self.delimiter)" & artworkURLString
                on error errMsg
                    if errMsg contains "Can't get current track" or errMsg contains "-1728" or errMsg contains "Can't get artwork url" then
                        return "no_library_track_info"
                    end if
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

    private func convertPlainLyricsToTimedLines(_ plainLyrics: String) -> [LyricLine] {
        let lines = plainLyrics.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return [] }

        // Estimate timing based on song duration
        let songDuration = max(duration, 180) // Default to 3 minutes if unknown
        let timePerLine = songDuration / Double(lines.count)

        var lyricLines: [LyricLine] = []

        for (index, line) in lines.enumerated() {
            let startTime = Double(index) * timePerLine
            lyricLines.append(LyricLine(startTime: startTime, words: line))
        }

        return lyricLines
    }

    deinit {
        updateTimer?.invalidate()
        lyricsTimer?.invalidate()
        currentFetchTask?.cancel()
    }
}

// MARK: - NetEase Data Structures (kept for fallback)

struct LRCLyrics: Codable {
    let syncedLyrics: String?
    let plainLyrics: String?

    private enum CodingKeys: String, CodingKey {
        case syncedLyrics, plainLyrics
    }
}

struct NetEaseSearch: Codable {
    let result: NetEaseSearchResult
}

struct NetEaseSearchResult: Codable {
    let songs: [NetEaseSong]
}

struct NetEaseSong: Codable {
    let id: Int
    let name: String
    let artists: [NetEaseArtist]
    let album: NetEaseAlbum
}

struct NetEaseArtist: Codable {
    let name: String
}

struct NetEaseAlbum: Codable {
    let name: String
}

struct NetEaseLyrics: Codable {
    let lrc: NetEaseLyric?
}

struct NetEaseLyric: Codable {
    let lyric: String?
}
