import Defaults
import Foundation

/// Discovers and loads widget manifests from the user's Application Support directory.
/// Stateless utility: fetch manifests on demand; no global singleton needed.
enum WidgetRegistry {
    // Default install root: ~/Library/Application Support/DockDoor/Widgets/
    static var installRoot: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("DockDoor/Widgets", isDirectory: true)
    }

    /// Load all manifests currently installed on disk.
    static func loadManifests() -> [WidgetManifest] {
        var results: [WidgetManifest] = []
        let fm = FileManager.default

        // Ensure directory exists (best-effort)
        do {
            try fm.createDirectory(at: installRoot, withIntermediateDirectories: true)
        } catch {
            // Ignore directory creation errors; discovery will fail below
        }

        let contents: [URL]
        do {
            contents = try fm.contentsOfDirectory(at: installRoot, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        } catch {
            return []
        }

        for dir in contents where dir.hasDirectoryPath {
            let manifestURL = dir.appendingPathComponent("manifest.json", isDirectory: false)
            do {
                let data = try Data(contentsOf: manifestURL)
                let manifest = try JSONDecoder().decode(WidgetManifest.self, from: data)
                results.append(manifest)
            } catch {
                continue
            }
        }

        return results
    }

    /// Return manifests matching a bundle id, discovered at call time.
    static func matchingWidgets(for bundleId: String) -> [WidgetManifest] {
        loadManifests().filter { $0.supports(bundleId: bundleId) }
    }

    // MARK: - Install/Uninstall Helpers

    /// Install (or update) a widget manifest to the install root.
    /// Writes to: ~/Library/Application Support/DockDoor/Widgets/<UUID>/manifest.json
    static func install(manifest: WidgetManifest, overwrite: Bool = true) throws {
        let fm = FileManager.default
        let dir = manifest.installDirectory
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("manifest.json")
        if fm.fileExists(atPath: url.path), !overwrite {
            return
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        let data = try encoder.encode(manifest)
        try data.write(to: url, options: .atomic)
    }

    /// Install manifest and a layout.json payload in one step (for declarative widgets).
    static func install(manifest: WidgetManifest, layout: Data, entryFileName: String = "layout.json", overwrite: Bool = true) throws {
        try install(manifest: manifest, overwrite: overwrite)
        let fileURL = manifest.installDirectory.appendingPathComponent(entryFileName, isDirectory: false)
        try layout.write(to: fileURL, options: .atomic)
    }

    /// Uninstall a widget by id (removes its directory).
    static func uninstall(id: UUID) throws {
        let fm = FileManager.default
        let dir = installRoot.appendingPathComponent(id.uuidString, isDirectory: true)
        if fm.fileExists(atPath: dir.path) {
            try fm.removeItem(at: dir)
        }
    }
}

// MARK: - Built-in Widgets Installer (no static UUIDs)

enum DefaultWidgets {
    static func ensureInstalledIfNeeded() {
        if Defaults[.installedDefaultWidgets] == false {
            installAll(overwriteExisting: false)
            Defaults[.installedDefaultWidgets] = true
        }
    }

    static func installAll(overwriteExisting: Bool = true) {
        installCalendar(overwriteExisting: overwriteExisting)
        installAppleMusic(overwriteExisting: overwriteExisting)
        installSpotify(overwriteExisting: overwriteExisting)
    }

    static func installCalendar(overwriteExisting: Bool = true) {
        removeExistingNative(entry: "CalendarWidget", matchBundleId: "com.apple.iCal")
        let manifest = WidgetManifest(
            name: "Calendar",
            author: "DockDoor",
            runtime: "native",
            entry: "CalendarWidget",
            modes: [.embedded, .full],
            matches: [WidgetMatchRule(bundleId: "com.apple.iCal")],
            actions: nil,
            provider: nil,
            version: SemVer(1, 0, 0),
            description: "Calendar at a glance.",
            icon: "calendar",
            permissions: nil,
            screenshots: nil,
            signature: nil,
            source: .local,
            updatedAt: nil
        )
        try? WidgetRegistry.install(manifest: manifest, overwrite: overwriteExisting)
    }

    static func installAppleMusic(overwriteExisting: Bool = true) {
        removeExistingNative(entry: "MediaControlsWidget", matchBundleId: "com.apple.Music")
        let actions = [
            "playPause": "tell application \"Music\" to playpause",
            "nextTrack": "tell application \"Music\" to next track",
            "previousTrack": "tell application \"Music\" to previous track",
            "seekSeconds": "tell application \"Music\" to set player position to {{seconds}}",
        ]
        let provider = WidgetStatusProvider(
            statusScript: "tell application \"Music\"\n  try\n    set currentState to player state\n    if currentState is playing then\n      set trackName to name of current track\n      set artistName to artist of current track\n      set albumName to album of current track\n      set playerState to \"playing\"\n      set currentPos to player position\n      set trackDuration to duration of current track\n      return trackName & tab & artistName & tab & albumName & tab & playerState & tab & currentPos & tab & trackDuration\n    else if currentState is paused then\n      set trackName to name of current track\n      set artistName to artist of current track\n      set albumName to album of current track\n      set playerState to \"paused\"\n      set currentPos to player position\n      set trackDuration to duration of current track\n      return trackName & tab & artistName & tab & albumName & tab & playerState & tab & currentPos & tab & trackDuration\n    else\n      return \"\" & tab & \"\" & tab & \"\" & tab & \"stopped\" & tab & \"0\" & tab & \"0\"\n    end if\n  on error\n    return \"\" & tab & \"\" & tab & \"\" & tab & \"stopped\" & tab & \"0\" & tab & \"0\"\n  end try\nend tell",
            pollIntervalMs: 500,
            delimiter: "\t",
            fields: [
                "media.title": 0,
                "media.artist": 1,
                "media.album": 2,
                "media.state": 3,
                "media.currentTime": 4,
                "media.duration": 5,
            ]
        )
        let manifest = WidgetManifest(
            name: "Apple Music Controls",
            author: "DockDoor",
            runtime: "native",
            entry: "MediaControlsWidget",
            modes: [.embedded, .full],
            matches: [WidgetMatchRule(bundleId: "com.apple.Music")],
            actions: actions,
            provider: provider,
            version: SemVer(1, 0, 0),
            description: "Playback controls for Apple Music.",
            icon: "music.note",
            permissions: [.appleScriptActions],
            screenshots: nil,
            signature: nil,
            source: .local,
            updatedAt: nil
        )
        try? WidgetRegistry.install(manifest: manifest, overwrite: overwriteExisting)
    }

    static func installSpotify(overwriteExisting: Bool = true) {
        removeExistingNative(entry: "MediaControlsWidget", matchBundleId: "com.spotify.client")
        let actions = [
            "playPause": "tell application \"Spotify\" to playpause",
            "nextTrack": "tell application \"Spotify\" to next track",
            "previousTrack": "tell application \"Spotify\" to previous track",
            "seekSeconds": "tell application \"Spotify\"\n  set player position to {{seconds}}\nend tell",
        ]
        let provider = WidgetStatusProvider(
            statusScript: "tell application \"Spotify\"\n  try\n    if player state is playing then\n      set trackName to name of current track\n      set artistName to artist of current track\n      set albumName to album of current track\n      set playerState to \"playing\"\n      set currentPos to player position\n      set trackDuration to (duration of current track) / 1000.0\n      set artworkUrl to artwork url of current track\n      return trackName & tab & artistName & tab & albumName & tab & playerState & tab & currentPos & tab & trackDuration & tab & artworkUrl\n    else if player state is paused then\n      set trackName to name of current track\n      set artistName to artist of current track\n      set albumName to album of current track\n      set playerState to \"paused\"\n      set currentPos to player position\n      set trackDuration to (duration of current track) / 1000.0\n      set artworkUrl to artwork url of current track\n      return trackName & tab & artistName & tab & albumName & tab & playerState & tab & currentPos & tab & trackDuration & tab & artworkUrl\n    else\n      return \"\" & tab & \"\" & tab & \"\" & tab & \"stopped\" & tab & \"0\" & tab & \"0\" & tab & \"\"\n    end if\n  on error\n    return \"\" & tab & \"\" & tab & \"\" & tab & \"stopped\" & tab & \"0\" & tab & \"0\" & tab & \"\"\n  end try\nend tell",
            pollIntervalMs: 500,
            delimiter: "\t",
            fields: [
                "media.title": 0,
                "media.artist": 1,
                "media.album": 2,
                "media.state": 3,
                "media.currentTime": 4,
                "media.duration": 5,
                "media.artworkURL": 6,
            ]
        )
        let manifest = WidgetManifest(
            name: "Spotify Controls",
            author: "DockDoor",
            runtime: "native",
            entry: "MediaControlsWidget",
            modes: [.embedded, .full],
            matches: [WidgetMatchRule(bundleId: "com.spotify.client")],
            actions: actions,
            provider: provider,
            version: SemVer(1, 0, 0),
            description: "Playback controls for Spotify.",
            icon: "music.note.list",
            permissions: [.appleScriptActions],
            screenshots: nil,
            signature: nil,
            source: .local,
            updatedAt: nil
        )
        try? WidgetRegistry.install(manifest: manifest, overwrite: overwriteExisting)
    }

    private static func removeExistingNative(entry: String, matchBundleId: String) {
        let existing = WidgetRegistry.loadManifests().filter { m in
            m.runtime == "native" && m.entry == entry && m.matches.contains(where: { $0.bundleId == matchBundleId })
        }
        for m in existing {
            try? WidgetRegistry.uninstall(id: m.id)
        }
    }
}
