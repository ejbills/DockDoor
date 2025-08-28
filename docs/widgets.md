# DockDoor Widget System

This documents DockDoor’s pluggable widget system, covering both declarative (JSON-rendered) widgets and native (SwiftUI) widgets. Widgets are installed per-user in Application Support and selected by the target app’s bundle identifier.

Key components
- `WidgetManifest` (DockDoor/Widgets/Core/WidgetModels.swift): JSON manifest describing a widget (runtime, entry, modes, matches, optional actions/provider).
- `WidgetRegistry` (DockDoor/Widgets/Core/WidgetRegistry.swift): discovers manifests in `~/Library/Application Support/DockDoor/Widgets`.
- `WidgetOrchestrator` (DockDoor/Widgets/Core/WidgetOrchestrator.swift): selects embedded/full widgets for the current app.
- Declarative runtime: `Wireframe` + `WidgetHostView` render JSON layouts and poll status providers for dynamic context.
- Native runtime: `NativeWidgetFactory` builds first‑party SwiftUI views. Native widgets handle their own polling (e.g., `MediaControlsWidgetView` with `MediaStore`).

Install location
```
~/Library/Application Support/DockDoor/Widgets/<UUID>/
  manifest.json
  layout.json        # for declarative widgets
  assets/*           # optional assets
```

Manifest schema (simplified)
- `id`: auto-generated UUID by DockDoor when installing via the settings UI
- `name`, `author`: display metadata
- `runtime`: `"declarative"` or `"native"`
- `entry`: declarative: `layout.json`; native: a built-in identifier (e.g. `"MediaControlsWidget"`, `"CalendarWidget"`)
- `modes`: list of `"embedded"` and/or `"full"`
- `matches`: array of `{ "bundleId": "…" }` rules
- `actions` (optional): map of action key → AppleScript string (supports template expansion)
- `provider` (optional): polling spec for dynamic data

Provider (polling) spec
```
{
  "statusScript": "…AppleScript…",
  "pollIntervalMs": 500,
  "delimiter": "\t",
  "fields": { "media.title": 0, "media.artist": 1, … }
}
```
- DockDoor executes `statusScript` on a schedule and splits stdout by `delimiter`.
- Each field name maps to an index in the parts array; those key/value pairs form the widget context.
- For native media widgets, these fields populate a typed store (`MediaStore`), so avoid renaming the standard keys below.

Standard media context keys
- `media.title`, `media.artist`, `media.album`
- `media.state` ("playing" | "paused" | "stopped")
- `media.currentTime`, `media.duration` (seconds; decimals allowed)
- `media.artworkURL` (http(s) or data: URL)

Action scripts (template expansion)
- Manifests may define actions like `playPause`, `nextTrack`, `previousTrack`, `seekSeconds`.
- Templates expand `{{key}}` from the merged context. Native views may pass extra keys (e.g., `{"seconds":"42"}` for `seekSeconds`).

Example: Apple Music (native)
```
{
  "name": "Apple Music Controls",
  "author": "DockDoor",
  "runtime": "native",
  "entry": "MediaControlsWidget",
  "modes": ["embedded", "full"],
  "matches": [{ "bundleId": "com.apple.Music" }],
  "actions": {
    "playPause": "tell application \"Music\" to playpause",
    "nextTrack": "tell application \"Music\" to next track",
    "previousTrack": "tell application \"Music\" to previous track",
    "seekSeconds": "tell application \"Music\" to set player position to {{seconds}}"
  },
  "provider": {
    "statusScript": "tell application \"Music\"\n  try\n    set currentState to player state\n    if currentState is playing then\n      set trackName to name of current track\n      set artistName to artist of current track\n      set albumName to album of current track\n      set playerState to \"playing\"\n      set currentPos to player position\n      set trackDuration to duration of current track\n      return trackName & tab & artistName & tab & albumName & tab & playerState & tab & currentPos & tab & trackDuration\n    else if currentState is paused then\n      set trackName to name of current track\n      set artistName to artist of current track\n      set albumName to album of current track\n      set playerState to \"paused\"\n      set currentPos to player position\n      set trackDuration to duration of current track\n      return trackName & tab & artistName & tab & albumName & tab & playerState & tab & currentPos & tab & trackDuration\n    else\n      return \"\" & tab & \"\" & tab & \"\" & tab & \"stopped\" & tab & \"0\" & tab & \"0\"\n    end if\n  on error\n    return \"\" & tab & \"\" & tab & \"\" & tab & \"stopped\" & tab & \"0\" & tab & \"0\"\n  end try\nend tell",
    "pollIntervalMs": 500,
    "delimiter": "\t",
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
```

Example: Spotify (native)
```
{
  "name": "Spotify Controls",
  "author": "DockDoor",
  "runtime": "native",
  "entry": "MediaControlsWidget",
  "modes": ["embedded", "full"],
  "matches": [{ "bundleId": "com.spotify.client" }],
  "actions": {
    "playPause": "tell application \"Spotify\" to playpause",
    "nextTrack": "tell application \"Spotify\" to next track",
    "previousTrack": "tell application \"Spotify\" to previous track",
    "seekSeconds": "tell application \"Spotify\"\n  set player position to {{seconds}}\nend tell"
  },
  "provider": {
    "statusScript": "tell application \"Spotify\"\n  try\n    if player state is playing then\n      set trackName to name of current track\n      set artistName to artist of current track\n      set albumName to album of current track\n      set playerState to \"playing\"\n      set currentPos to player position\n      set trackDuration to (duration of current track) / 1000.0\n      set artworkUrl to artwork url of current track\n      return trackName & tab & artistName & tab & albumName & tab & playerState & tab & currentPos & tab & trackDuration & tab & artworkUrl\n    else if player state is paused then\n      set trackName to name of current track\n      set artistName to artist of current track\n      set albumName to album of current track\n      set playerState to \"paused\"\n      set currentPos to player position\n      set trackDuration to (duration of current track) / 1000.0\n      set artworkUrl to artwork url of current track\n      return trackName & tab & artistName & tab & albumName & tab & playerState & tab & currentPos & tab & trackDuration & tab & artworkUrl\n    else\n      return \"\" & tab & \"\" & tab & \"\" & tab & \"stopped\" & tab & \"0\" & tab & \"0\" & tab & \"\"\n    end if\n  on error\n    return \"\" & tab & \"\" & tab & \"\" & tab & \"stopped\" & tab & \"0\" & tab & \"0\" & tab & \"\"\n  end try\nend tell",
    "pollIntervalMs": 500,
    "delimiter": "\t",
    "fields": {
      "media.title": 0,
      "media.artist": 1,
      "media.album": 2,
      "media.state": 3,
      "media.currentTime": 4,
      "media.duration": 5,
      "media.artworkURL": 6
    }
  }
}
```

Declarative widgets
- Provide `runtime: "declarative"`, `entry: "layout.json"`, optional `actions`, and optional `provider`.
- `WidgetHostView` polls the provider at `pollIntervalMs` while visible and injects the resulting context map into the layout renderer.
- Bind UI nodes to context keys and use the `buttonRow` actions to trigger manifest `actions`.

Native widgets
- Provide `runtime: "native"` and an `entry` of a built-in view. Native widgets handle their own polling directly.
- For media, `MediaControlsWidgetView` uses a `MediaStore` (ObservableObject) that polls the manifest's `provider` and updates the UI reactively. Actions are executed from the manifest with optimistic UI updates.
- Native widgets that don't require polling (e.g., Calendar) can omit `provider` and rely on their own data sources.

Lifecycle & performance
- Polling is lifecycle-aware: providers run only while their widgets are visible and stop when they go off-screen.
- Native widgets handle their own polling (needed for both embedded and pinned usage scenarios).
- Prefer stable field names and avoid excessive intervals; 500ms is typical for media.

Tips
- You can template any `{{key}}` present in context into your AppleScript `actions`.
- Consider returning a data URL string for artwork if fetching files is cumbersome.
- If your domain suits JSON, we plan to support JSON output (no `delimiter`/`fields`) in a future iteration.
