# DockDoor Widget System (Scaffold)

This branch introduces a scaffolding for a pluggable widget system.

Key components:

- `WidgetManifest` (DockDoor/Widgets/Core/WidgetModels.swift): JSON-manifest describing a widget.
- `WidgetRegistry` (DockDoor/Widgets/Core/WidgetRegistry.swift): scans `~/Library/Application Support/DockDoor/Widgets` for widgets.
- `WidgetOrchestrator` (DockDoor/Widgets/Core/WidgetOrchestrator.swift): selects widgets for a given app.
- `Wireframe` & `WidgetHostView` (DockDoor/Widgets/Declarative/): minimal JSON → SwiftUI renderer.

Install location:

```
~/Library/Application Support/DockDoor/Widgets/<widget-id>/
  - manifest.json
  - layout.json
  - assets...
```

`manifest.json` example (declarative):

```
{
  "id": "com.example.mymusic",
  "name": "My Music Widget",
  "version": "1.0.0",
  "author": "Example",
  "runtime": "declarative",
  "entry": "layout.json",
  "modes": ["embedded", "full"],
  "matches": [{ "bundleId": "com.example.MyMusic" }]
}
```

`layout.json` example (very minimal):

```
{
  "embedded": {
    "type": "hstack",
    "spacing": 8,
    "children": [
      {"type": "imageSymbol", "symbol": "music.note", "size": 16},
      {"type": "text", "text": "My Music", "font": "callout"}
    ]
  },
  "full": {
    "type": "vstack",
    "spacing": 12,
    "children": [
      {"type": "text", "text": "My Music (Full)", "font": "title3"},
      {"type": "buttonRow", "buttons": [
        {"symbol": "backward.fill", "action": "media.previous"},
        {"symbol": "playpause.fill", "action": "media.playPause"},
        {"symbol": "forward.fill", "action": "media.next"}
      ]}
    ]
  }
}
```

Note: This is an initial scaffold; actions and data providers are not wired yet. The host renders basic structure.

