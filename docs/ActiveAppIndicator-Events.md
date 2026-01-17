# Active App Indicator - Event Subscriptions

This document lists all events/observers used by `ActiveAppIndicatorCoordinator` for the active app indicator feature.

## Summary

| Observer | Event | Status | Frequency | Purpose |
|----------|-------|--------|-----------|---------|
| workspaceObserver | didActivateApplicationNotification | EXISTING | On app switch | Move indicator to active app |
| positionSettingsObserver | Defaults.observe | EXISTING | On settings change | Update indicator appearance |
| screenParametersObserver | didChangeScreenParametersNotification | EXISTING | On display/dock changes | Handle dock resize |
| spaceChangeObserver | activeSpaceDidChangeNotification | NEW | On space/fullscreen change | Hide indicator in fullscreen |
| dockPrefsObserver | com.apple.dock.prefchanged | NEW | On dock prefs change | Handle auto-hide toggle |
| dockLayoutObserver | AXObserver on Dock list | NEW | On dock icon add/remove | Handle dock layout shifts |

---

## Detailed Breakdown

### 1. workspaceObserver (EXISTING)
- **Event:** `NSWorkspace.didActivateApplicationNotification`
- **Source:** NSWorkspace notification center
- **Fires when:** User switches to a different application
- **Frequency:** Only when active app changes (user-initiated)
- **Performance cost:** Very low - only fires on deliberate app switches
- **Action:** Updates indicator position immediately + schedules delayed update

### 2. positionSettingsObserver (EXISTING)
- **Event:** Defaults.observe on indicator settings keys
- **Source:** Defaults library (UserDefaults wrapper)
- **Fires when:** User changes indicator settings (size, offset, color, etc.)
- **Frequency:** Only when user modifies settings in preferences
- **Performance cost:** Negligible - user-initiated, rare
- **Action:** Repositions indicator with new settings

### 3. screenParametersObserver (EXISTING)
- **Event:** `NSApplication.didChangeScreenParametersNotification`
- **Source:** NotificationCenter
- **Fires when:** Display configuration changes (resolution, arrangement, dock position)
- **Frequency:** Rare - only on display/dock configuration changes
- **Performance cost:** Very low
- **Action:** Checks if dock position/size changed, schedules update if needed

### 4. spaceChangeObserver (NEW - for fullscreen fix)
- **Event:** `NSWorkspace.activeSpaceDidChangeNotification`
- **Source:** NSWorkspace notification center
- **Fires when:** User switches Mission Control spaces or enters/exits fullscreen
- **Frequency:** Only on space changes (user-initiated)
- **Performance cost:** Very low - user-initiated action
- **Action:** Checks if in fullscreen, hides indicator if dock is hidden

### 5. dockPrefsObserver (NEW - for fullscreen fix)
- **Event:** `com.apple.dock.prefchanged` (DistributedNotificationCenter)
- **Source:** macOS Dock process
- **Fires when:** Dock preferences change (auto-hide toggled, magnification, etc.)
- **Frequency:** Rare - only when user changes Dock settings
- **Performance cost:** Negligible
- **Action:** Updates dock visibility state, shows/hides indicator accordingly

### 6. dockLayoutObserver (NEW - for dock shift fix)
- **Event:** `kAXUIElementDestroyedNotification` and `kAXCreatedNotification` on Dock's list element
- **Source:** AXObserver on com.apple.dock process
- **Fires when:** Dock icons are added or removed (app opens window, app quits, etc.)
- **Frequency:** When apps with dock icons launch/quit or apps open/close their first/last window
- **Performance cost:** Low - only fires on actual dock content changes
- **Action:** Schedules delayed indicator update to account for dock animation

---

## Performance Notes

### Events NOT used (alternatives considered but rejected):
- **Polling timer:** Would continuously check dock state - rejected for battery/CPU impact
- **kAXLayoutChangedNotification:** Fires too frequently on dock hover animations
- **Window observer on all apps:** Would require observing every app's windows - too broad

### Why these events are efficient:
1. All observers are event-driven (no polling)
2. Each event fires only when a relevant change occurs
3. Most events are user-initiated (app switch, space change, settings change)
4. The dock layout observer only fires when dock content actually changes, not on hover/animation

### Delayed update mechanism:
- When events fire that might cause dock animation (app switch, dock layout change), we:
  1. Update indicator immediately (for instant feedback)
  2. Schedule a second update after 0.6s (to catch dock animation completion)
- The delayed timer is debounced - multiple rapid events only trigger one delayed update

---

## Testing Notes

**Tested on:** January 2026

**Result:** All events verified to fire only when expected - no excessive event calls observed.

Test scenarios performed:
- Normal app switching (clicking dock icons, Cmd+Tab)
- Hovering over dock icons
- Opening/closing app windows (BTT settings edge case)
- Entering/exiting fullscreen
- Idle state (no spurious events)

All 6 observers behave correctly and only fire on relevant state changes.
