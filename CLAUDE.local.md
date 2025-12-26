# DockDoor - Claude Code Context

## What This Is
macOS dock enhancement app providing window previews on dock hover, enhanced Alt+Tab switching, and Cmd+Tab overlays. Menu bar only app (no dock icon). GPL-3.0 licensed.

## Tech Stack
- Swift 5.10 / SwiftUI / AppKit
- Xcode project (not SPM-based app)
- Dependencies: Defaults (prefs), Sparkle (updates), Pow (animations), ScreenCaptureKit (live capture)

## IMPORTANT: Build & Run
**DO NOT run build commands.** The user builds and runs the app manually in Xcode.

## Adding New Files to Xcode
When creating a new Swift file, you MUST also add it to `DockDoor.xcodeproj/project.pbxproj`:
1. Generate a UUID: `uuidgen | tr -d '-'` (run twice - need one for file ref, one for build file)
2. Add a PBXFileReference entry for the file
3. Add a PBXBuildFile entry linking to the file reference
4. Add the file reference to the appropriate PBXGroup (directory)
5. Add the build file to PBXSourcesBuildPhase

## Project Structure
```
DockDoor/
├── DockDoor/              # Main source
│   ├── Utilities/         # Core logic - window management, dock observation, keybinds
│   │   └── Window Management/  # WindowUtil.swift is the central window API
│   ├── Views/
│   │   ├── Hover Window/  # Preview panels and window switcher UI
│   │   │   └── Shared Components/SharedPreviewWindowCoordinator.swift  # Main coordinator
│   │   └── Settings/      # Settings UI with Shared Components/
│   ├── Components/        # Reusable UI components
│   ├── Extensions/        # Swift type extensions
│   ├── consts.swift       # ALL user preferences (Defaults.Keys) - check here first for settings
│   └── AppDelegate.swift  # App lifecycle, coordinator init
├── BuildTools/            # SwiftFormat config
└── resources/             # Marketing assets
```

## Key Architecture
- **Coordinators pattern**: `SharedPreviewWindowCoordinator` manages preview windows, `PreviewStateCoordinator` handles UI state
- **DockObserver**: Monitors dock via AXObserver, triggers preview display
- **KeybindHelper**: Handles Alt+Tab and custom keybinds for window switching
- **WindowUtil**: Central static utilities for all window operations (discovery, focus, minimize)

## Critical Files
| File | Purpose |
|------|---------|
| `consts.swift` | 80+ user preference keys - ALWAYS check here for settings |
| `WindowUtil.swift` | Window discovery/manipulation via Accessibility APIs |
| `DockObserver.swift` | Dock hover detection and event routing |
| `SharedPreviewWindowCoordinator.swift` | Preview panel lifecycle management |
| `WindowPreviewHoverContainer.swift` | Complex interaction handling (47KB) |

## Conventions
- New settings go in `consts.swift` under `extension Defaults.Keys`
- Use `String(localized:comment:)` for user-facing strings
- UI state belongs in coordinators, not views
- Window operations go through `WindowUtil` static methods
- Reusable settings UI → `Views/Settings/Shared Components/`

## Permissions Required
- Accessibility (AXUIElement APIs for window management)
- Screen Recording (ScreenCaptureKit for live previews)
- Calendar (optional, for calendar widget)

## Don't
- Run xcodebuild or build commands - user runs in Xcode manually
- Modify `Localizable.xcstrings` directly - it's managed via Crowdin
- Add dock icon - app is `LSUIElement: true` (menu bar only)
- Use private APIs without checking `Utilities/Private APIs/` first
