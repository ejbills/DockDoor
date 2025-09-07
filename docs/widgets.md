# DockDoor Widgets

Build small, app‑specific controls that appear alongside DockDoor’s previews. There are two ways to build:

- Native: a built‑in SwiftUI view identified by name in the manifest.
- Declarative: a tiny JSON layout (Wireframe) rendered by DockDoor, with optional AppleScript polling and actions.

Install location
```
~/Library/Application Support/DockDoor/Widgets/<UUID>/
  manifest.json
  layout.json        # only for declarative widgets
```

Keep it simple: no assets folder is needed. Declarative widgets use SF Symbols; native widgets render SwiftUI directly.

Manifest (essentials)
- `name`, `author`: Display info.
- `runtime`: `"native"` or `"declarative"`.
- `entry`: Native → a built‑in identifier (e.g. `"MediaControlsWidget"`, `"CalendarWidget"`). Declarative → `"layout.json"`.
- `modes`: Any of `"embedded"`, `"full"`.
- `matches`: Array of `{ "bundleId": "…" }` rules selecting which app(s) show the widget.
- Optional: `actions` (AppleScript snippets) and `provider` (polling) for dynamic data.

Provider (polling) — optional
```
{
  "statusScript": "…AppleScript…",
  "pollIntervalMs": 500,
  "delimiter": "\t",
  "fields": { "media.title": 0, "media.artist": 1 }
}
```
DockDoor executes `statusScript`, splits stdout by `delimiter`, and maps indexes to keys into the widget’s context. Use stable names when possible.

Action scripts (templating)
- Define keys like `playPause`, `nextTrack`, `seekSeconds`.
- Scripts expand `{{key}}` from the current context (and extras passed by native views).

Quick start — Native (example)
```
{
  "name": "Apple Music Controls",
  "author": "DockDoor",
  "runtime": "native",
  "entry": "MediaControlsWidget",
  "modes": ["embedded", "full"],
  "matches": [{ "bundleId": "com.apple.Music" }],
  "actions": {
    "playPause": "tell application \"Music\" to playpause"
  },
  "provider": {
    "statusScript": "tell application \"Music\" to return (name of current track) & tab & (artist of current track)",
    "pollIntervalMs": 500,
    "delimiter": "\t",
    "fields": { "media.title": 0, "media.artist": 1 }
  }
}
```
Steps:
- Create `manifest.json` like above.
- Install: Settings → Widgets → My Widgets → Install from Folder…
- Open the target app and hover its Dock icon.

Quick start — Declarative (example)
`layout.json` (uses SF Symbols; no external assets):
```
{
  "embedded": {
    "type": "hstack",
    "spacing": 8,
    "children": [
      { "type": "imageSymbol", "symbol": "playpause.fill", "size": 16 },
      { "type": "text", "text": "{{media.title}} — {{media.artist}}", "font": "caption", "lineLimit": 1 }
    ]
  }
}
```
`manifest.json`:
```
{
  "name": "Safari Essentials",
  "author": "DockDoor",
  "runtime": "declarative",
  "entry": "layout.json",
  "modes": ["embedded"],
  "matches": [{ "bundleId": "com.apple.Safari" }],
  "actions": { "playPause": "tell app \"Music\" to playpause" },
  "provider": {
    "statusScript": "tell application \"Music\" to return (name of current track) & tab & (artist of current track)",
    "pollIntervalMs": 500,
    "delimiter": "\t",
    "fields": { "media.title": 0, "media.artist": 1 }
  }
}
```

Layout nodes (supported)
- `vstack`, `hstack`, `zstack`: Containers with optional `spacing`.
- `text`: Text content; supports `font` (e.g. caption, body, headline), `foreground` (`primary`, `secondary`), `truncation`, `lineLimit`.
- `imageSymbol`: SF Symbol by name; set `size`.
- `buttonRow`: Row of buttons with SF Symbols that trigger manifest `actions` by key.
- `spacer`: Flexible space.

Context keys
- Provided automatically: `appName`, `bundleIdentifier`, `windows.count`, `dockPosition`.
- Media convenience: `media.title`, `media.artist`, `media.album`, `media.state`, `media.currentTime`, `media.duration`, `media.artworkURL` (if your provider returns it).

Lifecycle & performance
- Polling runs only while the widget is visible.
- Use reasonable intervals (e.g. 500ms for media).

Install & manage
- Use Settings → Widgets → My Widgets to install from a folder, reveal, and remove widgets.
- Widgets are per‑user under Application Support; no separate assets folder is required.

Notes
- Native widgets ignore external files; everything is rendered in SwiftUI.
- Declarative widgets use only SF Symbols for images.
- Future: a JSON provider output may be supported to avoid delimiter/index parsing.
