<style>
  h1:first-of-type {
    display: none;
  }
  .my-5 {
    margin: unset !important;
  }
  .markdown-body img {
    max-width: 50%;
  }
  @media (prefers-color-scheme: dark) {
    body {
      color-scheme: dark;
      color: white;
      background: transparent;
    }
    a, :link {
      color: #419cff;
    }
    a:active, link:active {
      color: #ff1919;
    }
  }
   .donation-link {
      display: inline-block;
      margin-top: 10px;
      padding: 5px 10px;
      background-color: #FFDD00;
      color: #000000 !important;
      text-decoration: none;
      font-size: 0.9em;
      font-weight: bold;
      border-radius: 3px;
    }
    .donation-link:hover {
      background-color: #E5C700;
    }
</style>
<div class="donation-link" target="_blank">☕ Support kepler.cafe at https://buymeacoffee.com/keplercafe</div>

<a id="v1.18.3"></a>
# [v1.18.3](https://github.com/ejbills/DockDoor/releases/tag/v1.18.3) - 2025-07-18

## 🐛 Bug Fixes

### Window Switcher MRU Ordering
* **Fixed critical window switcher bug**: Resolved issue where Window Switcher would incorrectly switch to unused windows of the same app instead of maintaining proper Most Recently Used (MRU) ordering
* **Improved window timestamp management**: Implemented a single point of entry for updating window timestamps, ensuring reliable and consistent MRU tracking
* **Enhanced cross-application switching**: Window Switcher now properly alternates between different applications without unexpectedly jumping to inactive windows of the same app

[Changes][v1.18.3]


<a id="v1.18.2"></a>
# [v1.18.2](https://github.com/ejbills/DockDoor/releases/tag/v1.18.2) - 2025-07-11

- Fixed issue where window timestamps weren't updating when clicking on dock icons or directly clicking on windows. The app now properly detects these interactions and updates only the specific window that was clicked, ensuring accurate MRU (Most Recently Used) ordering in the window switcher.

---
  Note: This addresses a remaining issue from the previous window ordering fix that was missed in the earlier release.

[Changes][v1.18.2]


<a id="v1.18.1"></a>
# [v1.18.1](https://github.com/ejbills/DockDoor/releases/tag/v1.18.1) - 2025-07-10

- Fixes window ordering 

[Changes][v1.18.1]


<a id="v1.18"></a>
# [v1.18](https://github.com/ejbills/DockDoor/releases/tag/v1.18) - 2025-07-02

🎯 New Features

  Windows-Style Navigation Enhancement
  - Improved keyboard navigation: Replace Shift+Tab with standalone Shift key for
  backwards navigation
  - Simplified controls: Tab always goes forward, Shift always goes backwards in
  Window Switcher

  Frontmost App Filtering
  - Active app only mode: New option to limit Window Switcher to show only windows
  from the currently active application
  - Fullscreen app blacklist: Prevent DockDoor key combinations when specific apps
  are in fullscreen mode

  🔧 Technical Improvements
  - Better keybind handling: Improved KeybindHelper with support for new navigation
   patterns
  - Window utility enhancements: Enhanced WindowUtil with frontmost app filtering
  capabilities
  - Better lyric timing

  📚 Documentation

  Website Updates
  - Updated keyboard shortcuts documentation: Reflect new Windows-style navigation
  behavior
  - Improved user guidance: Better documentation of new filtering and navigation
  features


[Changes][v1.18]


<a id="v1.17.3"></a>
# [v1.17.3](https://github.com/ejbills/DockDoor/releases/tag/v1.17.3) - 2025-06-24

- **Fixed preview window re-opening issue** - Resolved bug where preview windows would reappear after clicking an app icon and moving cursor away from dock
- Updates translations

[Changes][v1.17.3]


<a id="v1.17.2"></a>
# [v1.17.2](https://github.com/ejbills/DockDoor/releases/tag/v1.17.2) - 2025-06-24

### Fixed

- **Resolved orphaned windows remaining in the app switcher:** A persistent bug has been fixed where windows from applications that were already closed would incorrectly continue to appear in the window switcher.

[Changes][v1.17.2]


<a id="v1.17.1"></a>
# [v1.17.1](https://github.com/ejbills/DockDoor/releases/tag/v1.17.1) - 2025-06-22

- Fixes crash when pinning calendar
- Fixes dock hide manager positioning issue

[Changes][v1.17.1]


<a id="v1.17"></a>
# [v1.17](https://github.com/ejbills/DockDoor/releases/tag/v1.17) - 2025-06-19

## 🎵 New Features

### Audio Output Configuration
- **Added audio output selection** in expanded artwork mode for pinned media widgets
- ![CleanShot 2025-06-18 at 20 42 58](https://github.com/user-attachments/assets/8680e257-1bff-4c68-aadd-179b627fdac7)

### Lyric Experience
- **Improved lyric UX** with refined display and interaction patterns
- **Better synchronization** for more accurate lyric timing

[Changes][v1.17]


<a id="v1.16"></a>
# [v1.16](https://github.com/ejbills/DockDoor/releases/tag/v1.16) - 2025-06-18

## 🎵 New Features

### Lyric Mode for Pinned Media Controls
- **Added expandable lyric mode** to pinned media control widgets
- **Tap album artwork** on pinned widgets to expand and reveal additional controls
- **Lyrics toggle button** appears in expanded view to enable/disable lyric display
- **Real-time lyric synchronization** displays current lyrics alongside music playback
- **Seamless integration** works with existing pinned Spotify and Apple Music widgets

### Enhanced Pinned Widget Experience
- **Interactive album artwork** now serves as an expansion trigger for additional features
- **Expanded control panel** provides access to advanced media features beyond basic playback
- **Compact and expanded modes** allow users to choose between minimal and feature-rich widget displays
- **Persistent lyric display** remains active while widget is pinned and lyrics are enabled

## 🔧 Improvements
- **Optimized widget performance** maintains smooth operation even with lyric data processing
- **Optimized memory** by removing SwiftUI uses of .system() fonts which caused abandoned memory

## 🎬 Demo

![Clipboard-20250618-014356-811(1)](https://github.com/user-attachments/assets/756f3f45-f363-4ecc-b1a8-a9f6dadf1ed7)




[Changes][v1.16]


<a id="v1.15.2"></a>
# [v1.15.2](https://github.com/ejbills/DockDoor/releases/tag/v1.15.2) - 2025-06-16

- Resolves missing entitlements that prevented Apple Music and Spotify from displaying music controls

[Changes][v1.15.2]


<a id="v1.15.1"></a>
# [v1.15.1](https://github.com/ejbills/DockDoor/releases/tag/v1.15.1) - 2025-06-15

## 🔧 Improvements
- **Cleaned up DockObserver processing logic** for more reliable window placement detection
- **Refined window pinning logic** for more consistent floating widget behavior

## 🐛 Bug Fixes
- **Fixed various pinning bugs** that could cause inconsistent widget behavior
- **Improved reliability** of pin/unpin operations for floating widgets

## 📝 Notes
This patch release focuses on improving the core reliability of window detection and pinning systems introduced in v1.15.

[Changes][v1.15.1]


<a id="v1.15"></a>
# [v1.15](https://github.com/ejbills/DockDoor/releases/tag/v1.15) - 2025-06-14

## 🎨 New Features

### Floating Widget Controls
- **Pin special controls as desktop widgets** - Right-click on music and calendar controls to pin them as floating widgets
- **Persistent desktop presence** - Pinned controls remain visible on desktop for quick access without dock interaction
- **Widget-style behavior** - Pinned controls float above other windows and maintain their functionality
- **Easy unpinning** - Right-click pinned widgets to unpin and return to dock-only behavior
![CleanShot 2025-06-13 at 23 13 03@2x](https://github.com/user-attachments/assets/e3fc4a05-eda9-4555-93bb-548f62629a4c)
![CleanShot 2025-06-13 at 23 14 10@2x](https://github.com/user-attachments/assets/4ee3eb8c-16a0-4341-9880-6c490223687b)

### Global Padding Control
- **Added global padding control** for appearance customization
- **Fine-tune spacing** across all preview elements for personalized visual experience
- **Consistent padding application** throughout the interface for improved visual coherence

## 📝 Notes

This release introduces significant workflow enhancements, allowing users to transform dock previews into persistent desktop widgets. The floating widget feature is particularly useful for users who frequently interact with music controls or need quick calendar access throughout their workflow, eliminating the need to repeatedly hover over dock items.

[Changes][v1.15]


<a id="v1.14.4"></a>
# [v1.14.4](https://github.com/ejbills/DockDoor/releases/tag/v1.14.4) - 2025-06-13

## Fixed Apple Music Support
- **Fixed**: Apple Music artwork now properly converts binary data to base64 data URLs
- **Improved**: Error handling for artwork retrieval failures

[Changes][v1.14.4]


<a id="v1.14.3"></a>
# [v1.14.3](https://github.com/ejbills/DockDoor/releases/tag/v1.14.3) - 2025-06-13

## 🐛 Bug Fixes
-   Refined the display logic for special app controls (e.g., Music, Spotify, Calendar):
    -   When "Show media/calendar controls on Dock hover" (`showSpecialAppControls`) is enabled:
        -   If "Embed controls with window previews" (`useEmbeddedMediaControls`) is also enabled:
            -   Special controls will be embedded within the preview area alongside actual window previews if any are visible.
            -   If no window previews are visible (e.g., app has no open windows or all are minimized), the special controls will be shown in a larger, standalone embedded format.
        -   If "Embed controls with window previews" is disabled:
            -   The special controls will be shown in a larger, standalone format, replacing any window previews for that app.
    -   When "Show media/calendar controls on Dock hover" is disabled:
        -   Standard window previews will be shown for all apps, including those that have special controls available.
-   Updated the "Interaction & Behavior (Dock Previews)" section in Main Settings to include a new toggle for "Embed controls with window previews", which is active when "Show media/calendar controls on Dock hover" is enabled. This provides users with finer control over how these special app integrations are displayed.


[Changes][v1.14.3]


<a id="v1.14.2"></a>
# [v1.14.2](https://github.com/ejbills/DockDoor/releases/tag/v1.14.2) - 2025-06-13

## 🐛 Bug Fixes

### Music Controls Fixes
- **Fixed album artwork display issue** in Music app previews where artwork was not being shown properly
- **Resolved progress bar display** for music timestamps for international users

[Changes][v1.14.2]


<a id="v1.14.1"></a>
# [v1.14.1](https://github.com/ejbills/DockDoor/releases/tag/v1.14.1) - 2025-06-12

## 🐛 Bug Fixes
- **Extended lateral movement coverage** to the dismissal container for more consistent behavior

[Changes][v1.14.1]


<a id="v1.14"></a>
# [v1.14](https://github.com/ejbills/DockDoor/releases/tag/v1.14) - 2025-06-12

## 🎵 New Features

### Music Controls Integration
- **Added music preview controls** for Spotify and Apple Music when hovering over music apps in the dock
- **Now playing information** displays album artwork, track title, artist, and playback controls
- **Media control buttons** allow play/pause, skip forward/backward directly from the dock preview
- **Real-time synchronization** with current playback state and track information
- ![image](https://github.com/user-attachments/assets/06448a31-9116-4de8-9d42-f51eaf952d1c)

### Calendar Integration  
- **Added calendar preview** when hovering over the Calendar app in the dock
- **Daily events overview** shows upcoming events and appointments at a glance
- **Clean, intuitive interface** displays event times, titles, and calendar information
- **Quick schedule checking** without needing to open the Calendar app
- ![image](https://github.com/user-attachments/assets/321926af-6f99-4ba5-aaa1-ad99a5b21b33)

## 🐛 Bug Fixes

### Window Preview Issues
- **Fixed lateral movement behavior** where window previews would incorrectly persist when moving between dock items
- **Resolved issue** where apps with zero open windows would incorrectly display previews from previously hovered apps
- **Improved preview state management** to ensure consistent behavior when hovering over closed applications
- **Fixed race condition** in preview processing that could cause stale previews to remain visible

### Technical Improvements
- **Enhanced task cancellation** by properly resetting `isProcessing` flag when cancelling existing preview tasks
- **Improved preview reliability** by fixing defer block execution in cancelled operations
- **Better state management** prevents new preview requests from being blocked by stale state from previous operations

## 📝 Notes

- Music controls feature supports **Apple Music and Spotify only** due to Apple's restrictions on the MRMediaRemote private API (locked down in macOS 15.4)

[Changes][v1.14]


<a id="v1.13.1"></a>
# [v1.13.1](https://github.com/ejbills/DockDoor/releases/tag/v1.13.1) - 2025-06-04

### 🛠 Improvements & Fixes

* **Real-time Preview Updates**: Window previews in both the Dock Previews and Window Switcher now update immediately when windows are closed or new windows from an already previewed application are opened. This eliminates stale previews and ensures the UI accurately reflects the current window state.



[Changes][v1.13.1]


<a id="v1.13"></a>
# [v1.13](https://github.com/ejbills/DockDoor/releases/tag/v1.13) - 2025-06-02

It is my cat's 7th birthday 🎂
<img src="https://github.com/user-attachments/assets/bf6cba2d-643a-42cb-aa7c-d89c6a16800e" width="200" alt="Cat's 7th birthday celebration">

⚠️ This update changes a large amount of code. Be sure to report bugs if encountered.

### 🆕 What's New in DockDoor

* **Arrow Key Navigation**
  Navigate through windows in both the Window Switcher and Dock Previews using arrow keys and Tab, then press Return to select your desired window—perfect for keyboard-driven workflows.

* **Enhanced Keyboard Shortcuts**
  Added essential keyboard shortcuts to selected windows in previews: use Tab or arrow keys to select a window, then press `CMD + W` to close, `CMD + Q` to quit the app, or `CMD + M` to minimize—all without touching your mouse.

* **Improved Window State Management**
  Completely redesigned the underlying window tracking system using observed objects for better memory efficiency and more reliable window state synchronization across all views.

---

### 🛠 Improvements & Fixes

* **Performance Optimizations**
  - Refactored memory management by removing redundant window states
  - Implemented queued window switcher for smoother operation
  - Enhanced flow algorithm for better responsiveness

* **Window Tracking Reliability**
  - Fixed issue where closed windows would still appear in the Window Switcher
  - Improved window filter validation to ensure only active windows are displayed
  - Better activation attempt handling for more consistent behavior

* **Architecture Improvements**
  - Streamlined window state orchestration between dock previews and child window views
  - Reduced memory bloat by eliminating duplicate window object copies
  - Enhanced cross-view communication for better action synchronization

[Changes][v1.13]


<a id="v1.12.1"></a>
# [v1.12.1](https://github.com/ejbills/DockDoor/releases/tag/v1.12.1) - 2025-05-29

- Updates default dock buffer values

[Changes][v1.12.1]


<a id="v1.12"></a>
# [v1.12](https://github.com/ejbills/DockDoor/releases/tag/v1.12) - 2025-05-29

### 🆕 What's New in DockDoor

* **Keep Window Switcher Open**
  New option to keep the window switcher visible after releasing the shortcut key—great for slower switching or multitasking.

  ![Window Switcher](https://github.com/user-attachments/assets/1fc40025-b273-4bef-b7ac-3672b0bec156)

* **Settings Pane in Window Switcher**
  You can now access DockDoor settings directly from the window switcher.

* **Update Notification in Dock Previews**
  When a new DockDoor version is available, a handy **"Update available"** button will appear in Dock Previews.

* **"New Window" Button**
  Adds a new button that attempts to trigger `CMD + N` in the selected app. In some apps (like Finder), this opens a new window. In others, it might do something else—depends on the app.

  ![New Window Button](https://github.com/user-attachments/assets/07748c68-ac21-4b15-b93d-5e47313066db)

---

### 🛠 Improvements & Fixes

* Restored window filter validation logic.
* Refactored memory management for better performance.



[Changes][v1.12]


<a id="v1.11"></a>
# [v1.11](https://github.com/ejbills/DockDoor/releases/tag/v1.11) - 2025-05-20

- Updates app icon
- Adds experimental option to show hover window above app icon labels in the dock
![CleanShot 2025-05-20 at 15 37 57@2x](https://github.com/user-attachments/assets/5aebda35-b121-4795-9bfe-d8228d7eac70)
- Updates translations
- Fixes no dock preview for apps with multiple instances

[Changes][v1.11]


<a id="v1.10"></a>
# [v1.10](https://github.com/ejbills/DockDoor/releases/tag/v1.10) - 2025-05-17

- Entirely new settings design (thanks to [@apotenza92](https://github.com/apotenza92) for inspiration in settings design)
- - ![CleanShot 2025-05-17 at 13 48 10@2x](https://github.com/user-attachments/assets/ca22de6b-de36-4515-9e85-1b16974e3308)
- - Simplified settings and profiles for easy customization
- - ![CleanShot 2025-05-17 at 13 48 38@2x](https://github.com/user-attachments/assets/df5734af-c630-46bf-9f8f-890de0aa4ba0)
- - Live hover previews in the settings to make customization a breeze
- Middle mouse click on a window preview to close it
- Option to hide app name in window previews
- Misc. bug fixes

[Changes][v1.10]


<a id="v1.9.1"></a>
# [v1.9.1](https://github.com/ejbills/DockDoor/releases/tag/v1.9.1) - 2025-05-11

- Fixes window dismissal container logic

[Changes][v1.9.1]


<a id="v1.9"></a>
# [v1.9](https://github.com/ejbills/DockDoor/releases/tag/v1.9) - 2025-05-10

## New features
- Click app icon to minimize all windows of an app ([#505](https://github.com/ejbills/DockDoor/issues/505))
- - https://github.com/user-attachments/assets/e6deb2c9-0468-431d-9d40-66e959fc5df2
- - ![CleanShot 2025-05-10 at 11 22 21@2x](https://github.com/user-attachments/assets/db6105e5-9298-4bae-b7e7-6a0d2a0fd5fd)
- Remove DockDoor icon bouncing in dock with silent startup ([#539](https://github.com/ejbills/DockDoor/issues/539) thanks [@ShlomoCode](https://github.com/ShlomoCode))

## Bug fixes
- Window preview will be hidden on app icon click 
- Hide window when a click is outside of it's bounds
- Window preview showing under the dock ([#542](https://github.com/ejbills/DockDoor/issues/542))
- Ensure app re-attaches to Dock process if Dock is ever killed while DockDoor is running

[Changes][v1.9]


<a id="v1.8"></a>
# [v1.8](https://github.com/ejbills/DockDoor/releases/tag/v1.8) - 2025-05-05

- Window switcher performance improvements
- Window switcher control settings enhancements
- Misc. bug fixes

[Changes][v1.8]


<a id="v1.7.1"></a>
# [v1.7.1](https://github.com/ejbills/DockDoor/releases/tag/v1.7.1) - 2025-05-04

- Select windows while dragging files
- - In apps that support it, hovering over an app or preview while dragging a file will auto select target window.
- - ![Built-in Retina Display](https://github.com/user-attachments/assets/e85d136e-43bb-4874-abbb-7ecbfbc407f8)
- Better window capture logic
- - Majority of invalid windows will no longer be recorded (windows that are blank, chrome toolbars, UI elements, etc.)
- Some minor bug fixes and clean up

[Changes][v1.7.1]


<a id="v1.7"></a>
# [v1.7](https://github.com/ejbills/DockDoor/releases/tag/v1.7) - 2025-05-02

## What's Changed
* chore: better ux for sizing options (closes [#513](https://github.com/ejbills/DockDoor/issues/513))
* feat: customizable window inactivity timer
  - reworks event timeout to prevent preview flickering
  - reduces default inactivity timeout from 10 seconds to 1.5 seconds
  - closes [#472](https://github.com/ejbills/DockDoor/issues/472)
  - ![CleanShot 2025-05-02 at 06 47 12@2x](https://github.com/user-attachments/assets/ed1a6601-5dec-4bb4-b915-a443db31e14e)
* chore: sync website localizations with Crowdin 
* chore: sync macOS app localizations with Crowdin

**Full Changelog**: https://github.com/ejbills/DockDoor/compare/v1.6.2...v1.7

[Changes][v1.7]


<a id="v1.6.2"></a>
# [v1.6.2](https://github.com/ejbills/DockDoor/releases/tag/v1.6.2) - 2025-02-21

- Improved Window Focus Behavior: When classic ordering is enabled and there are at least two windows, the initial focus will now be set on the second window preview instead of the first for a smoother user experience. (thanks [@bestbandari](https://github.com/bestbandari))
- Fixed window switcher keybind failing after DockDoor remained open for long periods of time

[Changes][v1.6.2]


<a id="v1.6.1"></a>
# [v1.6.1](https://github.com/ejbills/DockDoor/releases/tag/v1.6.1) - 2025-01-09

- Fixes dock preview rendering too high when primary monitor was oriented vertically ([#447](https://github.com/ejbills/DockDoor/issues/447))
- Adds missing localization strings
- Syncs translations with Crowdin

[Changes][v1.6.1]


<a id="v1.6"></a>
# [v1.6](https://github.com/ejbills/DockDoor/releases/tag/v1.6) - 2025-01-09

# Changelog v1.6 🎉

## New Features
- **Aero Shake**
- - Shake window to minimize other/all windows
- - Configurable in General settings
- - ![aeroshake-ezgif com-speed](https://github.com/user-attachments/assets/afda2b3f-21ed-4bd0-b826-0205e02320b6)

- **Traffic Light Button Customizations**
- - New customization options for window controls in appearance settings, disable any of the buttons!
- - ![CleanShot 2025-01-08 at 16 12 36@2x](https://github.com/user-attachments/assets/6fe2bb44-f43a-42c4-9f40-313ebd66b523)

## Bug Fixes
- Fixed window switcher ordering. Windows will no longer be erratically shuffled.
- Fixed window flow breaking when extending off screen
- Fixed flow container being artificially capped at 3 rows
- Resolved lateral movement issues with non-running applications in dock
- Corrected window registration timing on application launch

## Enhancements
- Window sizing controls visualization
- Reworded and moved some settings options
- Windows now registered in DockDoor upon creation
- Quicker tabbing animation in window switcher
- Updated localizations via Crowdin integration

[Changes][v1.6]


<a id="v1.5.1"></a>
# [v1.5.1](https://github.com/ejbills/DockDoor/releases/tag/v1.5.1) - 2025-01-03

- Fixes preview intermittently failing to present when hovering over app icon
- Reworked "See full preview" hover action to display window previews at their exact size and position on the correct monitor, matching the real window's dimensions and location for a more accurate preview experience. 
- - This provides better context when switching between windows and eliminates scaling issues on large displays.
- Reduces memory usage

[Changes][v1.5.1]


<a id="v1.5"></a>
# [v1.5](https://github.com/ejbills/DockDoor/releases/tag/v1.5) - 2024-12-30

**This is a big update, folks.** 
这是一个重大更新。C'est une mise à jour majeure. Questo è un importante aggiornamento. Esta es una actualización importante.

If you find DockDoor helpful in your daily workflow, please consider supporting its development at https://buymeacoffee.com/keplercafe. Your contribution helps keep the project alive and growing! ❤️

# Changelog v1.5 🎉
## New Features
- **Window Switcher Enhancements**
 - - Completely redesigned interface with app titles and customizable window controls
 - - Screen placement options (mouse position, specific screen, or last active window)
 - - Dimmed inactive windows option
 - -  ![window switcher redesign](https://github.com/user-attachments/assets/b074d07e-7cc2-4d36-bd6a-ac571d5c0b1b)
- **Flow Container**
 - - Multi-row window preview layout for better organization of many windows
 - - Customizable row count for preview display
 - - ![CleanShot 2024-12-30 at 13 33 42@2x](https://github.com/user-attachments/assets/4c83e163-77ec-4795-bf85-018190623f56)
- - ![dockdoor flow container(1)](https://github.com/user-attachments/assets/bdc373bc-a171-40fc-9dbc-c4cc2562488a)
- Adjustable selection highlight color and opacity
- Added "Close All" and "Minimize All" window management options, on hover of app title.
- **This update has many customization options, take a look!**
- - To see it in motion, view the video here: https://youtu.be/ReEPCWaomlY
## Enhancements
- Myriad of UI/UX changes
- Optimized memory usage through removal of outdated cache code
- Support for custom application directories in filters
- Improved window capture system for better stability
- Enhanced dark mode support for capsule rendering
- Updated localizations via Crowdin integration
- Minimized and hidden window previews will now have refreshed screenshots
## Bug Fixes
- Resolved minimum window sizing for edge cases
- Fixed application filtering for apps outside `/Applications` folder
- Addressed preview display issues with minimized windows
- Corrected window positioning when closing windows
- Fixed popover window title rendering
- Many other bug fixes

[Changes][v1.5]


<a id="v1.4"></a>
# [v1.4](https://github.com/ejbills/DockDoor/releases/tag/v1.4) - 2024-12-22

# Changelog v1.4 🎄

## New Features
- **Window Dragging**:
  - Drag and reposition windows directly from DockDoor previews onto your macOS desktop.
  - ![window drag](https://github.com/user-attachments/assets/772ba9ad-84fd-41c5-9599-4069f6e80288)
- **Window Title Filters and Application Filters**:
  - Exclude windows or applications from being captured based on title or app name.
  - Example: Filtering "google" prevents windows containing "google" in their title from being managed.
  - ![CleanShot 2024-12-21 at 22 53 17](https://github.com/user-attachments/assets/b81df915-f082-49ff-8324-817bebce9e03)
- **Window Switcher option**:
  - Holding `Command` and pressing `Tab` twice now switches to the second last used window, addressing usability feedback.
  - ![image](https://github.com/user-attachments/assets/ae9e2221-5dd9-4676-9e13-b5f541eb1a04)

## Enhancements
- Less lingering windows!
  - Auto-dismissal of inactive window previews after 10 seconds to avoid clutter.
  - Improved preview dismissal logic when clicking outside the window area.
- Centered window previews relative to the current Dock icon for more reliable window placements.
- Improved user experience in keybind recording view.
- Refined settings placements for better navigation and discoverability.
- Enhanced permission messaging for clearer instructions.
- Synchronized localizations for both the macOS app and website with Crowdin.

## Bug Fixes
- Resolved window preview sizing issues across multiple displays.
- Fixed scaling for windows intersecting multiple screens.
- Dismissal of hover containers now properly occurs when interacting outside the window.
- Fixed gradient alerts to ensure proper localization.
- Addressed issues with window switcher behavior during initial app launch and desktop space switches.

[Changes][v1.4]


<a id="v1.3.3"></a>
# [v1.3.3](https://github.com/ejbills/DockDoor/releases/tag/v1.3.3) - 2024-12-07

# Changelog

## Fixes
- Fixed window presentation delay issues
- - Users with long hover delay times will no longer experience hanging windows
- Default "prevent dock hide" functionality is now disabled by default due to windows resizing
- Fixed missing window close animations when using traffic light buttons
- Fixed delayed window presentation timing
- Corrected issue where dockdoor settings window didn't close before new window presentation

## Chores
- Added clarifying comments for lingering window detection
- Updated macOS app localizations via Crowdin sync ([#389](https://github.com/ejbills/DockDoor/issues/389))

[Changes][v1.3.3]


<a id="v1.3.2"></a>
# [v1.3.2](https://github.com/ejbills/DockDoor/releases/tag/v1.3.2) - 2024-11-30

- Fixes issue where dock stays visible when not invoking previews when '_Ignore Apps with One Window_' option is checked
- Moved '_Include Hidden and Minimized Windows in the Window Switcher_' option to Window Switcher category

[Changes][v1.3.2]


<a id="v1.3.1"></a>
# [v1.3.1](https://github.com/ejbills/DockDoor/releases/tag/v1.3.1) - 2024-11-29

# 🦃 Changelog

## Features
- Dock with auto-hide enabled will now remain open when interacting with window previews (changable in settings)
- Window switcher now has option to exclude hidden and minimized windows
- Window selection is now more visually prominent

## Fixes
- Window previews now work properly with custom dock animation speeds ([#297](https://github.com/ejbills/DockDoor/issues/297))
- Window previews no longer disappear when moving between windows/apps ([#364](https://github.com/ejbills/DockDoor/issues/364))
- - This fixes the frustrating behavior where previews would vanish during normal window navigation.
- Windows can now be activated correctly when dock is set to auto-hide ([#371](https://github.com/ejbills/DockDoor/issues/371))
- Window previews now properly dismiss when moving cursor away ([#374](https://github.com/ejbills/DockDoor/issues/374))
- Slider fields now show decimal values for more precise control

## Chores
- Added Portuguese (Brazil) translation to https://dockdoor.net ([#383](https://github.com/ejbills/DockDoor/issues/383))
- Updated all system translations via Crowdin ([#377](https://github.com/ejbills/DockDoor/issues/377), [#386](https://github.com/ejbills/DockDoor/issues/386))

[Changes][v1.3.1]


<a id="v1.3"></a>
# [v1.3](https://github.com/ejbills/DockDoor/releases/tag/v1.3) - 2024-11-22

# Changelog

## 🚀 New Features
- **Window Preview Preservation**: Preview will no longer hide when traffic light buttons are used to manage window state ([#376](https://github.com/ejbills/DockDoor/issues/376))
- **Natural Mouse Movement**: Allow natural lateral mouse movements between active app icons
- Added app icon and app title information to window switcher

## 🛠️ Fixes
- **Window Cache Management**: Regularly purge invalid cached windows
- **Window Closing**: Fixed handling of invalid dock notifications for window closure
- **Window Sizing**: Improved UX for window sizing options (is now a slider based on screen dimensions)

## 🧹 Chores
- **macOS Localization**: Synced macOS app localizations with Crowdin ([#369](https://github.com/ejbills/DockDoor/issues/369))
- **Website Localization**: Synced website localizations with Crowdin ([#370](https://github.com/ejbills/DockDoor/issues/370))

## ↩️ Reverts
- Reverted fix for invalid dock notification window closure handling

[Changes][v1.3]


<a id="v1.2.9"></a>
# [v1.2.9](https://github.com/ejbills/DockDoor/releases/tag/v1.2.9) - 2024-09-17

- Fixes a bug where windows in the cache were not being properly updated

[Changes][v1.2.9]


<a id="v1.2.8"></a>
# [v1.2.8](https://github.com/ejbills/DockDoor/releases/tag/v1.2.8) - 2024-09-13

We now have a website, it was created by the wonderful [@illavoluntas](https://github.com/illavoluntas)! https://dockdoor.net

# Changelog

## 🚀 New Features

- **Ignore Single-Window Apps**: Added an option to ignore apps that only have one window, improving focus on multi-window applications.

## 🎨 Redesigns

- **Update Page**: Redesigned the update page for a more modern and intuitive user experience.

## 🛠️ Fixes

- **Date Window Sorting**: Fixed an issue with sorting windows by date, ensuring correct chronological order.
- **Window Info Fetching**: Refactored the `fetchWindowInfo` method for improved performance and reliability.
- **Resizable Settings Pane**: Enabled the settings pane to be resized and adjusted the layout for slider settings to improve usability.
- **Localized Strings**: Fixed an issue where localized strings sometimes did not fit properly within UI elements.

## 🛠️ Chores

- **Localization Sync**: Synced macOS app localizations with Crowdin, keeping translations up to date ([#318](https://github.com/ejbills/DockDoor/issues/318)).
- **Website Localization Sync**: Updated website localizations using Crowdin ([#316](https://github.com/ejbills/DockDoor/issues/316)).


[Changes][v1.2.8]


<a id="v1.2.7"></a>
# [v1.2.7](https://github.com/ejbills/DockDoor/releases/tag/v1.2.7) - 2024-09-13

# Changelog

No more dock alignment issues. It will now be placed accurately 100% of the time.

## 🛠️ Fixes

- **Dock Item Hover Preview**: The hover preview is now placed using the Dock item’s Accessibility (AX) element, ensuring accurate positioning even on multi-monitor setups ([#277](https://github.com/ejbills/DockDoor/issues/277)).


[Changes][v1.2.7]


<a id="v1.2.6"></a>
# [v1.2.6](https://github.com/ejbills/DockDoor/releases/tag/v1.2.6) - 2024-09-10

# Changelog

## 🚀 New Features

- **Help Settings**: Introduced a new section in the settings to provide help and support to users.

## 🛠️ Fixes

- **Window Validation**: Fixed an issue where windows were not properly validated when a window UI element was changed ([#310](https://github.com/ejbills/DockDoor/issues/310)).
- **Fluid Gradient Package Removal**: Removed the fluid gradient package in favor of a custom implementation to fix a small memory leak.


[Changes][v1.2.6]


<a id="v1.2.5"></a>
# [v1.2.5](https://github.com/ejbills/DockDoor/releases/tag/v1.2.5) - 2024-09-08

- ⚠️ Note: Fixes critical v1.2.4 crash. 
- ⚠️ This update sets the default app name label style to "embedded" and changes the window switcher keybind to Option + Tab. You can customize these settings if preferred.

# Changelog

## 🚀 New Features

- **Custom Menu Bar Icon**: Introduced a custom menu bar icon for DockDoor, offering a fresh, distinct look for users.
- **Embedded App Title Style**: The embedded app title style is now set as the default, providing a more cohesive visual experience.

## 🎨 Redesigns

- **First-Time Launch Experience**: Completely redesigned the first-time launch flow of DockDoor for a more intuitive and modern onboarding experience.
- **Permissions View**: Redesigned the permissions view for clarity and ease of use, enhancing the overall user experience.

## 🛠️ Changes

- **Window Switcher Keybind Change**: The window switcher now defaults to `Option + Tab` instead of `Command + Tab`.

## 🎨 Visual Updates

- **New App Icon**: Introduced another new icon, giving DockDoor a fresh, updated look.


[Changes][v1.2.5]


<a id="v1.2.3"></a>
# [v1.2.3](https://github.com/ejbills/DockDoor/releases/tag/v1.2.3) - 2024-09-05

- Adds option to disable window sorting - [#292](https://github.com/ejbills/DockDoor/issues/292) 

[Changes][v1.2.3]


<a id="v1.2.2"></a>
# [v1.2.2](https://github.com/ejbills/DockDoor/releases/tag/v1.2.2) - 2024-09-04

- Fixes far windows being impossible to reach [#291](https://github.com/ejbills/DockDoor/issues/291) 

[Changes][v1.2.2]


<a id="v1.2.1"></a>
# [v1.2.1](https://github.com/ejbills/DockDoor/releases/tag/v1.2.1) - 2024-09-04

- Fixes windows having wrong size while they are not in the main screen [#288](https://github.com/ejbills/DockDoor/issues/288) 

[Changes][v1.2.1]


<a id="v1.2.0"></a>
# [v1.2.0](https://github.com/ejbills/DockDoor/releases/tag/v1.2.0) - 2024-09-04

# Changelog

## 🚀 New Features

- **Efficient Dock Item Detection and Improved Window Management**: [@ShlomoCode](https://github.com/ShlomoCode), [@ejbills](https://github.com/ejbills) 
  - **Dock Item Detection**: The current Dock item is now detected using macOS Dock's native detection (`kAXSelectedChildrenChangedNotification` and `kAXSelectedChildrenAttribute`) instead of relying on mouse position calculations.
  - **Performance Improvement**: Removed the global listener for mouse events, which significantly reduces CPU usage to 0% when not interacting or hovering with the Dock.
  - **Window Cache Management**: Windows are now cached by PID instead of BundleID, improving compatibility with apps like scrcpy that do not have a BundleID.
  - **Window State Management**: Enhanced logic for managing window states, including addressing window switcher update inconsistencies.
  - **Window Fade Out Animations**: Introduced window fade-out animations and added configuration options for customization.

## 🛠️ Fixes

- **Fix Window Close Update**: Resolved an issue where the window was not updating its state upon closing. - [@ejbills](https://github.com/ejbills)
- **Window Placement and Configuration**: Fixed inaccurate window placement and configuration when using SCWindow. - [@ejbills](https://github.com/ejbills)
- **Invisible Window Switcher**: Corrected an issue where the window switcher would become invisible under certain conditions. - [@ejbills](https://github.com/ejbills)
- **Window Raise and Matching Logic**: Addressed problems with the logic that raises windows and matches them correctly. - [@ejbills](https://github.com/ejbills)
- **Window Switcher Update Inconsistency**: Fixed inconsistencies when updating the window switcher. - [@ejbills](https://github.com/ejbills)

## 🧹 Chores

- **Localization Sync**: Regular synchronization of localizations with Crowdin. [[#286](https://github.com/ejbills/DockDoor/issues/286), [#287](https://github.com/ejbills/DockDoor/issues/287)] - [@ejbills](https://github.com/ejbills), [@crowdin-bot](https://github.com/crowdin-bot)
- **Remove Unused Methods and Code**: Cleaned up the codebase by removing unused methods and outdated logic. - [@ejbills](https://github.com/ejbills)
- **Update Appcast for 1.1.6**: Updated the appcast to point to the patched version 1.1.6. - [@ejbills](https://github.com/ejbills)
- **Improve Button Reliability**: Enhancements were made to improve the reliability of buttons within the application. - [@ejbills](https://github.com/ejbills)

## 🎨 Refactor

- **Window Dismissal Improvements**: Applied debounce cancellation logic and refined mouse position checks to improve window dismissal. - [@ejbills](https://github.com/ejbills)
- **Smart Distance Threshold**: Implemented a smart distance threshold for hiding lingering windows. - [@ejbills](https://github.com/ejbills)

### Shoutout to [@ShlomoCode](https://github.com/ShlomoCode) for his amazing contributions!


[Changes][v1.2.0]


<a id="v1.1.6"></a>
# [v1.1.6](https://github.com/ejbills/DockDoor/releases/tag/v1.1.6) - 2024-08-30

## 🛠️ Fixes

- **Window Switcher Lag**: Resolved lag issues when switching windows, enhancing overall responsiveness. [[#280](https://github.com/ejbills/DockDoor/issues/280)] - [@ejbills](https://github.com/ejbills)
- **Previous Traffic Light Buttons Position**: Updated the logic to correctly position traffic light buttons on the “OK” dialog. [[#271](https://github.com/ejbills/DockDoor/issues/271)] - [@ShlomoCode](https://github.com/ShlomoCode)
- **Gradient Twitching**: Fixed an issue where gradients would twitch when using DockDoor within a fullscreen application. [[#267](https://github.com/ejbills/DockDoor/issues/267)] - [@ejbills](https://github.com/ejbills)
- **RTL Layout Rendering**: Corrected the right-to-left layout rendering for user-defined element positions. [[#262](https://github.com/ejbills/DockDoor/issues/262)] - [@ShlomoCode](https://github.com/ShlomoCode)
- **Bring Window to Front Logic**: Restored the original logic for bringing windows to the front, improving window management. [[#246](https://github.com/ejbills/DockDoor/issues/246)] - [@ShlomoCode](https://github.com/ShlomoCode)

## 🚀 New Features

- **macOS 13 Ventura Support**: Added full support for macOS 13 Ventura. [[#267](https://github.com/ejbills/DockDoor/issues/267)] - [@ShlomoCode](https://github.com/ShlomoCode), [@ejbills](https://github.com/ejbills)
- **Customizable Highlight Gradient Colors**: Introduced customizable highlight gradient colors for enhanced user interface personalization. [[#265](https://github.com/ejbills/DockDoor/issues/265)] - [@ejbills](https://github.com/ejbills)
- **Escape to Close Preview**: Added the ability to press the Escape key to close the preview window, streamlining user interactions. [[#255](https://github.com/ejbills/DockDoor/issues/255)] - [@ShlomoCode](https://github.com/ShlomoCode)

## 🔧 Maintenance

- **Localization Sync**: Regular synchronization of localizations with Crowdin to keep translations up-to-date. [[#270](https://github.com/ejbills/DockDoor/issues/270)], [[#266](https://github.com/ejbills/DockDoor/issues/266)], [[#263](https://github.com/ejbills/DockDoor/issues/263)], [[#249](https://github.com/ejbills/DockDoor/issues/249)] - [@ejbills](https://github.com/ejbills), [@crowdin-bot](https://github.com/crowdin-bot)
- **Format Preservation**: Preserved unused arguments in code formatting to maintain consistency. [[#252](https://github.com/ejbills/DockDoor/issues/252)] - [@ShlomoCode](https://github.com/ShlomoCode)
- **Localizable.xcstrings Update**: Updated the Localizable.xcstrings file with new keys to support additional translations. [[#255](https://github.com/ejbills/DockDoor/issues/255)] - [@ShlomoCode](https://github.com/ShlomoCode)
- **SwiftFormat Lint**: Integrated SwiftFormat linting to ensure consistent code style. [[#250](https://github.com/ejbills/DockDoor/issues/250)] - [@ShlomoCode](https://github.com/ShlomoCode)
- **Autogenerated Xcode File Headers**: Removed unnecessary autogenerated file headers in Xcode for cleaner codebase. [[#251](https://github.com/ejbills/DockDoor/issues/251)] - [@ShlomoCode](https://github.com/ShlomoCode)
- **CNAME Management**: Created and deleted CNAME records as part of domain management efforts. - [@ejbills](https://github.com/ejbills)

## 🛠️ Refactoring

- **AXUIElement Extension**: Refactored code to use an `AXUIElement` extension for improved accessibility and cleaner code. [[#242](https://github.com/ejbills/DockDoor/issues/242)] - [@ShlomoCode](https://github.com/ShlomoCode)


[Changes][v1.1.6]


<a id="v1.1.5"></a>
# [v1.1.5](https://github.com/ejbills/DockDoor/releases/tag/v1.1.5) - 2024-08-02

# Changelog
## Features
- Introducing ability to track & navigate to windows from all applications across all spaces, along with support for window previews on minimized and hidden windows. [@hasansultan92](https://github.com/hasansultan92) & [@ejbills](https://github.com/ejbills) 
- - Note: This is the initial rollout of this feature and things may be buggy. Please report any bugs you encounter. It works as follows: as you navigate, window states are tracked and stored across spaces, allowing support for windows in other spaces, along with tracking minimized and hidden windows (which are displayed in a faded-greyed out look in the window preview).
- Restart the app when needed instead of just quitting [@ShlomoCode](https://github.com/ShlomoCode)
- Open app settings by relaunch [@ShlomoCode](https://github.com/ShlomoCode)
- Add ability to choose traffic light buttons position [@ShlomoCode](https://github.com/ShlomoCode)
- Add quit button [@ShlomoCode](https://github.com/ShlomoCode)
## Fixes
- Disable fullscreen button in settings window [@ShlomoCode](https://github.com/ShlomoCode)
- Use decimalFormatter in 'preview hover delay' setting [@ShlomoCode](https://github.com/ShlomoCode)
## Chore
- Sync localizations with Crowdin [@ejbills](https://github.com/ejbills)
- Clearer wording in settings [@ShlomoCode](https://github.com/ShlomoCode)
- GitHub issue template enforcement [@ejbills](https://github.com/ejbills)
- Add manual run ability to stale issues action [@ejbills](https://github.com/ejbills)
- Create pull request template [@ejbills](https://github.com/ejbills)
- Add Homebrew installation instructions [@ejbills](https://github.com/ejbills)
- Show copy button for brew command [@ShlomoCode](https://github.com/ShlomoCode)

[Changes][v1.1.5]


<a id="v1.1.4"></a>
# [v1.1.4](https://github.com/ejbills/DockDoor/releases/tag/v1.1.4) - 2024-07-16

# Changelog

## Fixes
- No longer filter out windows with empty titles
- Blurry window preview images
- Traffic light buttons visibility picker width ([#193](https://github.com/ejbills/DockDoor/issues/193)) [@ShlomoCode](https://github.com/ShlomoCode)

## Chore
- Clearer wording in settings ([#194](https://github.com/ejbills/DockDoor/issues/194)) [@ShlomoCode](https://github.com/ShlomoCode)
- Typo in settings ([#197](https://github.com/ejbills/DockDoor/issues/197)) [@ShlomoCode](https://github.com/ShlomoCode)

[Changes][v1.1.4]


<a id="v1.1.3"></a>
# [v1.1.3](https://github.com/ejbills/DockDoor/releases/tag/v1.1.3) - 2024-07-16

# Changelog

## Features
- Add option to select window title visibility (whenOveringPreview/alwaysVisible) ([#188](https://github.com/ejbills/DockDoor/issues/188)) [@ShlomoCode](https://github.com/ShlomoCode)
- [SharedPreviewWindowCoordinator] add fall back ([#186](https://github.com/ejbills/DockDoor/issues/186)) [@chrisharper22](https://github.com/chrisharper22)
- Center Dock Tile Preview horizontally/vertically to icon ([#182](https://github.com/ejbills/DockDoor/issues/182)) [@chrisharper22](https://github.com/chrisharper22)
- Clearer wording ([#181](https://github.com/ejbills/DockDoor/issues/181)) [@ShlomoCode](https://github.com/ShlomoCode)
- Suggest users contribute translations ([#178](https://github.com/ejbills/DockDoor/issues/178)) [@ShlomoCode](https://github.com/ShlomoCode)
- Improve settings layout ([#175](https://github.com/ejbills/DockDoor/issues/175)) [@ShlomoCode](https://github.com/ShlomoCode)
- Add app icon to readme ([#176](https://github.com/ejbills/DockDoor/issues/176)) [@ShlomoCode](https://github.com/ShlomoCode)

## Fixes
- Lingering full screen preview in certain scenarios
- Minimized and hidden windows showing empty squircle

## Refactor
- HoverTimerActions -> PreviewHoverAction ([#173](https://github.com/ejbills/DockDoor/issues/173))

## Chore
- License change from MIT to GPL-3.0 ([#191](https://github.com/ejbills/DockDoor/issues/191))
- Add release publish to crowdin sync action
- Sync localizations with Crowdin [@ejbills](https://github.com/ejbills) [@crowdin-bot](https://github.com/crowdin-bot)

[Changes][v1.1.3]


<a id="v1.1.2"></a>
# [v1.1.2](https://github.com/ejbills/DockDoor/releases/tag/v1.1.2) - 2024-07-12

# Changelog

## Features
- Preview window hover actions, with time and action customizations ([#171](https://github.com/ejbills/DockDoor/issues/171))
- ![popup preview](https://github.com/user-attachments/assets/bd6ee1c8-3cff-492a-8d60-b4c40157f908)
- More localizations! You can now contribute to the translation here: https://crowdin.com/project/dockdoor/invite?h=895e3c085646d3c07fa36a97044668e02149115
- Make more strings localizable ([#168](https://github.com/ejbills/DockDoor/issues/168)) [@ShlomoCode](https://github.com/ShlomoCode)
- Settings: scale pickers and add number fields next to sliders ([#170](https://github.com/ejbills/DockDoor/issues/170)) [@ShlomoCode](https://github.com/ShlomoCode)
- Add top right window title position option ([#150](https://github.com/ejbills/DockDoor/issues/150)) [@ShlomoCode](https://github.com/ShlomoCode)
- Crowdin localization and automation ([#155](https://github.com/ejbills/DockDoor/issues/155))
- Add Crowdin localization support and actions ([#151](https://github.com/ejbills/DockDoor/issues/151))

## Fixes
- Local labels are cutting ([#169](https://github.com/ejbills/DockDoor/issues/169)) [@ShlomoCode](https://github.com/ShlomoCode) [@ejbills](https://github.com/ejbills)
- Better setting names for preview hover action items
- Release notes loading ([#148](https://github.com/ejbills/DockDoor/issues/148)) [@ShlomoCode](https://github.com/ShlomoCode)
- Invalid formatting in changelog ([#147](https://github.com/ejbills/DockDoor/issues/147)) [@ShlomoCode](https://github.com/ShlomoCode)

## Chore
- Sync localizations with Crowdin ([#165](https://github.com/ejbills/DockDoor/issues/165)) [@ejbills](https://github.com/ejbills) [@crowdin-bot](https://github.com/crowdin-bot)
- Set commit_message in crowdin-sync.yml ([#158](https://github.com/ejbills/DockDoor/issues/158)) [@ShlomoCode](https://github.com/ShlomoCode)
- Initialize workflow file on main branch
- Revert "fix: invalid formatting in changelog ([#147](https://github.com/ejbills/DockDoor/issues/147))" ([#149](https://github.com/ejbills/DockDoor/issues/149))
- Patch: Update crowdin-sync.yml to not run based on push to main (was creating loop) ([#167](https://github.com/ejbills/DockDoor/issues/167))
- New Crowdin translations by GitHub Action ([#156](https://github.com/ejbills/DockDoor/issues/156)) [@ejbills](https://github.com/ejbills) [@crowdin-bot](https://github.com/crowdin-bot)

[Changes][v1.1.2]


<a id="v1.1.1"></a>
# [v1.1.1](https://github.com/ejbills/DockDoor/releases/tag/v1.1.1) - 2024-07-11

# Changelog

## Features
- Update app icon to new design (Thanks to the awesome artwork by [@VisualisationExpo](https://github.com/VisualisationExpo))
- Traffic light button display customization options
- Make traffic lights symbols dark in light theme ([#135](https://github.com/ejbills/DockDoor/issues/135)) [@ShlomoCode](https://github.com/ShlomoCode)
- Added customization options for Window Titles ([#128](https://github.com/ejbills/DockDoor/issues/128)) [@chrisharper22](https://github.com/chrisharper22)
- Improve release notes style ([#125](https://github.com/ejbills/DockDoor/issues/125)) [@ShlomoCode](https://github.com/ShlomoCode)
- Show changelog in in-app update ([#120](https://github.com/ejbills/DockDoor/issues/120)) [@ShlomoCode](https://github.com/ShlomoCode)
- Localize to FR ([#115](https://github.com/ejbills/DockDoor/issues/115)) [@illavoluntas](https://github.com/illavoluntas)
- Focus when unminimized ([#118](https://github.com/ejbills/DockDoor/issues/118)) [@UnknownCrafts](https://github.com/UnknownCrafts)

## Fixes
- Incorrect placement of traffic light setting
- Window should not be draggable
- Accidentally deleted download link from readme
- Chrome PWA's ([#126](https://github.com/ejbills/DockDoor/issues/126)) [@ShlomoCode](https://github.com/ShlomoCode)
- Sparkle release notes in dark mode ([#124](https://github.com/ejbills/DockDoor/issues/124)) [@ShlomoCode](https://github.com/ShlomoCode)

## Refactor
- Replace numeric enums with named enums; reword keys and variables ([#141](https://github.com/ejbills/DockDoor/issues/141)) [@ShlomoCode](https://github.com/ShlomoCode)

## Chore
- Update he localization ([#143](https://github.com/ejbills/DockDoor/issues/143)) [@ShlomoCode](https://github.com/ShlomoCode)
- Add readme badges
- Remove useless maxwidth
- Create xcscheme file ([#127](https://github.com/ejbills/DockDoor/issues/127)) [@ShlomoCode](https://github.com/ShlomoCode)
- Create pr-lint.yml ([#122](https://github.com/ejbills/DockDoor/issues/122)) [@ShlomoCode](https://github.com/ShlomoCode)

[Changes][v1.1.1]


<a id="v1.1.0"></a>
# [v1.1.0](https://github.com/ejbills/DockDoor/releases/tag/v1.1.0) - 2024-07-09

## Features
- Add Hover App Title Styling options ([#101](https://github.com/ejbills/DockDoor/pull/101)) ([@chrisharper22](https://github.com/chrisharper22))
- - ![image](https://github.com/ejbills/DockDoor/assets/74191134/1e34a398-2f6f-4a6b-ba23-6893f6e2d17a)
- - ![image](https://github.com/ejbills/DockDoor/assets/74191134/eec2c1a2-912e-40d1-9ca3-f1f87dfc7c3c)
- Window title alignment option
- Use "hidden" word for window title hidden style ([#112](https://github.com/ejbills/DockDoor/pull/112)) ([@ShlomoCode](https://github.com/ShlomoCode))
- Subtle traffic light buttons
- Add an "Appearance" tab in app settings ([#106](https://github.com/ejbills/DockDoor/pull/106)) ([@ShlomoCode](https://github.com/ShlomoCode))
- Make more strings localizable ([#105](https://github.com/ejbills/DockDoor/pull/105), [#102](https://github.com/ejbills/DockDoor/pull/102)) ([@ShlomoCode](https://github.com/ShlomoCode))
- Localize Hebrew ([#100](https://github.com/ejbills/DockDoor/pull/100)) ([@ShlomoCode](https://github.com/ShlomoCode))
- Close preview when dock icon is clicked ([#62](https://github.com/ejbills/DockDoor/pull/62)) ([@ShlomoCode](https://github.com/ShlomoCode))

## Fixes
- Show menu bar icon only on app reopen, not on interact ([#98](https://github.com/ejbills/DockDoor/pull/98)) ([@ShlomoCode](https://github.com/ShlomoCode))
- OpenDelay display format ([#99](https://github.com/ejbills/DockDoor/pull/99)) ([@ShlomoCode](https://github.com/ShlomoCode))

## Other
- Remove xcuserdata files ([#113](https://github.com/ejbills/DockDoor/pull/113)) ([@ShlomoCode](https://github.com/ShlomoCode))
- Scale effect

[Changes][v1.1.0]


<a id="v1.0.17"></a>
# [v1.0.17](https://github.com/ejbills/DockDoor/releases/tag/v1.0.17) - 2024-07-08

- Fixes bug: Impossible to use Tab with default MacOS keybind activated ([#92](https://github.com/ejbills/DockDoor/issues/92)) [@hasansultan92](https://github.com/hasansultan92) 
- Adds option to not use uniform window radius, so that you can see an entire window preview without it getting cropped. ([#93](https://github.com/ejbills/DockDoor/pull/93)) [@ShlomoCode](https://github.com/ShlomoCode) 

[Changes][v1.0.17]


<a id="v1.0.16"></a>
# [v1.0.16](https://github.com/ejbills/DockDoor/releases/tag/v1.0.16) - 2024-07-08

- Adds window switcher key bind customization (thanks to [@hasansultan92](https://github.com/hasansultan92))
- Show menu bar icon when app icon is clicked (thanks to [@ShlomoCode](https://github.com/ShlomoCode))
- Fixes the title label UI flashing on hover

[Changes][v1.0.16]


<a id="v1.0.15"></a>
# [v1.0.15](https://github.com/ejbills/DockDoor/releases/tag/v1.0.15) - 2024-07-06

### Quick patch for:
- Windows that are on separate monitors not showing up
- Some users were experiencing blurry windows (not sure if this is fully fixed)

[Changes][v1.0.15]


<a id="v1.0.14"></a>
# [v1.0.14](https://github.com/ejbills/DockDoor/releases/tag/v1.0.14) - 2024-07-05

- Initial support for hidden apps (CMD+H). If an app is hidden, its windows will show up as ‘hidden’ and will be displayed similarly to minimized windows. If you click a hidden window from the window preview, the owning application will be marked as unhidden, and that window will be brought to the front.
- More changes to update page [@ShlomoCode](https://github.com/ShlomoCode) 

[Changes][v1.0.14]


<a id="v1.0.13"></a>
# [v1.0.13](https://github.com/ejbills/DockDoor/releases/tag/v1.0.13) - 2024-07-04

# Changelog

## New features:
- Feat: add quit app button to preview window ([#51](https://github.com/ejbills/DockDoor/issues/51)) [@ShlomoCode](https://github.com/ShlomoCode) 
- Feat: change sizingMultiplier setting without restarting the app ([#50](https://github.com/ejbills/DockDoor/issues/50)) [@ShlomoCode](https://github.com/ShlomoCode) 

## Misc.
- Update page overhaul
- Fixes title UI inconsistencies for small window sizing
- Moves window title to bottom
- Update README.md documentation for new traffic light button
- Fixes jagged gradient animation
- Fully finish transition to ScreenCaptureKit in preparation for macOS Sequoia (remove CoreGraphics usage)
- Removes unnecessary ".00" in Window Cache Lifespan
- Enhances window filtering for certain applications ([issue 1](https://github.com/ejbills/DockDoor/issues/55) [issue 2](https://github.com/ejbills/DockDoor/issues/36))

[Changes][v1.0.13]


<a id="v1.0.12"></a>
# [v1.0.12](https://github.com/ejbills/DockDoor/releases/tag/v1.0.12) - 2024-07-02

- Only shows window's title when you hover over the window
- Reduces animations to make it feel more polished
- Customizable screenshot caching timer (you can set it to 0 so window previews are always fresh)
- Adds support for maximizing a window from the window preview (thanks to [@ShlomoCode](https://github.com/ShlomoCode))
- Migrates screenshot manager to new ScreenCaptureKit API to prevent deprecated warning in macOS sequoia


What's upcoming?
- Full size window previews on hover
- Window switcher keybind customization
- Homebrew releases

[Changes][v1.0.12]


<a id="v1.0.11"></a>
# [v1.0.11](https://github.com/ejbills/DockDoor/releases/tag/v1.0.11) - 2024-06-30

- Adds window title to window previews
- Adds ability to minimize window via window previews
- Hides window when dock icon is clicked
- Hides window when dock item is right clicked
- UI tweaks
- Sets minimum width for settings pane to fix jagged resizing (thanks [@ShlomoCode](https://github.com/ShlomoCode))
- Fixes button to open recording preferences (thanks [@ShlomoCode](https://github.com/ShlomoCode))

[Changes][v1.0.11]


<a id="v1.0.10"></a>
# [v1.0.10](https://github.com/ejbills/DockDoor/releases/tag/v1.0.10) - 2024-06-30

- Adds option to disable menu bar icon

Note:
When DockDoor initially opens, the menu icon will be visible for 10 seconds, until it disappears. This way, you can access the settings even with the icon disabled. Just relaunch the app and click it before it disappears if you need to change some settings.

[Changes][v1.0.10]


<a id="v1.0.9"></a>
# [v1.0.9](https://github.com/ejbills/DockDoor/releases/tag/v1.0.9) - 2024-06-30

- Adds option to disable window switcher entirely (so you can use more mature apps, like AltTab, alongside DockDoor) - thanks [@hasansultan92](https://github.com/hasansultan92) 

[Changes][v1.0.9]


<a id="v1.0.7patch2"></a>
# [v1.0.8 patch (v1.0.7patch2)](https://github.com/ejbills/DockDoor/releases/tag/v1.0.7patch2) - 2024-06-27

- Patches the tab menu incorrectly showing desktop widgets

[Changes][v1.0.7patch2]


<a id="v1.0.7"></a>
# [v1.0.7 patch](https://github.com/ejbills/DockDoor/releases/tag/v1.0.7) - 2024-06-26

- Fixes window buffer being on the wrong axis while the dock is on the bottom
- Better memory management code

[Changes][v1.0.7]


<a id="v1.0.6"></a>
# [v1.0.6](https://github.com/ejbills/DockDoor/releases/tag/v1.0.6) - 2024-06-26

- Fixes localized apps not showing their windows
- Adds option "window buffer" which can be used to tweak the hover window location (if it's too far away, for example)
- Adds donation link in settings

[Changes][v1.0.6]


<a id="v1.0.5"></a>
# [v1.0.5](https://github.com/ejbills/DockDoor/releases/tag/v1.0.5) - 2024-06-25

- Quick patch to fix window previews for chromium browsers

[Changes][v1.0.5]


<a id="v1.0.4"></a>
# [v1.0.4](https://github.com/ejbills/DockDoor/releases/tag/v1.0.4) - 2024-06-25

- Introduces minimized window support. Minimized windows will show up in a little box which will show you all of the hidden windows for that given application. It is scrollable (horizontally if the dock is on the left or right, vertically if on bottom.)
- Hopefully remedies the selected window not being brought to front in browsers
- UI Tweaks

[Changes][v1.0.4]


<a id="v1.0.3"></a>
# [v1.0.3](https://github.com/ejbills/DockDoor/releases/tag/v1.0.3) - 2024-06-24

- Adjustments to app text label UI (you can now read it)
- Added option to delay hover window opening, up to 2 seconds
- Added option to disable the hover window sliding animation

[Changes][v1.0.3]


<a id="v1.0.1"></a>
# [v1.0.1](https://github.com/ejbills/DockDoor/releases/tag/v1.0.1) - 2024-06-23

This release is a quick patch to (hopefully) fix DMG notarization.

[Changes][v1.0.1]


<a id="releases"></a>
# [v1.0 (releases)](https://github.com/ejbills/DockDoor/releases/tag/releases) - 2024-06-23

v1.0

[Changes][releases]


[v1.18.3]: https://github.com/ejbills/DockDoor/compare/v1.18.2...v1.18.3
[v1.18.2]: https://github.com/ejbills/DockDoor/compare/v1.18.1...v1.18.2
[v1.18.1]: https://github.com/ejbills/DockDoor/compare/v1.18...v1.18.1
[v1.18]: https://github.com/ejbills/DockDoor/compare/v1.17.3...v1.18
[v1.17.3]: https://github.com/ejbills/DockDoor/compare/v1.17.2...v1.17.3
[v1.17.2]: https://github.com/ejbills/DockDoor/compare/v1.17.1...v1.17.2
[v1.17.1]: https://github.com/ejbills/DockDoor/compare/v1.17...v1.17.1
[v1.17]: https://github.com/ejbills/DockDoor/compare/v1.16...v1.17
[v1.16]: https://github.com/ejbills/DockDoor/compare/v1.15.2...v1.16
[v1.15.2]: https://github.com/ejbills/DockDoor/compare/v1.15.1...v1.15.2
[v1.15.1]: https://github.com/ejbills/DockDoor/compare/v1.15...v1.15.1
[v1.15]: https://github.com/ejbills/DockDoor/compare/v1.14.4...v1.15
[v1.14.4]: https://github.com/ejbills/DockDoor/compare/v1.14.3...v1.14.4
[v1.14.3]: https://github.com/ejbills/DockDoor/compare/v1.14.2...v1.14.3
[v1.14.2]: https://github.com/ejbills/DockDoor/compare/v1.14.1...v1.14.2
[v1.14.1]: https://github.com/ejbills/DockDoor/compare/v1.14...v1.14.1
[v1.14]: https://github.com/ejbills/DockDoor/compare/v1.13.1...v1.14
[v1.13.1]: https://github.com/ejbills/DockDoor/compare/v1.13...v1.13.1
[v1.13]: https://github.com/ejbills/DockDoor/compare/v1.12.1...v1.13
[v1.12.1]: https://github.com/ejbills/DockDoor/compare/v1.12...v1.12.1
[v1.12]: https://github.com/ejbills/DockDoor/compare/v1.11...v1.12
[v1.11]: https://github.com/ejbills/DockDoor/compare/v1.10...v1.11
[v1.10]: https://github.com/ejbills/DockDoor/compare/v1.9.1...v1.10
[v1.9.1]: https://github.com/ejbills/DockDoor/compare/v1.9...v1.9.1
[v1.9]: https://github.com/ejbills/DockDoor/compare/v1.8...v1.9
[v1.8]: https://github.com/ejbills/DockDoor/compare/v1.7.1...v1.8
[v1.7.1]: https://github.com/ejbills/DockDoor/compare/v1.7...v1.7.1
[v1.7]: https://github.com/ejbills/DockDoor/compare/v1.6.2...v1.7
[v1.6.2]: https://github.com/ejbills/DockDoor/compare/v1.6.1...v1.6.2
[v1.6.1]: https://github.com/ejbills/DockDoor/compare/v1.6...v1.6.1
[v1.6]: https://github.com/ejbills/DockDoor/compare/v1.5.1...v1.6
[v1.5.1]: https://github.com/ejbills/DockDoor/compare/v1.5...v1.5.1
[v1.5]: https://github.com/ejbills/DockDoor/compare/v1.4...v1.5
[v1.4]: https://github.com/ejbills/DockDoor/compare/v1.3.3...v1.4
[v1.3.3]: https://github.com/ejbills/DockDoor/compare/v1.3.2...v1.3.3
[v1.3.2]: https://github.com/ejbills/DockDoor/compare/v1.3.1...v1.3.2
[v1.3.1]: https://github.com/ejbills/DockDoor/compare/v1.3...v1.3.1
[v1.3]: https://github.com/ejbills/DockDoor/compare/v1.2.9...v1.3
[v1.2.9]: https://github.com/ejbills/DockDoor/compare/v1.2.8...v1.2.9
[v1.2.8]: https://github.com/ejbills/DockDoor/compare/v1.2.7...v1.2.8
[v1.2.7]: https://github.com/ejbills/DockDoor/compare/v1.2.6...v1.2.7
[v1.2.6]: https://github.com/ejbills/DockDoor/compare/v1.2.5...v1.2.6
[v1.2.5]: https://github.com/ejbills/DockDoor/compare/v1.2.3...v1.2.5
[v1.2.3]: https://github.com/ejbills/DockDoor/compare/v1.2.2...v1.2.3
[v1.2.2]: https://github.com/ejbills/DockDoor/compare/v1.2.1...v1.2.2
[v1.2.1]: https://github.com/ejbills/DockDoor/compare/v1.2.0...v1.2.1
[v1.2.0]: https://github.com/ejbills/DockDoor/compare/v1.1.6...v1.2.0
[v1.1.6]: https://github.com/ejbills/DockDoor/compare/v1.1.5...v1.1.6
[v1.1.5]: https://github.com/ejbills/DockDoor/compare/v1.1.4...v1.1.5
[v1.1.4]: https://github.com/ejbills/DockDoor/compare/v1.1.3...v1.1.4
[v1.1.3]: https://github.com/ejbills/DockDoor/compare/v1.1.2...v1.1.3
[v1.1.2]: https://github.com/ejbills/DockDoor/compare/v1.1.1...v1.1.2
[v1.1.1]: https://github.com/ejbills/DockDoor/compare/v1.1.0...v1.1.1
[v1.1.0]: https://github.com/ejbills/DockDoor/compare/v1.0.17...v1.1.0
[v1.0.17]: https://github.com/ejbills/DockDoor/compare/v1.0.16...v1.0.17
[v1.0.16]: https://github.com/ejbills/DockDoor/compare/v1.0.15...v1.0.16
[v1.0.15]: https://github.com/ejbills/DockDoor/compare/v1.0.14...v1.0.15
[v1.0.14]: https://github.com/ejbills/DockDoor/compare/v1.0.13...v1.0.14
[v1.0.13]: https://github.com/ejbills/DockDoor/compare/v1.0.12...v1.0.13
[v1.0.12]: https://github.com/ejbills/DockDoor/compare/v1.0.11...v1.0.12
[v1.0.11]: https://github.com/ejbills/DockDoor/compare/v1.0.10...v1.0.11
[v1.0.10]: https://github.com/ejbills/DockDoor/compare/v1.0.9...v1.0.10
[v1.0.9]: https://github.com/ejbills/DockDoor/compare/v1.0.7patch2...v1.0.9
[v1.0.7patch2]: https://github.com/ejbills/DockDoor/compare/v1.0.7...v1.0.7patch2
[v1.0.7]: https://github.com/ejbills/DockDoor/compare/v1.0.6...v1.0.7
[v1.0.6]: https://github.com/ejbills/DockDoor/compare/v1.0.5...v1.0.6
[v1.0.5]: https://github.com/ejbills/DockDoor/compare/v1.0.4...v1.0.5
[v1.0.4]: https://github.com/ejbills/DockDoor/compare/v1.0.3...v1.0.4
[v1.0.3]: https://github.com/ejbills/DockDoor/compare/v1.0.1...v1.0.3
[v1.0.1]: https://github.com/ejbills/DockDoor/compare/releases...v1.0.1
[releases]: https://github.com/ejbills/DockDoor/tree/releases

<!-- Generated by https://github.com/rhysd/changelog-from-release v3.9.0 -->
