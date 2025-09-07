import AppKit
import Foundation
import SwiftUI

// Media store that holds all media data and handles actions
@MainActor
final class MediaStore: ObservableObject {
    @Published var title: String = ""
    @Published var artist: String = ""
    @Published var album: String = ""
    @Published var artwork: NSImage?
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var appName: String = ""

    private let actions: [String: String]?

    init(actions: [String: String]?) {
        self.actions = actions
    }

    func updateFromContext(_ context: [String: String]) {
        if let v = context["media.title"], v != title { title = v }
        if let v = context["media.artist"], v != artist { artist = v }
        if let v = context["media.album"], v != album { album = v }

        if let s = context["media.state"] {
            let playing = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "playing"
            if playing != isPlaying { isPlaying = playing }
        }

        if let tStr = context["media.currentTime"],
           let t = TimeInterval(tStr.replacingOccurrences(of: ",", with: ".")),
           t != currentTime
        {
            currentTime = t
        }

        if let dStr = context["media.duration"],
           let d = TimeInterval(dStr.replacingOccurrences(of: ",", with: ".")),
           d != duration
        {
            duration = d
        }

        if let urlStr = context["media.artworkURL"] {
            Task { @MainActor in
                await loadArtwork(from: urlStr)
            }
        }
    }

    @MainActor
    private func loadArtwork(from urlString: String) async {
        guard let url = URL(string: urlString) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = NSImage(data: data) {
                artwork = image
            }
        } catch {
            // Ignore failures
        }
    }

    func playPause() { runAction("playPause") }
    func nextTrack() { runAction("nextTrack") }
    func previousTrack() { runAction("previousTrack") }
    func seek(to position: TimeInterval) {
        currentTime = min(max(0, position), max(duration, 0))
        runAction("seekSeconds", extras: ["seconds": String(position)])
    }

    private func runAction(_ key: String, extras: [String: String]? = nil) {
        guard let script = actions?[key] else { return }
        let expanded = expandScript(script, extras: extras)
        Task.detached {
            _ = AppleScriptExecutor.run(expanded)
        }
    }

    private func expandScript(_ script: String, extras: [String: String]?) -> String {
        var result = script
        var replacements: [String: String] = [
            "media.title": title,
            "media.artist": artist,
            "media.album": album,
            "media.currentTime": String(currentTime),
            "media.duration": String(duration),
        ]
        if let extras { replacements.merge(extras) { _, new in new } }

        for (key, value) in replacements {
            result = result.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        return result
    }
}
