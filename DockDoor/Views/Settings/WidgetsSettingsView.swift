import AppKit
import Defaults
import SwiftUI

struct WidgetsSettingsView: View {
    @Default(.widgetsEnabled) private var widgetsEnabled
    @State private var manifests: [WidgetManifest] = []
    @State private var installing: Bool = false
    @State private var message: String? = nil

    var body: some View {
        BaseSettingsView {
            VStack(alignment: .leading, spacing: 16) {
                StyledGroupBox(label: "Widgets") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(isOn: $widgetsEnabled) { Text("Enable Widgets") }
                        Text("Install and manage native/declarative widgets.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack(spacing: 8) {
                            Button(action: installNativeCalendarWidget) {
                                if installing { ProgressView().scaleEffect(0.8) } else { Text("Install Calendar (Native)") }
                            }
                            .disabled(installing)
                            Button(action: installNativeMediaWidgets) {
                                if installing { ProgressView().scaleEffect(0.8) } else { Text("Install Spotify and Apple Music Controls (Native)") }
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
                                        Text("by \(m.author)").font(.caption).foregroundColor(.secondary)
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
        manifests = WidgetRegistry.loadManifests()
    }

    private func installNativeCalendarWidget() {
        installing = true
        message = nil
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try WidgetRegistry.install(manifest: Self.makeCalendarNativeManifest())
                DispatchQueue.main.async {
                    installing = false
                    message = "Installed Calendar (Native)"
                    reload()
                }
            } catch {
                DispatchQueue.main.async {
                    installing = false
                    message = "Failed to install Calendar (Native): \(error.localizedDescription)"
                }
            }
        }
    }

    private func installNativeMediaWidgets() {
        installing = true
        message = nil
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try WidgetRegistry.install(manifest: Self.makeMusicNativeManifest())
                try WidgetRegistry.install(manifest: Self.makeSpotifyNativeManifest())

                DispatchQueue.main.async {
                    installing = false
                    message = "Installed native Spotify and Apple Music controls"
                    reload()
                }
            } catch {
                DispatchQueue.main.async {
                    installing = false
                    message = "Failed to install native media widgets: \(error.localizedDescription)"
                }
            }
        }
    }

    private func openWidgetsFolder() {
        let url = WidgetRegistry.installRoot
        _ = try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }

    private func removeWidget(_ m: WidgetManifest) {
        do {
            try WidgetRegistry.uninstall(id: m.id)
            message = "Removed \(m.name)"
            reload()
        } catch {
            message = "Failed to remove \(m.name)"
        }
    }

    private static func makeCalendarNativeManifest() -> WidgetManifest {
        WidgetManifest(
            name: "Calendar",
            author: "ejbills",
            runtime: "native",
            entry: "CalendarWidget",
            modes: [.embedded, .full],
            matches: [WidgetMatchRule(bundleId: "com.apple.iCal")]
        )
    }

    private static func makeMusicNativeManifest() -> WidgetManifest {
        let provider = WidgetStatusProvider(
            statusScript: [
                "tell application \"Music\"",
                "  try",
                "    set currentState to player state",
                "    if currentState is playing then",
                "      set trackName to name of current track",
                "      set artistName to artist of current track",
                "      set albumName to album of current track",
                "      set playerState to \"playing\"",
                "      set currentPos to player position",
                "      set trackDuration to duration of current track",
                "      return trackName & tab & artistName & tab & albumName & tab & playerState & tab & currentPos & tab & trackDuration",
                "    else if currentState is paused then",
                "      set trackName to name of current track",
                "      set artistName to artist of current track",
                "      set albumName to album of current track",
                "      set playerState to \"paused\"",
                "      set currentPos to player position",
                "      set trackDuration to duration of current track",
                "      return trackName & tab & artistName & tab & albumName & tab & playerState & tab & currentPos & tab & trackDuration",
                "    else",
                "      return \"\" & tab & \"\" & tab & \"\" & tab & \"stopped\" & tab & \"0\" & tab & \"0\"",
                "    end if",
                "  on error",
                "    return \"\" & tab & \"\" & tab & \"\" & tab & \"stopped\" & tab & \"0\" & tab & \"0\"",
                "  end try",
                "end tell",
            ].joined(separator: "\n"),
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
        return WidgetManifest(
            name: "Apple Music Controls",
            author: "DockDoor",
            runtime: "native",
            entry: "MediaControlsWidget",
            modes: [.embedded, .full],
            matches: [WidgetMatchRule(bundleId: "com.apple.Music")],
            actions: [
                "playPause": "tell application \"Music\" to playpause",
                "nextTrack": "tell application \"Music\" to next track",
                "previousTrack": "tell application \"Music\" to previous track",
                "seekSeconds": "tell application \"Music\" to set player position to {{seconds}}",
            ],
            provider: provider
        )
    }

    private static func makeSpotifyNativeManifest() -> WidgetManifest {
        let provider = WidgetStatusProvider(
            statusScript: [
                "tell application \"Spotify\"",
                "  try",
                "    if player state is playing then",
                "      set trackName to name of current track",
                "      set artistName to artist of current track",
                "      set albumName to album of current track",
                "      set playerState to \"playing\"",
                "      set currentPos to player position",
                "      set trackDuration to (duration of current track) / 1000.0",
                "      set artworkUrl to artwork url of current track",
                "      return trackName & tab & artistName & tab & albumName & tab & playerState & tab & currentPos & tab & trackDuration & tab & artworkUrl",
                "    else if player state is paused then",
                "      set trackName to name of current track",
                "      set artistName to artist of current track",
                "      set albumName to album of current track",
                "      set playerState to \"paused\"",
                "      set currentPos to player position",
                "      set trackDuration to (duration of current track) / 1000.0",
                "      set artworkUrl to artwork url of current track",
                "      return trackName & tab & artistName & tab & albumName & tab & playerState & tab & currentPos & tab & trackDuration & tab & artworkUrl",
                "    else",
                "      return \"\" & tab & \"\" & tab & \"\" & tab & \"stopped\" & tab & \"0\" & tab & \"0\" & tab & \"\"",
                "    end if",
                "  on error",
                "    return \"\" & tab & \"\" & tab & \"\" & tab & \"stopped\" & tab & \"0\" & tab & \"0\" & tab & \"\"",
                "  end try",
                "end tell",
            ].joined(separator: "\n"),
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
        return WidgetManifest(
            name: "Spotify Controls",
            author: "DockDoor",
            runtime: "native",
            entry: "MediaControlsWidget",
            modes: [.embedded, .full],
            matches: [WidgetMatchRule(bundleId: "com.spotify.client")],
            actions: [
                "playPause": "tell application \"Spotify\" to playpause",
                "nextTrack": "tell application \"Spotify\" to next track",
                "previousTrack": "tell application \"Spotify\" to previous track",
                "seekSeconds": "tell application \"Spotify\"\n  set player position to {{seconds}}\nend tell",
            ],
            provider: provider
        )
    }
}
