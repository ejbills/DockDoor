import AppKit
import Defaults
import SwiftUI

struct WidgetsSettingsView: View {
    @Default(.useWidgetSystem) private var useWidgetSystem
    @State private var manifests: [WidgetManifest] = []
    @State private var installing: Bool = false
    @State private var message: String? = nil

    var body: some View {
        BaseSettingsView {
            VStack(alignment: .leading, spacing: 16) {
                StyledGroupBox(label: "Widgets (Experimental)") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(isOn: $useWidgetSystem) { Text("Enable Widget System (Experimental)") }
                        Text("Allows installing and rendering widgets without updating the app.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack(spacing: 8) {
                            Button(action: installSampleWidget) {
                                if installing { ProgressView().scaleEffect(0.8) } else { Text("Install Sample Widget") }
                            }
                            .disabled(installing)
                            Button(action: installMusicWidgets) {
                                if installing { ProgressView().scaleEffect(0.8) } else { Text("Install Music Widgets") }
                            }
                            .disabled(installing)
                            Button(action: openWidgetsFolder) { Text("Open Widgets Folder") }
                        }

                        if let message { Text(message).font(.caption).foregroundColor(.secondary) }
                    }
                }

                StyledGroupBox(label: "Installed Widgets") {
                    VStack(alignment: .leading, spacing: 8) {
                        if manifests.isEmpty {
                            Text("No widgets installed").foregroundColor(.secondary)
                        } else {
                            ForEach(manifests, id: \.self) { m in
                                HStack(alignment: .center, spacing: 10) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(m.name).font(.headline)
                                        Text("\(m.id) • v\(m.version)").font(.caption).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Button(role: .destructive) { removeWidget(m) } label: { Image(systemName: "trash") }
                                        .buttonStyle(.plain)
                                }
                                .padding(.vertical, 4)
                                if m != manifests.last { Divider() }
                            }
                        }
                    }
                }
            }
            .onAppear(perform: reload)
        }
    }

    private func reload() {
        WidgetRegistry.shared.reload()
        manifests = WidgetRegistry.shared.manifests
    }

    private func openWidgetsFolder() {
        let url = WidgetRegistry.installRoot
        _ = try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }

    private func removeWidget(_ m: WidgetManifest) {
        guard let dir = m.installDirectory else { return }
        do {
            try FileManager.default.removeItem(at: dir)
            message = "Removed \(m.name)"
            reload()
        } catch {
            message = "Failed to remove \(m.name)"
        }
    }

    private func installSampleWidget() {
        installing = true
        message = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let sampleId = "com.dockdoor.sample.music"
            let root = WidgetRegistry.installRoot.appendingPathComponent(sampleId, isDirectory: true)
            let fm = FileManager.default
            do {
                try fm.createDirectory(at: root, withIntermediateDirectories: true)
                let manifest = Self.sampleManifest
                let layout = Self.sampleLayout
                try manifest.write(to: root.appendingPathComponent("manifest.json"), atomically: true, encoding: .utf8)
                try layout.write(to: root.appendingPathComponent("layout.json"), atomically: true, encoding: .utf8)
                DispatchQueue.main.async {
                    installing = false
                    message = "Installed sample widget targeting Music.app"
                    reload()
                }
            } catch {
                DispatchQueue.main.async {
                    installing = false
                    message = "Failed to install sample widget"
                }
            }
        }
    }

    private func installMusicWidgets() {
        installing = true
        message = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            do {
                // Install Music widget
                let musicRoot = WidgetRegistry.installRoot.appendingPathComponent("com.dockdoor.music.controls", isDirectory: true)
                try fm.createDirectory(at: musicRoot, withIntermediateDirectories: true)
                try Self.musicManifest.write(to: musicRoot.appendingPathComponent("manifest.json"), atomically: true, encoding: .utf8)
                try Self.musicLayout.write(to: musicRoot.appendingPathComponent("layout.json"), atomically: true, encoding: .utf8)

                // Install Spotify widget
                let spotifyRoot = WidgetRegistry.installRoot.appendingPathComponent("com.dockdoor.spotify.controls", isDirectory: true)
                try fm.createDirectory(at: spotifyRoot, withIntermediateDirectories: true)
                try Self.spotifyManifest.write(to: spotifyRoot.appendingPathComponent("manifest.json"), atomically: true, encoding: .utf8)
                try Self.spotifyLayout.write(to: spotifyRoot.appendingPathComponent("layout.json"), atomically: true, encoding: .utf8)

                DispatchQueue.main.async {
                    installing = false
                    message = "Installed Music and Spotify widgets"
                    reload()
                }
            } catch {
                DispatchQueue.main.async {
                    installing = false
                    message = "Failed to install music widgets: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Sample Files

    private static var sampleManifest: String {
        """
        {\n  \"id\": \"com.dockdoor.sample.music\",\n  \"name\": \"Sample Music Controls\",\n  \"version\": \"1.0.0\",\n  \"author\": \"DockDoor\",\n  \"runtime\": \"declarative\",\n  \"entry\": \"layout.json\",\n  \"modes\": [\"embedded\", \"full\"],\n  \"matches\": [{ \"bundleId\": \"com.apple.Music\" }]\n}\n
        """
    }

    private static var sampleLayout: String {
        """
        {\n  \"embedded\": {\n    \"type\": \"hstack\",\n    \"spacing\": 8,\n    \"children\": [\n      {\"type\": \"imageSymbol\", \"symbol\": \"music.note\", \"size\": 16},\n      {\"type\": \"text\", \"text\": \"Music\", \"font\": \"callout\"},\n      {\"type\": \"spacer\"},\n      {\"type\": \"buttonRow\", \"buttons\": [\n        {\"symbol\": \"backward.fill\", \"action\": \"media.previous\"},\n        {\"symbol\": \"playpause.fill\", \"action\": \"media.playPause\"},\n        {\"symbol\": \"forward.fill\", \"action\": \"media.next\"}\n      ]}\n    ]\n  },\n  \"full\": {\n    \"type\": \"vstack\",\n    \"spacing\": 12,\n    \"children\": [\n      {\"type\": \"text\", \"text\": \"Sample Music Controls\", \"font\": \"title3\"},\n      {\"type\": \"buttonRow\", \"buttons\": [\n        {\"symbol\": \"backward.fill\", \"action\": \"media.previous\"},\n        {\"symbol\": \"playpause.fill\", \"action\": \"media.playPause\"},\n        {\"symbol\": \"forward.fill\", \"action\": \"media.next\"}\n      ]}\n    ]\n  }\n}\n
        """
    }

    // MARK: - Music Widget Files

    private static var musicManifest: String {
        """
        {
          "id": "com.dockdoor.music.controls",
          "name": "Apple Music Controls",
          "version": "1.0.0",
          "author": "DockDoor",
          "runtime": "declarative",
          "entry": "layout.json",
          "modes": ["embedded", "full"],
          "matches": [
            { "bundleId": "com.apple.Music" }
          ],
          "actions": {
            "playPause": "tell application \\"Music\\" to playpause",
            "nextTrack": "tell application \\"Music\\" to next track",
            "previousTrack": "tell application \\"Music\\" to previous track",
            "seekSeconds": "tell application \\"Music\\" to set player position to {{seconds}}"
          },
          "provider": {
            "statusScript": "try\\n  tell application \\"Music\\"\\n    if not (exists current track) then return \\"〈♫DOCKDOOR♫〉〈♫DOCKDOOR♫〉〈♫DOCKDOOR♫〉paused〈♫DOCKDOOR♫〉0〈♫DOCKDOOR♫〉0\\"\\n    set t to name of current track\\n    set a to artist of current track\\n    set al to album of current track\\n    set p to (if player state is playing then \\"playing\\" else \\"paused\\")\\n    set ct to player position\\n    set d to duration of current track\\n    return t & \\"〈♫DOCKDOOR♫〉\\" & a & \\"〈♫DOCKDOOR♫〉\\" & al & \\"〈♫DOCKDOOR♫〉\\" & p & \\"〈♫DOCKDOOR♫〉\\" & ct & \\"〈♫DOCKDOOR♫〉\\" & d\\n  end tell\\non error\\n  return \\"〈♫DOCKDOOR♫〉〈♫DOCKDOOR♫〉〈♫DOCKDOOR♫〉paused〈♫DOCKDOOR♫〉0〈♫DOCKDOOR♫〉0\\"\\nend try",
            "pollIntervalMs": 1000,
            "delimiter": "〈♫DOCKDOOR♫〉",
            "fields": {
              "media.title": 0,
              "media.artist": 1,
              "media.album": 2,
              "media.state": 3,
              "media.currentTime": 4,
              "media.duration": 5
            }
          }
        }
        """
    }

    private static var musicLayout: String {
        """
        {
          "embedded": {
            "type": "hstack",
            "spacing": 8,
            "children": [
              {
                "type": "text",
                "text": "{{media.title}}",
                "font": "callout",
                "truncation": "tail",
                "lineLimit": 1
              },
              {
                "type": "text",
                "text": "{{media.artist}}",
                "font": "caption",
                "foreground": "secondary",
                "truncation": "tail",
                "lineLimit": 1
              },
              {
                "type": "spacer"
              },
              {
                "type": "buttonRow",
                "spacing": 12,
                "buttons": [
                  {
                    "symbol": "backward.fill",
                    "action": "previousTrack"
                  },
                  {
                    "symbol": "playpause.fill",
                    "action": "playPause"
                  },
                  {
                    "symbol": "forward.fill",
                    "action": "nextTrack"
                  }
                ]
              }
            ]
          },
          "full": {
            "type": "vstack",
            "spacing": 16,
            "alignment": "center",
            "children": [
              {
                "type": "text",
                "text": "{{media.title}}",
                "font": "title2",
                "truncation": "tail",
                "lineLimit": 2
              },
              {
                "type": "text",
                "text": "{{media.artist}}",
                "font": "headline",
                "foreground": "secondary",
                "truncation": "tail",
                "lineLimit": 1
              },
              {
                "type": "buttonRow",
                "spacing": 20,
                "buttons": [
                  {
                    "symbol": "backward.fill",
                    "action": "previousTrack"
                  },
                  {
                    "symbol": "playpause.fill",
                    "action": "playPause"
                  },
                  {
                    "symbol": "forward.fill",
                    "action": "nextTrack"
                  }
                ]
              },
              {
                "type": "text",
                "text": "State: {{media.state}}",
                "font": "caption",
                "foreground": "secondary"
              }
            ]
          }
        }
        """
    }

    // MARK: - Spotify Widget Files

    private static var spotifyManifest: String {
        """
        {
          "id": "com.dockdoor.spotify.controls",
          "name": "Spotify Controls",
          "version": "1.0.0",
          "author": "DockDoor",
          "runtime": "declarative",
          "entry": "layout.json",
          "modes": ["embedded", "full"],
          "matches": [
            { "bundleId": "com.spotify.client" }
          ],
          "actions": {
            "playPause": "tell application \\"Spotify\\" to playpause",
            "nextTrack": "tell application \\"Spotify\\" to next track",
            "previousTrack": "tell application \\"Spotify\\" to previous track",
            "seekSeconds": "tell application \\"Spotify\\"\\n  set player position to {{seconds}}\\nend tell"
          },
          "provider": {
            "statusScript": "try\\n  tell application \\"Spotify\\"\\n    set p to player state as string\\n    if p is not \\"playing\\" and p is not \\"paused\\" then set p to \\"paused\\"\\n    if not (exists current track) then return \\"〈♫DOCKDOOR♫〉〈♫DOCKDOOR♫〉〈♫DOCKDOOR♫〉\\" & p & \\"〈♫DOCKDOOR♫〉0〈♫DOCKDOOR♫〉0\\"\\n    set t to name of current track\\n    set a to artist of current track\\n    set al to album of current track\\n    set ct to player position\\n    set dm to duration of current track\\n    set ds to (dm / 1000.0)\\n    return t & \\"〈♫DOCKDOOR♫〉\\" & a & \\"〈♫DOCKDOOR♫〉\\" & al & \\"〈♫DOCKDOOR♫〉\\" & p & \\"〈♫DOCKDOOR♫〉\\" & ct & \\"〈♫DOCKDOOR♫〉\\" & ds\\n  end tell\\non error\\n  return \\"〈♫DOCKDOOR♫〉〈♫DOCKDOOR♫〉〈♫DOCKDOOR♫〉paused〈♫DOCKDOOR♫〉0〈♫DOCKDOOR♫〉0\\"\\nend try",
            "pollIntervalMs": 1000,
            "delimiter": "〈♫DOCKDOOR♫〉",
            "fields": {
              "media.title": 0,
              "media.artist": 1,
              "media.album": 2,
              "media.state": 3,
              "media.currentTime": 4,
              "media.duration": 5
            }
          }
        }
        """
    }

    private static var spotifyLayout: String {
        """
        {
          "embedded": {
            "type": "hstack",
            "spacing": 8,
            "children": [
              {
                "type": "text",
                "text": "{{media.title}}",
                "font": "callout",
                "truncation": "tail",
                "lineLimit": 1
              },
              {
                "type": "text",
                "text": "{{media.artist}}",
                "font": "caption",
                "foreground": "secondary",
                "truncation": "tail",
                "lineLimit": 1
              },
              {
                "type": "spacer"
              },
              {
                "type": "buttonRow",
                "spacing": 12,
                "buttons": [
                  {
                    "symbol": "backward.fill",
                    "action": "previousTrack"
                  },
                  {
                    "symbol": "playpause.fill",
                    "action": "playPause"
                  },
                  {
                    "symbol": "forward.fill",
                    "action": "nextTrack"
                  }
                ]
              }
            ]
          },
          "full": {
            "type": "vstack",
            "spacing": 16,
            "alignment": "center",
            "children": [
              {
                "type": "text",
                "text": "{{media.title}}",
                "font": "title2",
                "truncation": "tail",
                "lineLimit": 2
              },
              {
                "type": "text",
                "text": "{{media.artist}}",
                "font": "headline",
                "foreground": "secondary",
                "truncation": "tail",
                "lineLimit": 1
              },
              {
                "type": "buttonRow",
                "spacing": 20,
                "buttons": [
                  {
                    "symbol": "backward.fill",
                    "action": "previousTrack"
                  },
                  {
                    "symbol": "playpause.fill",
                    "action": "playPause"
                  },
                  {
                    "symbol": "forward.fill",
                    "action": "nextTrack"
                  }
                ]
              },
              {
                "type": "text",
                "text": "State: {{media.state}}",
                "font": "caption",
                "foreground": "secondary"
              }
            ]
          }
        }
        """
    }
}
