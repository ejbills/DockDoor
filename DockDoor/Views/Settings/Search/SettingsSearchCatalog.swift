import Foundation

enum SettingsSearchCatalog {
    static let items: [SettingsSearchItem] = generalItems + dockPreviewItems + windowSwitcherItems
        + cmdTabItems + dockLockingItems + appearanceItems + gesturesItems + filtersItems
        + widgetItems + advancedItems + supportItems

    // MARK: - General

    private static let generalItems: [SettingsSearchItem] = [
        SettingsSearchItem(
            id: "general.launchAtLogin",
            title: String(localized: "Launch DockDoor at login"),
            keywords: ["startup", "boot", "open", "auto"],
            tab: "General",
            section: String(localized: "Application Basics"),
            icon: "power"
        ),
        SettingsSearchItem(
            id: "general.menuBarIcon",
            title: String(localized: "Show menu bar icon"),
            keywords: ["status", "tray", "menu"],
            tab: "General",
            section: String(localized: "Application Basics"),
            icon: "menubar.rectangle"
        ),
        SettingsSearchItem(
            id: "general.activateOnWake",
            title: String(localized: "Restore settings window to front on wake from sleep"),
            keywords: ["wake", "sleep", "restore"],
            tab: "General",
            section: String(localized: "Application Basics"),
            icon: "moon.zzz"
        ),
        SettingsSearchItem(
            id: "general.reduceMotion",
            title: String(localized: "Reduce motion"),
            keywords: ["animation", "animations", "motion", "accessibility"],
            tab: "General",
            section: String(localized: "Application Basics"),
            icon: "figure.roll"
        ),
        SettingsSearchItem(
            id: "general.sortMinimized",
            title: String(localized: "Sort minimized/hidden windows to end"),
            description: String(localized: "Minimized and hidden windows will appear after all visible windows in previews and switcher."),
            keywords: ["sort", "minimized", "hidden", "order"],
            tab: "General",
            section: String(localized: "Application Basics"),
            icon: "arrow.down.to.line"
        ),
        SettingsSearchItem(
            id: "general.activeAppIndicator",
            title: String(localized: "Show active app indicator below dock icon"),
            description: String(localized: "Displays a colored line below the currently active application's dock icon."),
            keywords: ["indicator", "active", "dot", "highlight", "color"],
            tab: "General",
            section: String(localized: "Active App Indicator"),
            icon: "line.horizontal.star.fill.line.horizontal"
        ),
        SettingsSearchItem(
            id: "general.indicatorColor",
            title: String(localized: "Indicator Color"),
            keywords: ["indicator", "color", "picker"],
            tab: "General",
            section: String(localized: "Active App Indicator"),
            icon: "paintbrush"
        ),
        SettingsSearchItem(
            id: "general.indicatorAutoSize",
            title: String(localized: "Automatically set height and offset"),
            keywords: ["indicator", "auto", "height", "offset"],
            tab: "General",
            section: String(localized: "Active App Indicator"),
            icon: "arrow.up.and.down.text.horizontal"
        ),
        SettingsSearchItem(
            id: "general.indicatorHeight",
            title: String(localized: "Indicator Height"),
            keywords: ["indicator", "height", "thickness"],
            tab: "General",
            section: String(localized: "Active App Indicator"),
            icon: "arrow.up.and.down"
        ),
        SettingsSearchItem(
            id: "general.indicatorOffset",
            title: String(localized: "Position Offset"),
            keywords: ["indicator", "offset", "position"],
            tab: "General",
            section: String(localized: "Active App Indicator"),
            icon: "arrow.up.and.down"
        ),
        SettingsSearchItem(
            id: "general.indicatorAutoLength",
            title: String(localized: "Automatically set length"),
            keywords: ["indicator", "auto", "length", "width"],
            tab: "General",
            section: String(localized: "Active App Indicator"),
            icon: "arrow.left.and.right"
        ),
        SettingsSearchItem(
            id: "general.indicatorLength",
            title: String(localized: "Indicator Length"),
            keywords: ["indicator", "length", "width"],
            tab: "General",
            section: String(localized: "Active App Indicator"),
            icon: "arrow.left.and.right"
        ),
        SettingsSearchItem(
            id: "general.indicatorShift",
            title: String(localized: "Shift Indicator"),
            keywords: ["indicator", "shift", "nudge"],
            tab: "General",
            section: String(localized: "Active App Indicator"),
            icon: "arrow.left.arrow.right"
        ),
    ]

    // MARK: - Dock Previews

    private static let dockPreviewItems: [SettingsSearchItem] = [
        SettingsSearchItem(
            id: "dockPreviews.enable",
            title: String(localized: "Enable Dock Previews"),
            description: String(localized: "Show window previews when hovering over Dock icons."),
            keywords: ["dock", "hover", "preview"],
            tab: "DockPreviews",
            section: "",
            icon: "dock.rectangle"
        ),
        SettingsSearchItem(
            id: "dockPreviews.currentSpaceOnly",
            title: String(localized: "Show windows from current Space only"),
            description: String(localized: "Only display windows that are in the current virtual desktop/Space."),
            keywords: ["space", "desktop", "virtual"],
            tab: "DockPreviews",
            section: String(localized: "Window Display"),
            icon: "rectangle.on.rectangle"
        ),
        SettingsSearchItem(
            id: "dockPreviews.currentMonitorOnly",
            title: String(localized: "Show windows from current monitor only"),
            description: String(localized: "Only display windows that are on the same display as the Dock icon you're hovering."),
            keywords: ["monitor", "display", "screen"],
            tab: "DockPreviews",
            section: String(localized: "Window Display"),
            icon: "display"
        ),
        SettingsSearchItem(
            id: "dockPreviews.sortOrder",
            title: String(localized: "Window sort order"),
            keywords: ["sort", "order", "arrange"],
            tab: "DockPreviews",
            section: String(localized: "Window Display"),
            icon: "arrow.up.arrow.down"
        ),
        SettingsSearchItem(
            id: "dockPreviews.includeHidden",
            title: String(localized: "Include hidden/minimized windows"),
            keywords: ["hidden", "minimized", "include"],
            tab: "DockPreviews",
            section: String(localized: "Window Display"),
            icon: "eye.slash"
        ),
        SettingsSearchItem(
            id: "dockPreviews.showWindowless",
            title: String(localized: "Show preview for apps with no open windows"),
            description: String(localized: "Show a placeholder preview when hovering dock apps that have no windows."),
            keywords: ["windowless", "placeholder", "empty"],
            tab: "DockPreviews",
            section: String(localized: "Window Display"),
            icon: "macwindow.badge.plus"
        ),
        SettingsSearchItem(
            id: "dockPreviews.keepOnTerminate",
            title: String(localized: "Keep preview when app terminates"),
            description: String(localized: "Remove only terminated app's windows instead of hiding the entire preview."),
            keywords: ["terminate", "quit", "close", "keep"],
            tab: "DockPreviews",
            section: String(localized: "Window Display"),
            icon: "xmark.app"
        ),
        SettingsSearchItem(
            id: "dockPreviews.groupInstances",
            title: String(localized: "Group multiple app instances together"),
            description: String(localized: "Show windows from all instances of an app when hovering its dock icon."),
            keywords: ["group", "instance", "multiple"],
            tab: "DockPreviews",
            section: String(localized: "Window Display"),
            icon: "square.stack"
        ),
        SettingsSearchItem(
            id: "dockPreviews.ignoreSingleWindow",
            title: String(localized: "Ignore apps with one window"),
            description: String(localized: "Prevents apps that only ever have a single window from appearing in previews."),
            keywords: ["single", "ignore", "one"],
            tab: "DockPreviews",
            section: String(localized: "Window Display"),
            icon: "1.square"
        ),
        SettingsSearchItem(
            id: "dockPreviews.hoverAction",
            title: String(localized: "Dock Preview Hover Action"),
            keywords: ["hover", "action", "click", "tap"],
            tab: "DockPreviews",
            section: String(localized: "Dock Interaction"),
            icon: "cursorarrow.click"
        ),
        SettingsSearchItem(
            id: "dockPreviews.hoverDelay",
            title: String(localized: "Preview Hover Action Delay"),
            keywords: ["delay", "tap", "interval"],
            tab: "DockPreviews",
            section: String(localized: "Dock Interaction"),
            icon: "timer"
        ),
        SettingsSearchItem(
            id: "dockPreviews.hideOnClick",
            title: String(localized: "Hide all app windows on dock icon click"),
            keywords: ["hide", "click", "minimize"],
            tab: "DockPreviews",
            section: String(localized: "Dock Interaction"),
            icon: "cursorarrow.click.2"
        ),
        SettingsSearchItem(
            id: "dockPreviews.cmdRightClickQuit",
            title: String(localized: "CMD + Right Click on dock icon to quit app"),
            keywords: ["quit", "right click", "command", "force"],
            tab: "DockPreviews",
            section: String(localized: "Dock Interaction"),
            icon: "xmark.circle"
        ),
        SettingsSearchItem(
            id: "dockPreviews.quitOnClose",
            title: String(localized: "Quit app when closing its last window"),
            description: String(localized: "When an app has only one window left, closing it from the preview will quit the app. Hold Option to force quit. Useful as a replacement for Swift Quit."),
            keywords: ["quit", "close", "last window"],
            tab: "DockPreviews",
            section: String(localized: "Dock Interaction"),
            icon: "xmark.app.fill"
        ),
        SettingsSearchItem(
            id: "dockPreviews.buffer",
            title: String(localized: "Window Buffer from Dock (pixels)"),
            keywords: ["buffer", "distance", "gap", "offset", "pixels"],
            tab: "DockPreviews",
            section: String(localized: "Dock Interaction"),
            icon: "arrow.up.and.down"
        ),
    ]

    // MARK: - Window Switcher

    private static let windowSwitcherItems: [SettingsSearchItem] = [
        SettingsSearchItem(
            id: "windowSwitcher.enable",
            title: String(localized: "Enable Window Switcher"),
            description: String(localized: "The Window Switcher (often Alt/Cmd-Tab) lets you quickly cycle between open app windows with a keyboard shortcut."),
            keywords: ["switcher", "alt tab", "window"],
            tab: "WindowSwitcher",
            section: "",
            icon: "uiwindow.split.2x1"
        ),
        SettingsSearchItem(
            id: "windowSwitcher.instant",
            title: String(localized: "Show Window Switcher instantly"),
            description: String(localized: "May feel snappier but can cause flickering if you quickly release the key."),
            keywords: ["instant", "fast", "speed", "flicker"],
            tab: "WindowSwitcher",
            section: String(localized: "Behavior"),
            icon: "bolt"
        ),
        SettingsSearchItem(
            id: "windowSwitcher.releaseToSelect",
            title: String(localized: "Release initializer key to select window"),
            keywords: ["release", "select", "key"],
            tab: "WindowSwitcher",
            section: String(localized: "Behavior"),
            icon: "hand.raised"
        ),
        SettingsSearchItem(
            id: "windowSwitcher.startOnSecond",
            title: String(localized: "Start on second window"),
            description: String(localized: "Highlight the second window instead of the first when opening."),
            keywords: ["second", "start", "classic", "ordering"],
            tab: "WindowSwitcher",
            section: String(localized: "Behavior"),
            icon: "2.circle"
        ),
        SettingsSearchItem(
            id: "windowSwitcher.mouseFollowsFocus",
            title: String(localized: "Mouse follows focus", comment: "Mouse follows focus setting label"),
            description: String(localized: "Move the cursor to the center of the selected window."),
            keywords: ["mouse", "cursor", "warp", "teleport", "focus"],
            tab: "WindowSwitcher",
            section: String(localized: "Behavior"),
            icon: "computermouse"
        ),
        SettingsSearchItem(
            id: "windowSwitcher.currentSpaceOnly",
            title: String(localized: "Show windows from current Space only"),
            description: String(localized: "Only display windows that are in the current virtual desktop/Space."),
            keywords: ["space", "desktop", "virtual"],
            tab: "WindowSwitcher",
            section: String(localized: "Window Display"),
            icon: "rectangle.on.rectangle"
        ),
        SettingsSearchItem(
            id: "windowSwitcher.currentMonitorOnly",
            title: String(localized: "Show windows from current monitor only"),
            description: String(localized: "Only display windows that are on the same display as the mouse cursor."),
            keywords: ["monitor", "display", "screen"],
            tab: "WindowSwitcher",
            section: String(localized: "Window Display"),
            icon: "display"
        ),
        SettingsSearchItem(
            id: "windowSwitcher.limitToFrontmost",
            title: String(localized: "Limit to active app only"),
            description: String(localized: "Only show windows from the currently active/frontmost application."),
            keywords: ["frontmost", "active", "limit", "current"],
            tab: "WindowSwitcher",
            section: String(localized: "Window Display"),
            icon: "app.dashed"
        ),
        SettingsSearchItem(
            id: "windowSwitcher.includeHidden",
            title: String(localized: "Include hidden/minimized windows"),
            keywords: ["hidden", "minimized", "include"],
            tab: "WindowSwitcher",
            section: String(localized: "Window Display"),
            icon: "eye.slash"
        ),
        SettingsSearchItem(
            id: "windowSwitcher.showWindowless",
            title: String(localized: "Show running apps with no open windows"),
            description: String(localized: "Dock-visible apps without any windows will appear as icon-only entries at the end."),
            keywords: ["windowless", "running", "empty", "icon"],
            tab: "WindowSwitcher",
            section: String(localized: "Window Display"),
            icon: "macwindow.badge.plus"
        ),
        SettingsSearchItem(
            id: "windowSwitcher.enableSearch",
            title: String(localized: "Enable search"),
            keywords: ["search", "find", "filter", "type"],
            tab: "WindowSwitcher",
            section: String(localized: "Search & Input"),
            icon: "magnifyingglass"
        ),
        SettingsSearchItem(
            id: "windowSwitcher.focusSearch",
            title: String(localized: "Focus search on open"),
            description: String(localized: "Automatically focus the search bar when the window switcher opens."),
            keywords: ["focus", "search", "auto", "bar"],
            tab: "WindowSwitcher",
            section: String(localized: "Search & Input"),
            icon: "text.cursor"
        ),
        SettingsSearchItem(
            id: "windowSwitcher.mouseHover",
            title: String(localized: "Enable mouse hover selection"),
            description: String(localized: "Select and scroll to windows when hovering with mouse."),
            keywords: ["mouse", "hover", "select"],
            tab: "WindowSwitcher",
            section: String(localized: "Search & Input"),
            icon: "cursorarrow"
        ),
        SettingsSearchItem(
            id: "windowSwitcher.sortOrder",
            title: String(localized: "Window sort order"),
            keywords: ["sort", "order", "arrange"],
            tab: "WindowSwitcher",
            section: String(localized: "Sorting & Grouping"),
            icon: "arrow.up.arrow.down"
        ),
        SettingsSearchItem(
            id: "windowSwitcher.groupByApp",
            title: String(localized: "Group windows by app"),
            description: String(localized: "Selected apps show only their most recent window. All windows shown in active-app-only mode."),
            keywords: ["group", "app", "bundle"],
            tab: "WindowSwitcher",
            section: String(localized: "Sorting & Grouping"),
            icon: "square.stack"
        ),
        SettingsSearchItem(
            id: "windowSwitcher.placement",
            title: String(localized: "Screen"),
            keywords: ["placement", "screen", "position", "where"],
            tab: "WindowSwitcher",
            section: String(localized: "Placement"),
            icon: "rectangle.center.inset.filled"
        ),
        SettingsSearchItem(
            id: "windowSwitcher.offsetPosition",
            title: String(localized: "Offset position"),
            keywords: ["offset", "shift", "move", "position"],
            tab: "WindowSwitcher",
            section: String(localized: "Placement"),
            icon: "arrow.up.left.and.arrow.down.right"
        ),
    ]

    // MARK: - Cmd+Tab

    private static let cmdTabItems: [SettingsSearchItem] = [
        SettingsSearchItem(
            id: "cmdTab.enable",
            title: String(localized: "Enable Cmd+Tab Enhancements"),
            description: String(localized: "Show previews while holding Cmd+Tab."),
            keywords: ["cmd tab", "command tab", "enhance"],
            tab: "CmdTab",
            section: "",
            icon: "command"
        ),
        SettingsSearchItem(
            id: "cmdTab.cycleKey",
            title: String(localized: "Preview cycle key:"),
            keywords: ["cycle", "key", "forward", "tab"],
            tab: "CmdTab",
            section: String(localized: "Configuration"),
            icon: "arrow.right"
        ),
        SettingsSearchItem(
            id: "cmdTab.backwardKey",
            title: String(localized: "Backward cycle key:"),
            keywords: ["backward", "reverse", "shift"],
            tab: "CmdTab",
            section: String(localized: "Configuration"),
            icon: "arrow.left"
        ),
        SettingsSearchItem(
            id: "cmdTab.autoSelect",
            title: String(localized: "Automatically select first window"),
            description: String(localized: "When Cmd+Tab opens, highlight the first window preview automatically."),
            keywords: ["auto", "select", "first", "highlight"],
            tab: "CmdTab",
            section: String(localized: "Configuration"),
            icon: "1.circle"
        ),
        SettingsSearchItem(
            id: "cmdTab.currentSpaceOnly",
            title: String(localized: "Show windows from current Space only"),
            description: String(localized: "Only display windows that are in the current virtual desktop/Space."),
            keywords: ["space", "desktop"],
            tab: "CmdTab",
            section: String(localized: "Window Display"),
            icon: "rectangle.on.rectangle"
        ),
        SettingsSearchItem(
            id: "cmdTab.currentMonitorOnly",
            title: String(localized: "Show windows from current monitor only"),
            description: String(localized: "Only display windows that are on the same display as the mouse cursor."),
            keywords: ["monitor", "display", "screen"],
            tab: "CmdTab",
            section: String(localized: "Window Display"),
            icon: "display"
        ),
        SettingsSearchItem(
            id: "cmdTab.includeHidden",
            title: String(localized: "Include hidden/minimized windows"),
            keywords: ["hidden", "minimized"],
            tab: "CmdTab",
            section: String(localized: "Window Display"),
            icon: "eye.slash"
        ),
        SettingsSearchItem(
            id: "cmdTab.showWindowless",
            title: String(localized: "Show preview for apps with no open windows"),
            description: String(localized: "Show a placeholder preview when Cmd+Tab lands on an app that has no windows."),
            keywords: ["windowless", "placeholder"],
            tab: "CmdTab",
            section: String(localized: "Window Display"),
            icon: "macwindow.badge.plus"
        ),
        SettingsSearchItem(
            id: "cmdTab.sortOrder",
            title: String(localized: "Window sort order"),
            keywords: ["sort", "order"],
            tab: "CmdTab",
            section: String(localized: "Window Display"),
            icon: "arrow.up.arrow.down"
        ),
    ]

    // MARK: - Dock Locking

    private static let dockLockingItems: [SettingsSearchItem] = [
        SettingsSearchItem(
            id: "dockLocking.enable",
            title: String(localized: "Lock Dock to Screen"),
            description: String(localized: "Prevent the Dock from jumping to other monitors when your cursor reaches the screen edge."),
            keywords: ["lock", "pin", "monitor", "screen", "multi"],
            tab: "DockLocking",
            section: "",
            icon: "lock.fill"
        ),
        SettingsSearchItem(
            id: "dockLocking.screen",
            title: String(localized: "Lock Dock to"),
            keywords: ["screen", "display", "which"],
            tab: "DockLocking",
            section: String(localized: "Configuration"),
            icon: "display"
        ),
        SettingsSearchItem(
            id: "dockLocking.bypass",
            title: String(localized: "Bypass modifier key"),
            description: String(localized: "Hold this key to temporarily allow the Dock to move freely."),
            keywords: ["bypass", "override", "modifier", "temporarily"],
            tab: "DockLocking",
            section: String(localized: "Configuration"),
            icon: "key"
        ),
    ]

    // MARK: - Appearance

    private static let appearanceItems: [SettingsSearchItem] = [
        // Window Preview Size
        SettingsSearchItem(
            id: "appearance.lockAspect",
            title: String(localized: "Lock aspect ratio (16:10)"),
            keywords: ["aspect", "ratio", "lock", "16:10"],
            tab: "Appearance",
            section: String(localized: "Window Preview Size"),
            icon: "aspectratio"
        ),
        SettingsSearchItem(
            id: "appearance.dynamicSizing",
            title: String(localized: "Dynamic image sizing"),
            description: String(localized: "Scale previews to match actual window proportions instead of using fixed dimensions."),
            keywords: ["dynamic", "scale", "size", "proportional"],
            tab: "Appearance",
            section: String(localized: "Window Preview Size"),
            icon: "arrow.up.left.and.arrow.down.right"
        ),
        SettingsSearchItem(
            id: "appearance.previewWidth",
            title: String(localized: "Preview Width"),
            keywords: ["width", "size", "preview"],
            tab: "Appearance",
            section: String(localized: "Window Preview Size"),
            icon: "arrow.left.and.right"
        ),
        SettingsSearchItem(
            id: "appearance.previewHeight",
            title: String(localized: "Preview Height"),
            keywords: ["height", "size", "preview"],
            tab: "Appearance",
            section: String(localized: "Window Preview Size"),
            icon: "arrow.up.and.down"
        ),
        // Background
        SettingsSearchItem(
            id: "appearance.backgroundStyle",
            title: String(localized: "Style"),
            keywords: ["background", "style", "glass", "blur", "material"],
            tab: "Appearance",
            section: String(localized: "Background"),
            icon: "rectangle.fill"
        ),
        // General Appearance
        SettingsSearchItem(
            id: "appearance.theme",
            title: String(localized: "Appearance"),
            keywords: ["theme", "dark", "light", "system"],
            tab: "Appearance",
            section: String(localized: "General Appearance"),
            icon: "circle.lefthalf.filled"
        ),
        SettingsSearchItem(
            id: "appearance.roundedCorners",
            title: String(localized: "Rounded corners"),
            description: String(localized: "Round the corners of window preview images for a modern look."),
            keywords: ["rounded", "corners", "radius"],
            tab: "Appearance",
            section: String(localized: "General Appearance"),
            icon: "rectangle.roundedtop"
        ),
        SettingsSearchItem(
            id: "appearance.marquee",
            title: String(localized: "Long title overflow"),
            description: String(localized: "How to display window titles that are too long to fit."),
            keywords: ["marquee", "scroll", "title", "truncate", "overflow"],
            tab: "Appearance",
            section: String(localized: "General Appearance"),
            icon: "text.badge.star"
        ),
        SettingsSearchItem(
            id: "appearance.distinguishMinimized",
            title: String(localized: "Distinguish minimized/hidden windows"),
            description: String(localized: "When enabled, shows visual indicators and dims minimized/hidden windows. When disabled, treats them as normal windows with full functionality."),
            keywords: ["minimized", "hidden", "dim", "visual"],
            tab: "Appearance",
            section: String(localized: "General Appearance"),
            icon: "eye.trianglebadge.exclamationmark"
        ),
        SettingsSearchItem(
            id: "appearance.hidePreviewBackground",
            title: String(localized: "Hide preview card background"),
            description: String(localized: "Removes the background panel from individual window previews."),
            keywords: ["background", "card", "hide", "transparent"],
            tab: "Appearance",
            section: String(localized: "General Appearance"),
            icon: "rectangle.dashed"
        ),
        SettingsSearchItem(
            id: "appearance.hideContainerBackground",
            title: String(localized: "Hide hover container background"),
            description: String(localized: "Removes the container background from window preview panels."),
            keywords: ["container", "background", "hide", "transparent"],
            tab: "Appearance",
            section: String(localized: "General Appearance"),
            icon: "rectangle.dashed.and.arrow.up"
        ),
        SettingsSearchItem(
            id: "appearance.hideWidgetBackground",
            title: String(localized: "Hide widget container background"),
            description: String(localized: "Removes the container background from widget panels (media controls, calendar)."),
            keywords: ["widget", "background", "hide"],
            tab: "Appearance",
            section: String(localized: "General Appearance"),
            icon: "widget.small.badge.minus"
        ),
        SettingsSearchItem(
            id: "appearance.activeBorder",
            title: String(localized: "Show active window border"),
            description: String(localized: "Highlights the currently focused window with a colored border."),
            keywords: ["border", "active", "highlight", "focused"],
            tab: "Appearance",
            section: String(localized: "General Appearance"),
            icon: "rectangle.inset.filled.and.person.filled"
        ),
        // Compact Mode
        SettingsSearchItem(
            id: "appearance.compactMode",
            title: String(localized: "Always use compact mode"),
            keywords: ["compact", "list", "titles", "minimal"],
            tab: "Appearance",
            section: String(localized: "Compact Mode (Titles Only)"),
            icon: "list.bullet"
        ),
        SettingsSearchItem(
            id: "appearance.hideTrafficLights",
            title: String(localized: "Hide Traffic Lights"),
            description: String(localized: "Hides the close, minimize, and other window control buttons in compact mode to provide more room for window titles."),
            keywords: ["traffic", "lights", "close", "minimize", "buttons"],
            tab: "Appearance",
            section: String(localized: "Compact Mode (Titles Only)"),
            icon: "minus.circle"
        ),
        // Advanced Appearance
        SettingsSearchItem(
            id: "appearance.opaqueBackground",
            title: String(localized: "Use opaque background"),
            description: String(localized: "Replaces the blurred/transparent background with a solid color. Useful for accessibility or readability."),
            keywords: ["opaque", "solid", "transparent", "blur"],
            tab: "Appearance",
            section: String(localized: "Dock Preview Transparency"),
            icon: "square.fill"
        ),
        SettingsSearchItem(
            id: "appearance.dockPreviewOpacity",
            title: String(localized: "Background Opacity"),
            description: String(localized: "Control the transparency of the dock preview background."),
            keywords: ["opacity", "transparency", "background", "dock"],
            tab: "Appearance",
            section: String(localized: "Dock Preview Transparency"),
            icon: "circle.lefthalf.filled"
        ),
        // General Appearance - sliders
        SettingsSearchItem(
            id: "appearance.spacingScale",
            title: String(localized: "Spacing Scale"),
            keywords: ["spacing", "padding", "scale", "gap"],
            tab: "Appearance",
            section: String(localized: "General Appearance"),
            icon: "arrow.left.and.right"
        ),
        SettingsSearchItem(
            id: "appearance.unselectedOpacity",
            title: String(localized: "Unselected Content Opacity"),
            keywords: ["opacity", "unselected", "dim", "fade"],
            tab: "Appearance",
            section: String(localized: "General Appearance"),
            icon: "circle.lefthalf.filled"
        ),
        // Compact Mode - additional
        SettingsSearchItem(
            id: "appearance.compactThresholdSwitcher",
            title: String(localized: "Window Switcher"),
            description: String(localized: "Switch to compact list in window switcher when window count reaches threshold."),
            keywords: ["compact", "threshold", "switcher", "auto"],
            tab: "Appearance",
            section: String(localized: "Compact Mode (Titles Only)"),
            icon: "list.bullet"
        ),
        SettingsSearchItem(
            id: "appearance.compactThresholdDock",
            title: String(localized: "Dock Previews"),
            description: String(localized: "Switch to compact list in dock previews when window count reaches threshold."),
            keywords: ["compact", "threshold", "dock", "auto"],
            tab: "Appearance",
            section: String(localized: "Compact Mode (Titles Only)"),
            icon: "list.bullet"
        ),
        SettingsSearchItem(
            id: "appearance.compactThresholdCmdTab",
            title: String(localized: "Cmd+Tab Enhancement"),
            description: String(localized: "Switch to compact list in Cmd+Tab overlay when window count reaches threshold."),
            keywords: ["compact", "threshold", "cmd tab", "auto"],
            tab: "Appearance",
            section: String(localized: "Compact Mode (Titles Only)"),
            icon: "list.bullet"
        ),
        SettingsSearchItem(
            id: "appearance.compactItemSize",
            title: String(localized: "Item Size"),
            keywords: ["compact", "item", "size", "row"],
            tab: "Appearance",
            section: String(localized: "Compact Mode (Titles Only)"),
            icon: "textformat.size"
        ),
        SettingsSearchItem(
            id: "appearance.compactTitleFormat",
            title: String(localized: "Title Format"),
            keywords: ["compact", "title", "format", "display"],
            tab: "Appearance",
            section: String(localized: "Compact Mode (Titles Only)"),
            icon: "textformat"
        ),
        // Background - additional
        SettingsSearchItem(
            id: "appearance.material",
            title: String(localized: "Material"),
            keywords: ["material", "frosted", "background"],
            tab: "Appearance",
            section: String(localized: "Background"),
            icon: "rectangle.fill"
        ),
        SettingsSearchItem(
            id: "appearance.glassTuning",
            title: String(localized: "Glass Tuning"),
            description: String(localized: "Fine-tune opacity, blur, saturation, tint, and border for glass background style."),
            keywords: ["glass", "opacity", "blur", "saturation", "tint", "border", "tuning"],
            tab: "Appearance",
            section: String(localized: "Background"),
            icon: "slider.horizontal.3"
        ),
        // Window Background
        SettingsSearchItem(
            id: "appearance.hoverHighlightColor",
            title: String(localized: "Custom Hover Highlight Color"),
            keywords: ["hover", "highlight", "color", "accent", "selection"],
            tab: "Appearance",
            section: String(localized: "Window Background"),
            icon: "paintbrush"
        ),
        SettingsSearchItem(
            id: "appearance.selectionOpacity",
            title: String(localized: "Background Opacity"),
            description: String(localized: "Controls the opacity of the selection highlight background."),
            keywords: ["selection", "opacity", "highlight"],
            tab: "Appearance",
            section: String(localized: "Window Background"),
            icon: "circle.lefthalf.filled"
        ),
        SettingsSearchItem(
            id: "appearance.customBackgroundColor",
            title: String(localized: "Custom Background Color"),
            description: String(localized: "Override the default blurred background with a solid custom color."),
            keywords: ["background", "color", "custom", "solid"],
            tab: "Appearance",
            section: String(localized: "Dock Preview Transparency"),
            icon: "paintbrush.fill"
        ),
        // Color Customization
        SettingsSearchItem(
            id: "appearance.gradientColors",
            title: String(localized: "Highlight Gradient Colors"),
            keywords: ["gradient", "color", "palette", "rainbow"],
            tab: "Appearance",
            section: String(localized: "Color Customization"),
            icon: "paintpalette"
        ),
        SettingsSearchItem(
            id: "appearance.gradientSpeed",
            title: String(localized: "Animation speed"),
            keywords: ["gradient", "animation", "speed"],
            tab: "Appearance",
            section: String(localized: "Color Customization"),
            icon: "hare"
        ),
        SettingsSearchItem(
            id: "appearance.gradientBlur",
            title: String(localized: "Blur amount"),
            keywords: ["gradient", "blur", "amount"],
            tab: "Appearance",
            section: String(localized: "Color Customization"),
            icon: "aqi.medium"
        ),
        // Dock Preview Appearance
        SettingsSearchItem(
            id: "appearance.dockShowAppHeader",
            title: String(localized: "Show App Header"),
            keywords: ["app", "header", "name", "dock"],
            tab: "Appearance",
            section: String(localized: "Dock Preview Appearance"),
            icon: "textformat"
        ),
        SettingsSearchItem(
            id: "appearance.dockAppHeaderStyle",
            title: String(localized: "App Header Style"),
            keywords: ["header", "style", "dock"],
            tab: "Appearance",
            section: String(localized: "Dock Preview Appearance"),
            icon: "textformat"
        ),
        SettingsSearchItem(
            id: "appearance.dockShowAppIconOnly",
            title: String(localized: "Show App Icon Only"),
            keywords: ["icon", "only", "header", "dock"],
            tab: "Appearance",
            section: String(localized: "Dock Preview Appearance"),
            icon: "app.badge"
        ),
        SettingsSearchItem(
            id: "appearance.dockControlPosition",
            title: String(localized: "Position Dock Preview Controls"),
            keywords: ["position", "controls", "toolbar", "dock"],
            tab: "Appearance",
            section: String(localized: "Dock Preview Appearance"),
            icon: "rectangle.topthird.inset.filled"
        ),
        SettingsSearchItem(
            id: "appearance.dockShowWindowTitle",
            title: String(localized: "Show Window Title"),
            description: String(localized: "Show window title in dock previews."),
            keywords: ["title", "window", "dock", "show"],
            tab: "Appearance",
            section: String(localized: "Dock Preview Appearance"),
            icon: "textformat.abc"
        ),
        SettingsSearchItem(
            id: "appearance.dockWindowTitleVisibility",
            title: String(localized: "Window Title Visibility"),
            keywords: ["title", "visibility", "hover", "always", "dock"],
            tab: "Appearance",
            section: String(localized: "Dock Preview Appearance"),
            icon: "eye"
        ),
        SettingsSearchItem(
            id: "appearance.dockDisableTitleStyling",
            title: String(localized: "Disable dock styling on window titles"),
            description: String(localized: "Removes the pill-shaped background styling from window titles in dock previews for a cleaner look."),
            keywords: ["styling", "pill", "title", "dock"],
            tab: "Appearance",
            section: String(localized: "Dock Preview Appearance"),
            icon: "textformat.abc.dottedunderline"
        ),
        SettingsSearchItem(
            id: "appearance.dockWindowTitleFontSize",
            title: String(localized: "Window Title Font Size"),
            keywords: ["font", "size", "title", "dock"],
            tab: "Appearance",
            section: String(localized: "Dock Preview Appearance"),
            icon: "textformat.size"
        ),
        SettingsSearchItem(
            id: "appearance.dockDisableTrafficLightStyling",
            title: String(localized: "Disable dock styling on traffic light buttons"),
            description: String(localized: "Removes the pill-shaped background styling from traffic light buttons in dock previews for a cleaner look."),
            keywords: ["traffic light", "styling", "pill", "dock"],
            tab: "Appearance",
            section: String(localized: "Dock Preview Appearance"),
            icon: "minus.circle"
        ),
        SettingsSearchItem(
            id: "appearance.dockMassActionButtons",
            title: String(localized: "Show Close All and Minimize All buttons"),
            description: String(localized: "Displays Close All and Minimize All buttons when hovering the app icon in dock previews."),
            keywords: ["close all", "minimize all", "mass", "buttons"],
            tab: "Appearance",
            section: String(localized: "Dock Preview Appearance"),
            icon: "xmark.circle"
        ),
        SettingsSearchItem(
            id: "appearance.dockEmbedControls",
            title: String(localized: "Embed controls in preview frames"),
            description: String(localized: "Places traffic light buttons and window titles directly inside the dock preview frames for a more compact and minimal appearance."),
            keywords: ["embed", "controls", "frame", "dock"],
            tab: "Appearance",
            section: String(localized: "Dock Preview Appearance"),
            icon: "rectangle.inset.filled"
        ),
        SettingsSearchItem(
            id: "appearance.dockMaxRows",
            title: String(localized: "Max Rows (Bottom Dock)"),
            description: String(localized: "Controls how many rows of windows are shown in dock previews."),
            keywords: ["rows", "layout", "dock", "grid"],
            tab: "Appearance",
            section: String(localized: "Dock Preview Appearance"),
            icon: "rectangle.grid.1x2"
        ),
        SettingsSearchItem(
            id: "appearance.dockMaxColumns",
            title: String(localized: "Max Columns (Left/Right Dock)"),
            description: String(localized: "Controls how many columns of windows are shown in dock previews."),
            keywords: ["columns", "layout", "dock", "grid"],
            tab: "Appearance",
            section: String(localized: "Dock Preview Appearance"),
            icon: "rectangle.grid.2x1"
        ),
        // Window Switcher Appearance
        SettingsSearchItem(
            id: "appearance.switcherControlPosition",
            title: String(localized: "Position Window Controls"),
            description: String(localized: "Position of window controls in the switcher."),
            keywords: ["position", "controls", "toolbar", "switcher"],
            tab: "Appearance",
            section: String(localized: "Window Switcher Appearance"),
            icon: "rectangle.topthird.inset.filled"
        ),
        SettingsSearchItem(
            id: "appearance.switcherTrafficLightVisibility",
            title: String(localized: "Visibility"),
            description: String(localized: "Controls when traffic light buttons appear in the window switcher."),
            keywords: ["traffic light", "visibility", "switcher", "buttons"],
            tab: "Appearance",
            section: String(localized: "Window Switcher Appearance"),
            icon: "eye"
        ),
        SettingsSearchItem(
            id: "appearance.switcherMonochrome",
            title: String(localized: "Use Monochrome Colors"),
            keywords: ["monochrome", "gray", "traffic light", "switcher"],
            tab: "Appearance",
            section: String(localized: "Window Switcher Appearance"),
            icon: "circle.fill"
        ),
        SettingsSearchItem(
            id: "appearance.switcherDisableTrafficLightStyling",
            title: String(localized: "Disable dock styling on traffic light buttons"),
            description: String(localized: "Removes the pill-shaped background styling from traffic light buttons."),
            keywords: ["traffic light", "styling", "pill", "switcher"],
            tab: "Appearance",
            section: String(localized: "Window Switcher Appearance"),
            icon: "minus.circle"
        ),
        SettingsSearchItem(
            id: "appearance.switcherShowWindowTitle",
            title: String(localized: "Show Window Title"),
            description: String(localized: "Show window title in the window switcher."),
            keywords: ["title", "window", "switcher", "show"],
            tab: "Appearance",
            section: String(localized: "Window Switcher Appearance"),
            icon: "textformat.abc"
        ),
        SettingsSearchItem(
            id: "appearance.switcherWindowTitleVisibility",
            title: String(localized: "Visibility"),
            description: String(localized: "Controls when window titles appear in the switcher."),
            keywords: ["title", "visibility", "hover", "always", "switcher"],
            tab: "Appearance",
            section: String(localized: "Window Switcher Appearance"),
            icon: "eye"
        ),
        SettingsSearchItem(
            id: "appearance.switcherScrollDirection",
            title: String(localized: "Scroll Direction"),
            keywords: ["scroll", "direction", "horizontal", "vertical", "switcher"],
            tab: "Appearance",
            section: String(localized: "Window Switcher Appearance"),
            icon: "arrow.left.and.right"
        ),
        SettingsSearchItem(
            id: "appearance.switcherMaxRows",
            title: String(localized: "Max Rows"),
            description: String(localized: "Controls how many rows of windows are shown in the window switcher."),
            keywords: ["rows", "columns", "layout", "grid", "switcher"],
            tab: "Appearance",
            section: String(localized: "Window Switcher Appearance"),
            icon: "rectangle.grid.1x2"
        ),
        SettingsSearchItem(
            id: "appearance.switcherIgnoreScreenLimit",
            title: String(localized: "Ignore screen size limit"),
            description: String(localized: "Allow columns/rows to exceed what fits on screen."),
            keywords: ["screen", "limit", "overflow", "exceed"],
            tab: "Appearance",
            section: String(localized: "Window Switcher Appearance"),
            icon: "arrow.up.left.and.arrow.down.right"
        ),
        // Cmd+Tab Appearance
        SettingsSearchItem(
            id: "appearance.cmdTabShowAppHeader",
            title: String(localized: "Show App Header"),
            description: String(localized: "Show app header in Cmd+Tab overlay."),
            keywords: ["app", "header", "name", "cmd tab"],
            tab: "Appearance",
            section: String(localized: "Cmd+Tab Appearance"),
            icon: "textformat"
        ),
        SettingsSearchItem(
            id: "appearance.cmdTabAppHeaderStyle",
            title: String(localized: "App Header Style"),
            keywords: ["header", "style", "cmd tab"],
            tab: "Appearance",
            section: String(localized: "Cmd+Tab Appearance"),
            icon: "textformat"
        ),
        SettingsSearchItem(
            id: "appearance.cmdTabShowAppIconOnly",
            title: String(localized: "Show App Icon Only"),
            keywords: ["icon", "only", "header", "cmd tab"],
            tab: "Appearance",
            section: String(localized: "Cmd+Tab Appearance"),
            icon: "app.badge"
        ),
        SettingsSearchItem(
            id: "appearance.cmdTabControlPosition",
            title: String(localized: "Position Window Controls"),
            description: String(localized: "Position of window controls in Cmd+Tab overlay."),
            keywords: ["position", "controls", "toolbar", "cmd tab"],
            tab: "Appearance",
            section: String(localized: "Cmd+Tab Appearance"),
            icon: "rectangle.topthird.inset.filled"
        ),
        SettingsSearchItem(
            id: "appearance.cmdTabShowWindowTitle",
            title: String(localized: "Show Window Title"),
            description: String(localized: "Show window title in Cmd+Tab overlay."),
            keywords: ["title", "window", "cmd tab", "show"],
            tab: "Appearance",
            section: String(localized: "Cmd+Tab Appearance"),
            icon: "textformat.abc"
        ),
        SettingsSearchItem(
            id: "appearance.cmdTabWindowTitleVisibility",
            title: String(localized: "Window Title Visibility"),
            keywords: ["title", "visibility", "hover", "always", "cmd tab"],
            tab: "Appearance",
            section: String(localized: "Cmd+Tab Appearance"),
            icon: "eye"
        ),
        SettingsSearchItem(
            id: "appearance.cmdTabDisableTitleStyling",
            title: String(localized: "Disable dock styling on window titles"),
            description: String(localized: "Removes the pill-shaped background styling from window titles."),
            keywords: ["styling", "pill", "title", "cmd tab"],
            tab: "Appearance",
            section: String(localized: "Cmd+Tab Appearance"),
            icon: "textformat.abc.dottedunderline"
        ),
        SettingsSearchItem(
            id: "appearance.cmdTabTrafficLightVisibility",
            title: String(localized: "Visibility"),
            description: String(localized: "Controls when traffic light buttons appear in Cmd+Tab overlay."),
            keywords: ["traffic light", "visibility", "cmd tab", "buttons"],
            tab: "Appearance",
            section: String(localized: "Cmd+Tab Appearance"),
            icon: "eye"
        ),
        SettingsSearchItem(
            id: "appearance.cmdTabMonochrome",
            title: String(localized: "Use Monochrome Colors"),
            keywords: ["monochrome", "gray", "traffic light", "cmd tab"],
            tab: "Appearance",
            section: String(localized: "Cmd+Tab Appearance"),
            icon: "circle.fill"
        ),
        SettingsSearchItem(
            id: "appearance.cmdTabDisableTrafficLightStyling",
            title: String(localized: "Disable dock styling on traffic light buttons"),
            description: String(localized: "Removes the pill-shaped background styling from traffic light buttons."),
            keywords: ["traffic light", "styling", "pill", "cmd tab"],
            tab: "Appearance",
            section: String(localized: "Cmd+Tab Appearance"),
            icon: "minus.circle"
        ),
        SettingsSearchItem(
            id: "appearance.cmdTabEmbedControls",
            title: String(localized: "Embed controls in preview frames"),
            description: String(localized: "Places traffic light buttons and window titles directly inside the preview frames."),
            keywords: ["embed", "controls", "frame", "cmd tab"],
            tab: "Appearance",
            section: String(localized: "Cmd+Tab Appearance"),
            icon: "rectangle.inset.filled"
        ),
    ]

    // MARK: - Gestures & Keybinds

    private static let gesturesItems: [SettingsSearchItem] = [
        SettingsSearchItem(
            id: "gestures.dockScroll",
            title: String(localized: "Enable scroll gestures on dock icons"),
            description: String(localized: "Scroll up on a dock icon to bring the app to front, scroll down to hide all its windows."),
            keywords: ["scroll", "dock", "gesture", "hide", "front"],
            tab: "GesturesKeybinds",
            section: String(localized: "Dock Icon Scroll Gesture"),
            icon: "arrow.up.and.down.circle"
        ),
        SettingsSearchItem(
            id: "gestures.titleBarScroll",
            title: String(localized: "Enable scroll gestures on active window title bars"),
            description: String(localized: "Scroll up on a focused window title bar to maximize it, scroll down to center it using the configured window size, and scroll left or right to switch desktop spaces. Repeat the same up/down scroll within the configured restore time to restore the previous window size."),
            keywords: ["title bar", "scroll", "maximize", "center", "spaces"],
            tab: "GesturesKeybinds",
            section: String(localized: "Title Bar Scroll Gesture"),
            icon: "arrow.up.and.down.text.horizontal"
        ),
        SettingsSearchItem(
            id: "gestures.dockPreview",
            title: String(localized: "Enable gestures on dock window previews"),
            description: String(localized: "Swipe on window previews in the dock popup. Direction is relative to dock position — swipe towards the dock (e.g., down when dock is at bottom, left when dock is on left)."),
            keywords: ["swipe", "gesture", "preview", "dock"],
            tab: "GesturesKeybinds",
            section: String(localized: "Dock Preview Gestures"),
            icon: "hand.draw"
        ),
        SettingsSearchItem(
            id: "gestures.sensitivity",
            title: String(localized: "Gesture Sensitivity"),
            description: String(localized: "Lower values make gestures more sensitive. Higher values require longer swipes. Applies to both dock previews and window switcher."),
            keywords: ["sensitivity", "threshold", "swipe"],
            tab: "GesturesKeybinds",
            section: String(localized: "Gesture Settings"),
            icon: "slider.horizontal.3"
        ),
        SettingsSearchItem(
            id: "gestures.middleClick",
            title: String(localized: "Middle Click"),
            description: String(localized: "Action performed when middle-clicking on a window preview."),
            keywords: ["middle", "click", "mouse", "button"],
            tab: "GesturesKeybinds",
            section: String(localized: "Mouse Actions"),
            icon: "computermouse"
        ),
        SettingsSearchItem(
            id: "gestures.cmdShortcuts",
            title: String(localized: "Window Preview Keyboard Shortcuts"),
            description: String(localized: "Cmd+key shortcuts for quick actions on the selected window preview. These work in both the window switcher and Cmd+Tab enhancement mode."),
            keywords: ["shortcut", "cmd", "keyboard", "hotkey"],
            tab: "GesturesKeybinds",
            section: String(localized: "Window Preview Keyboard Shortcuts"),
            icon: "command"
        ),
        SettingsSearchItem(
            id: "gestures.switcherKeybind",
            title: String(localized: "Window Switcher Shortcuts"),
            keywords: ["keybind", "shortcut", "alt tab", "switcher", "initializer"],
            tab: "GesturesKeybinds",
            section: String(localized: "Window Switcher Shortcuts"),
            icon: "keyboard"
        ),
        SettingsSearchItem(
            id: "gestures.vimMotions",
            title: String(localized: "Enable Vim Motions"),
            description: String(localized: "Use H/J/K/L keys to navigate left/down/up/right in the window switcher. Disabled while search is focused."),
            keywords: ["vim", "hjkl", "navigation"],
            tab: "GesturesKeybinds",
            section: String(localized: "Window Switcher Shortcuts"),
            icon: "character.textbox"
        ),
        SettingsSearchItem(
            id: "gestures.arrowPassthrough",
            title: String(localized: "Pass Arrow Keys Through to System"),
            description: String(localized: "When enabled, Ctrl+Arrow keys will be passed through to the system instead of navigating the switcher. Useful for Spaces switching."),
            keywords: ["arrow", "passthrough", "spaces", "ctrl"],
            tab: "GesturesKeybinds",
            section: String(localized: "Window Switcher Shortcuts"),
            icon: "arrow.left.arrow.right"
        ),
        SettingsSearchItem(
            id: "gestures.switcherGestures",
            title: String(localized: "Enable gestures in window switcher"),
            description: String(localized: "Swipe up or down on window previews in the keyboard-activated window switcher. Only vertical swipes are recognized, unless in compact mode."),
            keywords: ["swipe", "gesture", "switcher"],
            tab: "GesturesKeybinds",
            section: String(localized: "Window Switcher Gestures"),
            icon: "hand.draw"
        ),
        // Dock Scroll - additional
        SettingsSearchItem(
            id: "gestures.musicScroll",
            title: String(localized: "Music & Spotify dock icon scroll"),
            description: String(localized: "Only applies when scrolling directly on Apple Music or Spotify dock icons."),
            keywords: ["music", "spotify", "scroll", "volume", "track"],
            tab: "GesturesKeybinds",
            section: String(localized: "Dock Icon Scroll Gesture"),
            icon: "music.note"
        ),
        // Title Bar Scroll - additional
        SettingsSearchItem(
            id: "gestures.centeredSizingMode",
            title: String(localized: "Centered Window Sizing"),
            keywords: ["centered", "sizing", "uniform", "separate"],
            tab: "GesturesKeybinds",
            section: String(localized: "Title Bar Scroll Gesture"),
            icon: "rectangle.center.inset.filled"
        ),
        SettingsSearchItem(
            id: "gestures.centeredWindowSize",
            title: String(localized: "Centered Window Size"),
            keywords: ["centered", "size", "scale", "percent"],
            tab: "GesturesKeybinds",
            section: String(localized: "Title Bar Scroll Gesture"),
            icon: "arrow.up.left.and.arrow.down.right"
        ),
        SettingsSearchItem(
            id: "gestures.centeredLockAspect",
            title: String(localized: "Lock aspect ratio (uniform scaling)"),
            keywords: ["aspect", "ratio", "lock", "centered"],
            tab: "GesturesKeybinds",
            section: String(localized: "Title Bar Scroll Gesture"),
            icon: "aspectratio"
        ),
        SettingsSearchItem(
            id: "gestures.centeredWidth",
            title: String(localized: "Centered Window Width"),
            keywords: ["centered", "width", "size"],
            tab: "GesturesKeybinds",
            section: String(localized: "Title Bar Scroll Gesture"),
            icon: "arrow.left.and.right"
        ),
        SettingsSearchItem(
            id: "gestures.centeredHeight",
            title: String(localized: "Centered Window Height"),
            keywords: ["centered", "height", "size"],
            tab: "GesturesKeybinds",
            section: String(localized: "Title Bar Scroll Gesture"),
            icon: "arrow.up.and.down"
        ),
        SettingsSearchItem(
            id: "gestures.restoreTime",
            title: String(localized: "Restore Window Time"),
            description: String(localized: "Repeat the same up/down scroll within this time to restore the previous window size."),
            keywords: ["restore", "time", "interval", "undo"],
            tab: "GesturesKeybinds",
            section: String(localized: "Title Bar Scroll Gesture"),
            icon: "clock.arrow.circlepath"
        ),
        // Dock Preview Gestures - additional
        SettingsSearchItem(
            id: "gestures.swipeTowardsDock",
            title: String(localized: "Towards Dock"),
            description: String(localized: "Swipe toward the dock edge"),
            keywords: ["swipe", "towards", "dock", "action"],
            tab: "GesturesKeybinds",
            section: String(localized: "Dock Preview Gestures"),
            icon: "arrow.down.to.line"
        ),
        SettingsSearchItem(
            id: "gestures.swipeAwayFromDock",
            title: String(localized: "Away from Dock"),
            description: String(localized: "Swipe away from the dock edge"),
            keywords: ["swipe", "away", "dock", "action"],
            tab: "GesturesKeybinds",
            section: String(localized: "Dock Preview Gestures"),
            icon: "arrow.up.to.line"
        ),
        SettingsSearchItem(
            id: "gestures.aeroShake",
            title: String(localized: "Aero Shake"),
            description: String(localized: "Shake a window preview rapidly"),
            keywords: ["aero", "shake", "rapid", "action"],
            tab: "GesturesKeybinds",
            section: String(localized: "Dock Preview Gestures"),
            icon: "hand.point.up.left.and.text"
        ),
        // Window Switcher Shortcuts - additional
        SettingsSearchItem(
            id: "gestures.backwardKey",
            title: String(localized: "Backward Key"),
            description: String(localized: "The key used to navigate backward in the window switcher."),
            keywords: ["backward", "key", "navigate", "back"],
            tab: "GesturesKeybinds",
            section: String(localized: "Window Switcher Shortcuts"),
            icon: "arrow.left"
        ),
        SettingsSearchItem(
            id: "gestures.requireShiftTab",
            title: String(localized: "Require \u{21E7}+Tab to go back in Switcher"),
            keywords: ["shift", "tab", "back", "require"],
            tab: "GesturesKeybinds",
            section: String(localized: "Window Switcher Shortcuts"),
            icon: "arrow.uturn.backward"
        ),
        SettingsSearchItem(
            id: "gestures.selectionKey",
            title: String(localized: "Selection Key"),
            description: String(localized: "The key used to select and bring to front the highlighted window in the switcher."),
            keywords: ["selection", "key", "enter", "return", "select"],
            tab: "GesturesKeybinds",
            section: String(localized: "Window Switcher Shortcuts"),
            icon: "return"
        ),
        SettingsSearchItem(
            id: "gestures.alternateShortcut",
            title: String(localized: "Alternate Shortcut"),
            description: String(localized: "An additional trigger key using the same modifier, invoking the switcher with a different filter mode."),
            keywords: ["alternate", "shortcut", "trigger", "mode"],
            tab: "GesturesKeybinds",
            section: String(localized: "Window Switcher Shortcuts"),
            icon: "keyboard"
        ),
        SettingsSearchItem(
            id: "gestures.searchTriggerKey",
            title: String(localized: "Search Trigger Key"),
            description: String(localized: "The key that activates search while the window switcher is open."),
            keywords: ["search", "trigger", "key", "activate"],
            tab: "GesturesKeybinds",
            section: String(localized: "Window Switcher Shortcuts"),
            icon: "magnifyingglass"
        ),
        SettingsSearchItem(
            id: "gestures.fullscreenBlacklist",
            title: String(localized: "Fullscreen App Blacklist"),
            description: String(localized: "Apps in this list will not respond to window switcher shortcuts when in fullscreen mode."),
            keywords: ["fullscreen", "blacklist", "exclude", "app"],
            tab: "GesturesKeybinds",
            section: String(localized: "Window Switcher Shortcuts"),
            icon: "app.badge.checkmark"
        ),
    ]

    // MARK: - Filters

    private static let filtersItems: [SettingsSearchItem] = [
        SettingsSearchItem(
            id: "filters.appDirectories",
            title: String(localized: "Custom Application Directories"),
            description: String(localized: "Add additional directories to scan for applications. This is useful if you keep apps outside standard locations."),
            keywords: ["directory", "folder", "path", "scan"],
            tab: "Filters",
            section: String(localized: "Custom Application Directories"),
            icon: "folder"
        ),
        SettingsSearchItem(
            id: "filters.appFilters",
            title: String(localized: "Application Filters"),
            description: String(localized: "Hide specific applications from DockDoor previews."),
            keywords: ["blacklist", "hide", "exclude", "app", "block"],
            tab: "Filters",
            section: String(localized: "Application Filters"),
            icon: "app.badge.checkmark"
        ),
        SettingsSearchItem(
            id: "filters.windowTitle",
            title: String(localized: "Window Title Filters"),
            description: String(localized: "Exclude windows from capture by filtering specific text in their titles (case-insensitive)."),
            keywords: ["title", "filter", "exclude", "text"],
            tab: "Filters",
            section: String(localized: "Window Title Filters"),
            icon: "textformat"
        ),
        SettingsSearchItem(
            id: "filters.widgetApps",
            title: String(localized: "Widget App Filters"),
            description: String(localized: "Disable dock hover widgets for selected apps while keeping their regular previews. Useful for browsers that expose media sessions like YouTube."),
            keywords: ["widget", "disable", "media", "youtube"],
            tab: "Filters",
            section: String(localized: "Widget App Filters"),
            icon: "square.grid.2x2"
        ),
    ]

    // MARK: - Widgets

    private static let widgetItems: [SettingsSearchItem] = [
        SettingsSearchItem(
            id: "widgets.enable",
            title: String(localized: "Enable widget controls on Dock hover"),
            keywords: ["widget", "controls", "dock", "hover"],
            tab: "Widgets",
            section: String(localized: "Widget Controls"),
            icon: "square.grid.2x2"
        ),
        SettingsSearchItem(
            id: "widgets.media",
            title: String(localized: "Media controls"),
            description: String(localized: "Show now playing controls when hovering the active media source's Dock icon. Works with any app."),
            keywords: ["media", "music", "now playing", "controls"],
            tab: "Widgets",
            section: String(localized: "Widget Controls"),
            icon: "play.circle"
        ),
        SettingsSearchItem(
            id: "widgets.calendar",
            title: String(localized: "Calendar widget"),
            description: String(localized: "Show today's events when hovering the Calendar Dock icon."),
            keywords: ["calendar", "events", "today", "schedule"],
            tab: "Widgets",
            section: String(localized: "Widget Controls"),
            icon: "calendar"
        ),
        SettingsSearchItem(
            id: "widgets.embedded",
            title: String(localized: "Embed controls alongside window previews"),
            description: String(localized: "Show controls inline with window previews when both are available."),
            keywords: ["embed", "inline", "alongside"],
            tab: "Widgets",
            section: String(localized: "Display"),
            icon: "rectangle.on.rectangle"
        ),
        SettingsSearchItem(
            id: "widgets.fullSize",
            title: String(localized: "Use full-size controls when no windows are open"),
            keywords: ["full", "size", "big", "large"],
            tab: "Widgets",
            section: String(localized: "Display"),
            icon: "rectangle.expand.vertical"
        ),
        SettingsSearchItem(
            id: "widgets.pinning",
            title: String(localized: "Allow pinning controls to screen"),
            description: String(localized: "Right-click a media or calendar widget to pin it."),
            keywords: ["pin", "stick", "float", "always"],
            tab: "Widgets",
            section: String(localized: "Display"),
            icon: "pin"
        ),
        SettingsSearchItem(
            id: "widgets.scrollBehavior",
            title: String(localized: "Behavior:"),
            description: String(localized: "Controls what happens when you scroll on the media widget preview."),
            keywords: ["scroll", "media", "volume", "track"],
            tab: "Widgets",
            section: String(localized: "Media Widget Scroll"),
            icon: "arrow.up.and.down"
        ),
        SettingsSearchItem(
            id: "widgets.detectionMode",
            title: String(localized: "Detection mode:"),
            keywords: ["detection", "mode", "media", "source"],
            tab: "Widgets",
            section: String(localized: "Widget Controls"),
            icon: "antenna.radiowaves.left.and.right"
        ),
        SettingsSearchItem(
            id: "widgets.scrollDirection",
            title: String(localized: "Direction:"),
            description: String(localized: "Horizontal scrolling may interfere with dock preview gestures."),
            keywords: ["scroll", "direction", "horizontal", "vertical", "media"],
            tab: "Widgets",
            section: String(localized: "Media Widget Scroll"),
            icon: "arrow.left.and.right"
        ),
    ]

    // MARK: - Advanced

    private static let advancedItems: [SettingsSearchItem] = [
        SettingsSearchItem(
            id: "advanced.openDelay",
            title: String(localized: "Preview Window Open Delay"),
            keywords: ["delay", "open", "hover", "timer"],
            tab: "Advanced",
            section: String(localized: "Performance Tuning"),
            icon: "timer"
        ),
        SettingsSearchItem(
            id: "advanced.delayOnlyInitial",
            title: String(localized: "Only use delay for initial window opening"),
            description: String(localized: "Switching between dock icons while a preview is already open will show previews instantly."),
            keywords: ["delay", "initial", "instant"],
            tab: "Advanced",
            section: String(localized: "Performance Tuning"),
            icon: "bolt"
        ),
        SettingsSearchItem(
            id: "advanced.fadeOut",
            title: String(localized: "Preview Window Fade Out Duration"),
            keywords: ["fade", "duration", "close", "animation"],
            tab: "Advanced",
            section: String(localized: "Performance Tuning"),
            icon: "rectangle.portrait.and.arrow.right"
        ),
        SettingsSearchItem(
            id: "advanced.inactivity",
            title: String(localized: "Preview Window Inactivity Timer"),
            keywords: ["inactivity", "timeout", "idle", "timer"],
            tab: "Advanced",
            section: String(localized: "Performance Tuning"),
            icon: "clock"
        ),
        SettingsSearchItem(
            id: "advanced.debounce",
            title: String(localized: "Window Processing Debounce Interval"),
            keywords: ["debounce", "processing", "performance"],
            tab: "Advanced",
            section: String(localized: "Performance Tuning"),
            icon: "gauge.with.dots.needle.bottom.50percent"
        ),
        SettingsSearchItem(
            id: "advanced.anchorPosition",
            title: String(localized: "Anchor preview to initial dock icon position"),
            description: String(localized: "Keeps the preview pinned where the dock icon was when first hovered, preventing it from jumping when the dock auto-hides."),
            keywords: ["anchor", "pin", "position", "auto-hide"],
            tab: "Advanced",
            section: String(localized: "Performance Tuning"),
            icon: "pin.circle"
        ),
        SettingsSearchItem(
            id: "advanced.preventDockHide",
            title: String(localized: "Prevent dock from hiding during previews"),
            keywords: ["dock", "hide", "auto-hide", "prevent"],
            tab: "Advanced",
            section: String(localized: "Performance Tuning"),
            icon: "dock.rectangle"
        ),
        SettingsSearchItem(
            id: "advanced.raisedLevel",
            title: String(localized: "Show preview above app labels"),
            keywords: ["above", "level", "layer", "z-index", "raised"],
            tab: "Advanced",
            section: String(localized: "Performance Tuning"),
            icon: "square.3.layers.3d.top.filled"
        ),
        SettingsSearchItem(
            id: "advanced.smallWindows",
            title: String(localized: "Show small windows (under 100px)"),
            description: String(localized: "Includes small windows like Finder's copy progress dialog in previews."),
            keywords: ["small", "tiny", "100px", "filter"],
            tab: "Advanced",
            section: String(localized: "Performance Tuning"),
            icon: "rectangle.arrowtriangle.2.inward"
        ),
        SettingsSearchItem(
            id: "advanced.preventReentry",
            title: String(localized: "Prevent preview reappearance during fade-out"),
            description: String(localized: "Moving the mouse back over the preview during fade-out will not reactivate it."),
            keywords: ["reentry", "fade", "reappear", "prevent"],
            tab: "Advanced",
            section: String(localized: "Performance Tuning"),
            icon: "arrow.uturn.backward"
        ),
        SettingsSearchItem(
            id: "advanced.openNewWindow",
            title: String(localized: "Open a new window when clicking windowless apps"),
            description: String(localized: "Automatically sends ⌘N to open a new window when activating an app with no windows."),
            keywords: ["windowless", "new window", "open", "cmd+n"],
            tab: "Advanced",
            section: String(localized: "Performance Tuning"),
            icon: "plus.rectangle.on.rectangle"
        ),
        SettingsSearchItem(
            id: "advanced.captureQuality",
            title: String(localized: "Window Image Capture Quality"),
            keywords: ["quality", "capture", "resolution", "image"],
            tab: "Advanced",
            section: String(localized: "Preview Quality"),
            icon: "photo"
        ),
        SettingsSearchItem(
            id: "advanced.cacheLifespan",
            title: String(localized: "Window Image Cache Lifespan"),
            keywords: ["cache", "lifespan", "refresh", "stale"],
            tab: "Advanced",
            section: String(localized: "Preview Quality"),
            icon: "clock.arrow.circlepath"
        ),
        SettingsSearchItem(
            id: "advanced.imageScale",
            title: String(localized: "Window Image Resolution Scale (1=Best)"),
            keywords: ["scale", "resolution", "retina", "quality"],
            tab: "Advanced",
            section: String(localized: "Preview Quality"),
            icon: "arrow.up.left.and.arrow.down.right"
        ),
        SettingsSearchItem(
            id: "advanced.livePreview",
            title: String(localized: "Enable Live Preview (Video)"),
            description: String(localized: "Window previews show live video instead of static screenshots. Uses ScreenCaptureKit for real-time capture."),
            keywords: ["live", "video", "stream", "real-time", "screen capture"],
            tab: "Advanced",
            section: String(localized: "Live Preview"),
            icon: "video"
        ),
        SettingsSearchItem(
            id: "advanced.livePreviewDock",
            title: String(localized: "Enable for Dock Preview"),
            keywords: ["live", "dock", "video"],
            tab: "Advanced",
            section: String(localized: "Dock Live Preview"),
            icon: "video"
        ),
        SettingsSearchItem(
            id: "advanced.livePreviewSwitcher",
            title: String(localized: "Enable for Window Switcher"),
            keywords: ["live", "switcher", "video"],
            tab: "Advanced",
            section: String(localized: "Switcher Live Preview"),
            icon: "video"
        ),
        SettingsSearchItem(
            id: "advanced.streamKeepAlive",
            title: String(localized: "Stream Keep-Alive Duration"),
            description: String(localized: "How long to keep video streams active after closing preview. Longer duration means faster reopening but uses more resources."),
            keywords: ["keep alive", "stream", "duration", "resource"],
            tab: "Advanced",
            section: String(localized: "Stream Management"),
            icon: "waveform.path"
        ),
    ]

    // MARK: - Support

    private static let supportItems: [SettingsSearchItem] = [
        SettingsSearchItem(
            id: "support.accessibility",
            title: String(localized: "Accessibility"),
            description: String(localized: "Required for dock hover detection and window switcher hotkeys"),
            keywords: ["permission", "accessibility", "grant", "axui"],
            tab: "Support",
            section: String(localized: "Permissions"),
            icon: "accessibility"
        ),
        SettingsSearchItem(
            id: "support.screenRecording",
            title: String(localized: "Screen Recording"),
            description: String(localized: "Required for capturing window previews. Without this, only compact list view is available."),
            keywords: ["permission", "screen", "recording", "capture", "grant"],
            tab: "Support",
            section: String(localized: "Permissions"),
            icon: "record.circle"
        ),
        SettingsSearchItem(
            id: "support.updateChannel",
            title: String(localized: "Update Channel"),
            description: String(localized: "Choose between stable releases and beta versions"),
            keywords: ["update", "channel", "beta", "stable", "release"],
            tab: "Support",
            section: String(localized: "Updates"),
            icon: "arrow.triangle.branch"
        ),
        SettingsSearchItem(
            id: "support.checkForUpdates",
            title: String(localized: "Check for Updates"),
            keywords: ["update", "check", "new version"],
            tab: "Support",
            section: String(localized: "Updates"),
            icon: "arrow.triangle.2.circlepath"
        ),
        SettingsSearchItem(
            id: "support.automaticUpdates",
            title: String(localized: "Automatic Updates"),
            description: String(localized: "Automatically check for updates in the background"),
            keywords: ["update", "automatic", "background", "check"],
            tab: "Support",
            section: String(localized: "Updates"),
            icon: "clock.arrow.2.circlepath"
        ),
        SettingsSearchItem(
            id: "support.debugLogging",
            title: String(localized: "Debug Logging"),
            description: String(localized: "Capture performance metrics for troubleshooting"),
            keywords: ["debug", "log", "logging", "performance", "troubleshoot"],
            tab: "Support",
            section: String(localized: "Updates"),
            icon: "ant.fill"
        ),
    ]
}
