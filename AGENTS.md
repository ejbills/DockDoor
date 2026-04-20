# DockDoor

macOS dock enhancement app — window previews on dock hover, Alt+Tab window switcher, Cmd+Tab overlay. Menu bar only (`LSUIElement: true`). Swift 5.10 / SwiftUI / AppKit. GPL-3.0.

## Build

Open `DockDoor.xcodeproj` in Xcode and build (Cmd+R). No CLI build commands — this is an Xcode-managed project, not SPM.

## Adding Files to the Project

Every new `.swift` file must be registered in `DockDoor.xcodeproj/project.pbxproj`:

1. Generate two UUIDs: `for i in 1 2; do uuidgen | tr -d '-'; done`
2. Add a `PBXFileReference` entry
3. Add a `PBXBuildFile` entry referencing it
4. Add the file ref to the correct `PBXGroup`
5. Add the build file to `PBXSourcesBuildPhase`

## Adding Settings

All user preferences are declared in `consts.swift` under `extension Defaults.Keys`.

**Every new setting must be indexed in the search system:**

1. Add a `.settingsSearchTarget("tab.settingName")` modifier to the control in the view:
   ```swift
   Toggle(isOn: $mySetting) {
       Text("My Setting")
   }
   .settingsSearchTarget("general.mySetting")
   ```

2. Add a catalog entry in `Views/Settings/Search/SettingsSearchCatalog.swift`:
   ```swift
   SettingsSearchItem(
       id: "general.mySetting",          // must match the search target
       title: String(localized: "My Setting"), // exact string from the view
       description: String(localized: "Optional description text"),
       keywords: ["internal", "search", "tokens"],
       tab: "General",                   // matches sidebar tab tag
       section: String(localized: "Section Header"),
       icon: "sf.symbol.name"
   )
   ```

3. If adding a new settings tab, also update `SettingsSearchEngine.swift` — add to `tabDisplayOrder` and `tabDisplayNames`.

### Rules

- `title` and `description` use `String(localized:)` with the **exact same literal** as the view — reuses existing translations
- `keywords` are internal English tokens only (not translated, not displayed)
- The `id` must match between the catalog entry and `.settingsSearchTarget()` call

## Localization

- Use `String(localized:comment:)` for user-facing strings
- Do not edit `Localizable.xcstrings` directly — managed via Crowdin
- macOS 13.0 minimum — use single-parameter `onChange { newValue in }` form

## Code Style

- No verbose comments — only comment non-obvious logic
- No doc comments unless the API is public and non-obvious
- UI state belongs in coordinators, not views
- Window operations go through `WindowUtil` static methods
- Reusable settings UI goes in `Views/Settings/Shared Components/`

## Key Files

| File | Purpose |
|------|---------|
| `consts.swift` | All user preference keys |
| `WindowUtil.swift` | Window discovery/manipulation (Accessibility APIs) |
| `DockObserver.swift` | Dock hover detection and event routing |
| `SharedPreviewWindowCoordinator.swift` | Preview panel lifecycle |
| `Views/Settings/Search/SettingsSearchCatalog.swift` | Settings search index |
