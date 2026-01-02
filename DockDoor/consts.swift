import Carbon.HIToolbox.Events
import Cocoa
import Defaults
import Foundation
import SwiftUI

let optimisticScreenSizeWidth = NSScreen.main!.frame.width
let optimisticScreenSizeHeight = NSScreen.main!.frame.height

let roughHeightCap = optimisticScreenSizeHeight / 3
let roughWidthCap = optimisticScreenSizeWidth / 3

let spotifyAppIdentifier = "com.spotify.client"
let appleMusicAppIdentifier = "com.apple.Music"
let calendarAppIdentifier = "com.apple.iCal"

extension Defaults.Keys {
    static let previewWidth = Key<CGFloat>("previewWidth", default: 300)
    static let previewHeight = Key<CGFloat>("previewHeight", default: 187.5)
    static let lockAspectRatio = Key<Bool>("lockAspectRatio", default: true)
    static let bufferFromDock = Key<CGFloat>("bufferFromDock", default: CoreDockIsMagnificationEnabled() ? -25 : DockUtils.getDockPosition() == .right ? -18 : -20)
    static let globalPaddingMultiplier = Key<CGFloat>("globalPaddingMultiplier", default: 1.0)
    static let hoverWindowOpenDelay = Key<CGFloat>("openDelay", default: 0.2)
    static let useDelayOnlyForInitialOpen = Key<Bool>("useDelayOnlyForInitialOpen", default: false)
    static let preventDockHide = Key<Bool>("preventDockHide", default: false)
    static let preventSwitcherHide = Key<Bool>("preventSwitcherHide", default: false)
    static let requireShiftTabToGoBack = Key<Bool>("requireShiftTabToGoBack", default: false)
    static let shouldHideOnDockItemClick = Key<Bool>("shouldHideOnDockItemClick", default: false)
    static let dockClickAction = Key<DockClickAction>("dockClickAction", default: .hide)
    static let enableCmdRightClickQuit = Key<Bool>("enableCmdRightClickQuit", default: true)
    static let enableDockScrollGesture = Key<Bool>("enableDockScrollGesture", default: false)
    static let dockIconMediaScrollBehavior = Key<DockIconMediaScrollBehavior>("dockIconMediaScrollBehavior", default: .adjustVolume)
    static let mediaWidgetScrollBehavior = Key<MediaWidgetScrollBehavior>("mediaWidgetScrollBehavior", default: .seekPlayback)
    static let mediaWidgetScrollDirection = Key<MediaWidgetScrollDirection>("mediaWidgetScrollDirection", default: .vertical)

    static let screenCaptureCacheLifespan = Key<CGFloat>("screenCaptureCacheLifespan", default: 60)
    static let windowProcessingDebounceInterval = Key<CGFloat>("windowProcessingDebounceInterval", default: 0.3)
    static let windowPreviewImageScale = Key<CGFloat>("windowPreviewImageScale", default: 1)
    static let windowImageCaptureQuality = Key<WindowImageCaptureQuality>("windowImageCaptureQuality", default: .nominal)

    static let enableLivePreview = Key<Bool>("enableLivePreview", default: false)
    static let enableLivePreviewForDock = Key<Bool>("enableLivePreviewForDock", default: true)
    static let enableLivePreviewForWindowSwitcher = Key<Bool>("enableLivePreviewForWindowSwitcher", default: false)
    static let dockLivePreviewQuality = Key<LivePreviewQuality>("dockLivePreviewQuality", default: .high)
    static let dockLivePreviewFrameRate = Key<LivePreviewFrameRate>("dockLivePreviewFrameRate", default: .fps24)
    static let windowSwitcherLivePreviewQuality = Key<LivePreviewQuality>("windowSwitcherLivePreviewQuality", default: .low)
    static let windowSwitcherLivePreviewFrameRate = Key<LivePreviewFrameRate>("windowSwitcherLivePreviewFrameRate", default: .fps10)
    static let windowSwitcherLivePreviewScope = Key<WindowSwitcherLivePreviewScope>("windowSwitcherLivePreviewScope", default: .selectedAppWindows)
    static let livePreviewStreamKeepAlive = Key<Int>("livePreviewStreamKeepAlive", default: 0)

    static let uniformCardRadius = Key<Bool>("uniformCardRadius", default: true)
    static let allowDynamicImageSizing = Key<Bool>("allowDynamicImageSizing", default: false)
    static let tapEquivalentInterval = Key<CGFloat>("tapEquivalentInterval", default: 1.5)
    static let fadeOutDuration = Key<CGFloat>("fadeOutDuration", default: 0.4)
    static let preventPreviewReentryDuringFadeOut = Key<Bool>("preventPreviewReentryDuringFadeOut", default: false)
    static let inactivityTimeout = Key<CGFloat>("inactivityTimeout", default: 0.2)
    static let previewHoverAction = Key<PreviewHoverAction>("previewHoverAction", default: .none)
    static let aeroShakeAction = Key<AeroShakeAction>("aeroShakeAction", default: .none)

    static let showSpecialAppControls = Key<Bool>("showSpecialAppControls", default: true)
    static let useEmbeddedMediaControls = Key<Bool>("useEmbeddedMediaControls", default: false)
    static let useEmbeddedDockPreviewElements = Key<Bool>("useEmbeddedDockPreviewElements", default: false)
    static let disableDockStyleTrafficLights = Key<Bool>("disableDockStyleTrafficLights", default: false)
    static let disableDockStyleTitles = Key<Bool>("disableDockStyleTitles", default: false)
    static let showBigControlsWhenNoValidWindows = Key<Bool>("showBigControlsWhenNoValidWindows", default: true)
    static let enablePinning = Key<Bool>("enablePinning", default: true)

    static let persistedWindowOrder = Key<[WindowOrderPersistence.PersistedWindowEntry]>("persistedWindowOrder", default: [])
    static let showAnimations = Key<Bool>("showAnimations", default: true)
    static let gradientColorPalette = Key<GradientColorPaletteSettings>("gradientColorPalette", default: .init())
    static let enableWindowSwitcher = Key<Bool>("enableWindowSwitcher", default: true)
    static let instantWindowSwitcher = Key<Bool>("instantWindowSwitcher", default: false)
    static let enableDockPreviews = Key<Bool>("enableDockPreviews", default: true)
    static let showWindowsFromCurrentSpaceOnly = Key<Bool>("showWindowsFromCurrentSpaceOnly", default: false)
    static let windowPreviewSortOrder = Key<WindowPreviewSortOrder>("windowPreviewSortOrder", default: .recentlyUsed)
    static let showWindowsFromCurrentSpaceOnlyInSwitcher = Key<Bool>("showWindowsFromCurrentSpaceOnlyInSwitcher", default: false)
    static let windowSwitcherSortOrder = Key<WindowPreviewSortOrder>("windowSwitcherSortOrder", default: .recentlyUsed)
    static let showWindowsFromCurrentSpaceOnlyInCmdTab = Key<Bool>("showWindowsFromCurrentSpaceOnlyInCmdTab", default: false)
    static let cmdTabSortOrder = Key<WindowPreviewSortOrder>("cmdTabSortOrder", default: .recentlyUsed)
    static let sortMinimizedToEnd = Key<Bool>("sortMinimizedToEnd", default: false)
    static let enableCmdTabEnhancements = Key<Bool>("enableCmdTabEnhancements", default: false)
    static let enableMouseHoverInSwitcher = Key<Bool>("enableMouseHoverInSwitcher", default: true)
    static let mouseHoverAutoScrollSpeed = Key<CGFloat>("mouseHoverAutoScrollSpeed", default: 4.0)
    static let keepPreviewOnAppTerminate = Key<Bool>("keepPreviewOnAppTerminate", default: false)
    static let enableWindowSwitcherSearch = Key<Bool>("enableWindowSwitcherSearch", default: false)
    static let compactModeTitleFormat = Key<CompactModeTitleFormat>("compactModeTitleFormat", default: .appNameAndTitle)
    static let compactModeItemSize = Key<CompactModeItemSize>("compactModeItemSize", default: .medium)

    // Per-feature compact mode thresholds (0 = disabled, 1+ = enable when window count >= threshold)
    static let windowSwitcherCompactThreshold = Key<Int>("windowSwitcherCompactThreshold", default: 0)
    static let dockPreviewCompactThreshold = Key<Int>("dockPreviewCompactThreshold", default: 0)
    static let cmdTabCompactThreshold = Key<Int>("cmdTabCompactThreshold", default: 0)
    static let searchFuzziness = Key<Int>("searchFuzziness", default: 3)
    static let useClassicWindowOrdering = Key<Bool>("useClassicWindowOrdering", default: true)
    static let includeHiddenWindowsInSwitcher = Key<Bool>("includeHiddenWindowsInSwitcher", default: true)
    static let ignoreAppsWithSingleWindow = Key<Bool>("ignoreAppsWithSingleWindow", default: false)
    static let groupAppInstancesInDock = Key<Bool>("groupAppInstancesInDock", default: true)
    static let useLiquidGlass = Key<Bool>("useLiquidGlass", default: true)
    static let showMenuBarIcon = Key<Bool>("showMenuBarIcon", default: true)
    static let raisedWindowLevel = Key<Bool>("raisedWindowLevel", default: true)
    static let launched = Key<Bool>("launched", default: false)
    static let Int64maskCommand = Key<Int>("Int64maskCommand", default: 1_048_840)
    static let Int64maskControl = Key<Int>("Int64maskControl", default: 262_401)
    static let Int64maskAlternate = Key<Int>("Int64maskAlternate", default: 524_576)
    static let UserKeybind = Key<UserKeyBind>("UserKeybind", default: UserKeyBind(keyCode: 48, modifierFlags: Defaults[.Int64maskAlternate]))

    static let showAppName = Key<Bool>("showAppName", default: true)
    static let appNameStyle = Key<AppNameStyle>("appNameStyle", default: .default)
    static let selectionOpacity = Key<CGFloat>("selectionOpacity", default: 0.4)
    static let unselectedContentOpacity = Key<CGFloat>("unselectedContentOpacity", default: 0.75)
    static let hoverHighlightColor = Key<Color?>("hoverHighlightColor", default: nil)
    static let dockPreviewBackgroundOpacity = Key<CGFloat>("dockPreviewBackgroundOpacity", default: 1.0)
    static let hidePreviewCardBackground = Key<Bool>("hidePreviewCardBackground", default: false)
    static let hideHoverContainerBackground = Key<Bool>("hideHoverContainerBackground", default: false)
    static let showActiveWindowBorder = Key<Bool>("showActiveWindowBorder", default: false)

    // MARK: - Dock Preview Appearance Settings

    static let showWindowTitle = Key<Bool>("showWindowTitle", default: true)
    static let showAppIconOnly = Key<Bool>("showAppIconOnly", default: false)
    static let windowTitleDisplayCondition = Key<WindowTitleDisplayCondition>("windowTitleDisplayCondition", default: .all)
    static let windowTitleVisibility = Key<WindowTitleVisibility>("windowTitleVisibility", default: .alwaysVisible)
    static let windowTitlePosition = Key<WindowTitlePosition>("windowTitlePosition", default: .bottomLeft)
    static let enableTitleMarquee = Key<Bool>("enableTitleMarquee", default: true)
    static let trafficLightButtonsVisibility = Key<TrafficLightButtonsVisibility>("trafficLightButtonsVisibility", default: .dimmedOnPreviewHover)
    static let trafficLightButtonsPosition = Key<TrafficLightButtonsPosition>("trafficLightButtonsPosition", default: .topLeft)
    static let enabledTrafficLightButtons = Key<Set<WindowAction>>("enabledTrafficLightButtons", default: [.quit, .close, .minimize, .toggleFullScreen])
    static let useMonochromeTrafficLights = Key<Bool>("useMonochromeTrafficLights", default: false)
    static let showMinimizedHiddenLabels = Key<Bool>("showMinimizedHiddenLabels", default: true)

    // MARK: - Window Switcher Appearance Settings

    static let switcherShowWindowTitle = Key<Bool>("switcherShowWindowTitle", default: true)
    static let switcherWindowTitleVisibility = Key<WindowTitleVisibility>("switcherWindowTitleVisibility", default: .alwaysVisible)
    static let switcherTrafficLightButtonsVisibility = Key<TrafficLightButtonsVisibility>("switcherTrafficLightButtonsVisibility", default: .dimmedOnPreviewHover)
    static let switcherEnabledTrafficLightButtons = Key<Set<WindowAction>>("switcherEnabledTrafficLightButtons", default: [.quit, .close, .minimize, .toggleFullScreen])
    static let switcherUseMonochromeTrafficLights = Key<Bool>("switcherUseMonochromeTrafficLights", default: false)
    static let switcherDisableDockStyleTrafficLights = Key<Bool>("switcherDisableDockStyleTrafficLights", default: false)

    // MARK: - Cmd+Tab Appearance Settings

    static let cmdTabShowAppName = Key<Bool>("cmdTabShowAppName", default: true)
    static let cmdTabAppNameStyle = Key<AppNameStyle>("cmdTabAppNameStyle", default: .default)
    static let cmdTabShowAppIconOnly = Key<Bool>("cmdTabShowAppIconOnly", default: false)
    static let cmdTabShowWindowTitle = Key<Bool>("cmdTabShowWindowTitle", default: true)
    static let cmdTabWindowTitleVisibility = Key<WindowTitleVisibility>("cmdTabWindowTitleVisibility", default: .alwaysVisible)
    static let cmdTabWindowTitlePosition = Key<WindowTitlePosition>("cmdTabWindowTitlePosition", default: .bottomLeft)
    static let cmdTabTrafficLightButtonsVisibility = Key<TrafficLightButtonsVisibility>("cmdTabTrafficLightButtonsVisibility", default: .dimmedOnPreviewHover)
    static let cmdTabTrafficLightButtonsPosition = Key<TrafficLightButtonsPosition>("cmdTabTrafficLightButtonsPosition", default: .topLeft)
    static let cmdTabEnabledTrafficLightButtons = Key<Set<WindowAction>>("cmdTabEnabledTrafficLightButtons", default: [.quit, .close, .minimize, .toggleFullScreen])
    static let cmdTabUseMonochromeTrafficLights = Key<Bool>("cmdTabUseMonochromeTrafficLights", default: false)
    static let cmdTabControlPosition = Key<WindowSwitcherControlPosition>("cmdTabControlPosition", default: .topTrailing)
    static let cmdTabUseEmbeddedDockPreviewElements = Key<Bool>("cmdTabUseEmbeddedDockPreviewElements", default: false)
    static let cmdTabDisableDockStyleTrafficLights = Key<Bool>("cmdTabDisableDockStyleTrafficLights", default: false)
    static let cmdTabDisableDockStyleTitles = Key<Bool>("cmdTabDisableDockStyleTitles", default: false)

    static let previewMaxColumns = Key<Int>("previewMaxColumns", default: 2) // For left/right dock
    static let previewMaxRows = Key<Int>("previewMaxRows", default: 1) // For bottom dock only
    static let switcherMaxRows = Key<Int>("switcherMaxRows", default: 2) // For window switcher

    static let windowSwitcherPlacementStrategy = Key<WindowSwitcherPlacementStrategy>("windowSwitcherPlacementStrategy", default: .screenWithMouse)
    static let windowSwitcherControlPosition = Key<WindowSwitcherControlPosition>("windowSwitcherControlPosition", default: .topTrailing)
    static let windowSwitcherHorizontalOffsetPercent = Key<CGFloat>("windowSwitcherHorizontalOffsetPercent", default: 0)
    static let windowSwitcherVerticalOffsetPercent = Key<CGFloat>("windowSwitcherVerticalOffsetPercent", default: 0)
    static let windowSwitcherAnchorToTop = Key<Bool>("windowSwitcherAnchorToTop", default: false)
    static let enableShiftWindowSwitcherPlacement = Key<Bool>("enableShiftWindowSwitcherPlacement", default: false)
    static let dockPreviewControlPosition = Key<WindowSwitcherControlPosition>("dockPreviewControlPosition", default: .topTrailing)
    static let pinnedScreenIdentifier = Key<String>("pinnedScreenIdentifier", default: NSScreen.main?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? String ?? "")

    // MARK: - Window Switcher Filters

    static let limitSwitcherToFrontmostApp = Key<Bool>("limitSwitcherToFrontmostApp", default: false)
    static let fullscreenAppBlacklist = Key<[String]>("fullscreenAppBlacklist", default: [])

    // MARK: - Filters

    static let appNameFilters = Key<[String]>("appNameFilters", default: [])
    static let windowTitleFilters = Key<[String]>("windowTitleFilters", default: [])
    static let groupedAppsInSwitcher = Key<[String]>("groupedAppsInSwitcher", default: [])
    static let customAppDirectories = Key<[String]>("customAppDirectories", default: [])
    static let filteredCalendarIdentifiers = Key<[String]>("filteredCalendarIdentifiers", default: [])
    static let hasSeenCmdTabFocusHint = Key<Bool>("hasSeenCmdTabFocusHint", default: false)
    static let disableImagePreview = Key<Bool>("disableImagePreview", default: false)
    static let debugMode = Key<Bool>("debugMode", default: false)

    // MARK: - Active App Indicator

    static let showActiveAppIndicator = Key<Bool>("showActiveAppIndicator", default: false)
    static let activeAppIndicatorColor = Key<Color>("activeAppIndicatorColor", default: Color.accentColor)
    static let activeAppIndicatorAutoSize = Key<Bool>("activeAppIndicatorAutoSize", default: true)
    static let activeAppIndicatorAutoLength = Key<Bool>("activeAppIndicatorAutoLength", default: false)
    static let activeAppIndicatorHeight = Key<CGFloat>("activeAppIndicatorHeight", default: 4.0)
    static let activeAppIndicatorOffset = Key<CGFloat>("activeAppIndicatorOffset", default: 5.0)
    static let activeAppIndicatorLength = Key<CGFloat>("activeAppIndicatorLength", default: 40.0)
    static let activeAppIndicatorShift = Key<CGFloat>("activeAppIndicatorShift", default: 0.0)

    // MARK: - Trackpad Gestures

    static let gestureSwipeThreshold = Key<CGFloat>("gestureSwipeThreshold", default: 50)

    // Dock Preview Gestures (towards/away from dock - automatically translates based on dock position)
    static let enableDockPreviewGestures = Key<Bool>("enableDockPreviewGestures", default: true)
    static let dockSwipeTowardsDockAction = Key<WindowAction>("dockSwipeTowardsDockAction", default: .minimize)
    static let dockSwipeAwayFromDockAction = Key<WindowAction>("dockSwipeAwayFromDockAction", default: .maximize)

    // Window Switcher Gestures (up/down only - switcher is always horizontally centered)
    static let enableWindowSwitcherGestures = Key<Bool>("enableWindowSwitcherGestures", default: true)
    static let switcherSwipeUpAction = Key<WindowAction>("switcherSwipeUpAction", default: .maximize)
    static let switcherSwipeDownAction = Key<WindowAction>("switcherSwipeDownAction", default: .minimize)

    // MARK: - Middle Click Action

    static let middleClickAction = Key<WindowAction>("middleClickAction", default: .close)

    // MARK: - Window Switcher Keyboard Shortcuts (Cmd+key)

    // Each shortcut has a key code (the letter/key) and an action
    // The Cmd modifier is always required - only the key is customizable

    static let cmdShortcut1Key = Key<UInt16>("cmdShortcut1Key", default: UInt16(kVK_ANSI_W))
    static let cmdShortcut1Action = Key<WindowAction>("cmdShortcut1Action", default: .close)

    static let cmdShortcut2Key = Key<UInt16>("cmdShortcut2Key", default: UInt16(kVK_ANSI_M))
    static let cmdShortcut2Action = Key<WindowAction>("cmdShortcut2Action", default: .minimize)

    static let cmdShortcut3Key = Key<UInt16>("cmdShortcut3Key", default: UInt16(kVK_ANSI_Q))
    static let cmdShortcut3Action = Key<WindowAction>("cmdShortcut3Action", default: .quit)

    // MARK: - Alternate Window Switcher Keybind (shares modifier with primary keybind)

    static let alternateKeybindKey = Key<UInt16>("alternateKeybindKey", default: 0)
    static let alternateKeybindMode = Key<SwitcherInvocationMode>("alternateKeybindMode", default: .activeAppOnly)
}

// MARK: Display Configurations

enum WindowImageCaptureQuality: String, CaseIterable, Defaults.Serializable {
    case nominal
    case best

    var localizedName: String {
        switch self {
        case .nominal:
            String(localized: "Improved performance (nominal)", comment: "Window image capture quality option")
        case .best:
            String(localized: "Best quality (full resolution)", comment: "Window image capture quality option")
        }
    }
}

enum WindowTitleDisplayCondition: String, CaseIterable, Defaults.Serializable {
    case all
    case dockPreviewsOnly
    case windowSwitcherOnly

    var localizedName: String {
        switch self {
        case .all:
            String(localized: "Dock Previews & Window Switcher", comment: "Preview window title display condition option")
        case .dockPreviewsOnly:
            String(localized: "Dock Previews only", comment: "Preview window title condition display option")
        case .windowSwitcherOnly:
            String(localized: "Window Switcher only", comment: "Preview window title condition display option")
        }
    }
}

enum WindowTitlePosition: String, CaseIterable, Defaults.Serializable {
    case bottomLeft
    case bottomRight
    case topRight
    case topLeft

    var localizedName: String {
        switch self {
        case .bottomLeft:
            String(localized: "Bottom Left", comment: "Preview window title position option")
        case .bottomRight:
            String(localized: "Bottom Right", comment: "Preview window title position option")
        case .topRight:
            String(localized: "Top Right", comment: "Preview window title position option")
        case .topLeft:
            String(localized: "Top Left", comment: "Preview window title position option")
        }
    }
}

enum AppNameStyle: String, CaseIterable, Defaults.Serializable {
    case `default`
    case shadowed
    case popover

    var localizedName: String {
        switch self {
        case .default:
            String(localized: "Default", comment: "Preview title style option")
        case .shadowed:
            String(localized: "Shadowed", comment: "Preview title style option")
        case .popover:
            String(localized: "Popover", comment: "Preview title style option")
        }
    }
}

enum WindowTitleVisibility: String, CaseIterable, Defaults.Serializable {
    case whenHoveringPreview
    case alwaysVisible

    var localizedName: String {
        switch self {
        case .whenHoveringPreview:
            String(localized: "When hovering over the preview", comment: "Window title visibility option")
        case .alwaysVisible:
            String(localized: "Always visible", comment: "Window title visibility option")
        }
    }
}

enum TrafficLightButtonsVisibility: String, CaseIterable, Defaults.Serializable {
    case never
    case dimmedOnPreviewHover
    case fullOpacityOnPreviewHover
    case alwaysVisible

    var localizedName: String {
        switch self {
        case .never:
            String(localized: "Never visible", comment: "Traffic light buttons visibility option")
        case .dimmedOnPreviewHover:
            String(localized: "On window hover; Dimmed until button hover", comment: "Traffic light buttons visibility option")
        case .fullOpacityOnPreviewHover:
            String(localized: "On window hover; Full opacity", comment: "Traffic light buttons visibility option")
        case .alwaysVisible:
            String(localized: "Always visible; Full opacity", comment: "Traffic light buttons visibility option")
        }
    }
}

enum TrafficLightButtonsPosition: String, CaseIterable, Defaults.Serializable {
    case topLeft
    case topRight
    case bottomRight
    case bottomLeft

    var localizedName: String {
        switch self {
        case .topLeft:
            String(localized: "Top Left", comment: "Traffic light buttons position option")
        case .topRight:
            String(localized: "Top Right", comment: "Traffic light buttons position option")
        case .bottomRight:
            String(localized: "Bottom Right", comment: "Traffic light buttons position option")
        case .bottomLeft:
            String(localized: "Bottom Left", comment: "Traffic light buttons position option")
        }
    }
}

enum WindowSwitcherPlacementStrategy: String, CaseIterable, Defaults.Serializable {
    case screenWithMouse
    case screenWithLastActiveWindow
    case pinnedToScreen

    var localizedName: String {
        switch self {
        case .screenWithMouse:
            String(localized: "Screen with mouse", comment: "Window switcher placement option")
        case .screenWithLastActiveWindow:
            String(localized: "Screen with last active window", comment: "Window switcher placement option")
        case .pinnedToScreen:
            String(localized: "Pinned to screen", comment: "Window switcher placement option")
        }
    }
}

enum WindowSwitcherControlPosition: String, CaseIterable, Defaults.Serializable {
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing
    case diagonalTopLeftBottomRight
    case diagonalTopRightBottomLeft
    case diagonalBottomLeftTopRight
    case diagonalBottomRightTopLeft
    case parallelTopLeftBottomLeft
    case parallelTopRightBottomRight
    case parallelBottomLeftTopLeft
    case parallelBottomRightTopRight

    var localizedName: String {
        switch self {
        case .topLeading:
            String(localized: "At top - Title on left, controls on right")
        case .topTrailing:
            String(localized: "At top - Controls on left, title on right")
        case .bottomLeading:
            String(localized: "At bottom - Title on left, controls on right")
        case .bottomTrailing:
            String(localized: "At bottom - Controls on left, title on right")
        case .diagonalTopLeftBottomRight:
            String(localized: "Diagonal - Title top left, controls bottom right")
        case .diagonalTopRightBottomLeft:
            String(localized: "Diagonal - Title top right, controls bottom left")
        case .diagonalBottomLeftTopRight:
            String(localized: "Diagonal - Title bottom left, controls top right")
        case .diagonalBottomRightTopLeft:
            String(localized: "Diagonal - Title bottom right, controls top left")
        case .parallelTopLeftBottomLeft:
            String(localized: "Parallel - Title top left, controls bottom left")
        case .parallelTopRightBottomRight:
            String(localized: "Parallel - Title top right, controls bottom right")
        case .parallelBottomLeftTopLeft:
            String(localized: "Parallel - Title bottom left, controls top left")
        case .parallelBottomRightTopRight:
            String(localized: "Parallel - Title bottom right, controls top right")
        }
    }

    var showsOnTop: Bool {
        switch self {
        case .topLeading, .topTrailing,
             .diagonalTopLeftBottomRight, .diagonalTopRightBottomLeft,
             .diagonalBottomLeftTopRight, .diagonalBottomRightTopLeft,
             .parallelTopLeftBottomLeft, .parallelTopRightBottomRight,
             .parallelBottomLeftTopLeft, .parallelBottomRightTopRight:
            true
        case .bottomLeading, .bottomTrailing:
            false
        }
    }

    var showsOnBottom: Bool {
        switch self {
        case .bottomLeading, .bottomTrailing,
             .diagonalTopLeftBottomRight, .diagonalTopRightBottomLeft,
             .diagonalBottomLeftTopRight, .diagonalBottomRightTopLeft,
             .parallelTopLeftBottomLeft, .parallelTopRightBottomRight,
             .parallelBottomLeftTopLeft, .parallelBottomRightTopRight:
            true
        case .topLeading, .topTrailing:
            false
        }
    }

    var topConfiguration: (isLeadingControls: Bool, showTitle: Bool, showControls: Bool) {
        switch self {
        case .topLeading, .bottomLeading:
            (false, true, true)
        case .topTrailing, .bottomTrailing:
            (true, true, true)
        case .diagonalTopLeftBottomRight, .parallelTopLeftBottomLeft:
            (false, true, false)
        case .diagonalTopRightBottomLeft, .parallelTopRightBottomRight:
            (true, true, false)
        case .diagonalBottomLeftTopRight, .parallelBottomRightTopRight:
            (false, false, true)
        case .diagonalBottomRightTopLeft, .parallelBottomLeftTopLeft:
            (true, false, true)
        }
    }

    var bottomConfiguration: (isLeadingControls: Bool, showTitle: Bool, showControls: Bool) {
        switch self {
        case .topLeading, .bottomLeading:
            (false, true, true)
        case .topTrailing, .bottomTrailing:
            (true, true, true)
        case .diagonalTopLeftBottomRight:
            (false, false, true)
        case .diagonalTopRightBottomLeft:
            (true, false, true)
        case .diagonalBottomLeftTopRight:
            (false, true, false)
        case .diagonalBottomRightTopLeft:
            (true, true, false)
        case .parallelTopLeftBottomLeft:
            (true, false, true) // controls on left
        case .parallelTopRightBottomRight:
            (false, false, true) // controls on right
        case .parallelBottomLeftTopLeft:
            (false, true, false) // title on left
        case .parallelBottomRightTopRight:
            (true, true, false) // title on right
        }
    }
}

// MARK: Action Configurations

enum PreviewHoverAction: String, CaseIterable, Defaults.Serializable {
    case none
    case tap
    case previewFullSize

    var localizedName: String {
        switch self {
        case .none:
            String(localized: "No action", comment: "Window popup hover action option")
        case .tap:
            String(localized: "Simulate a click (open the window)", comment: "Window popup hover action option")
        case .previewFullSize:
            String(localized: "Present a full size preview of the window", comment: "Window popup hover action option")
        }
    }
}

enum AeroShakeAction: String, CaseIterable, Defaults.Serializable {
    case none
    case all
    case except

    var localizedName: String {
        switch self {
        case .none:
            String(localized: "No action", comment: "Aero shake action option")
        case .all:
            String(localized: "Minimize all windows", comment: "Aero shake action option")
        case .except:
            String(localized: "Minimize all windows except the current one", comment: "Aero shake action option")
        }
    }
}

enum DockClickAction: String, CaseIterable, Defaults.Serializable {
    case minimize
    case hide

    var localizedName: String {
        switch self {
        case .minimize:
            String(localized: "Minimize windows", comment: "Dock click action option")
        case .hide:
            String(localized: "Hide application", comment: "Dock click action option")
        }
    }
}

// Dock icon scroll behavior for Music/Spotify
enum DockIconMediaScrollBehavior: String, CaseIterable, Defaults.Serializable {
    case adjustVolume
    case activateHide

    var localizedName: String {
        switch self {
        case .adjustVolume:
            String(localized: "Adjust volume", comment: "Dock icon media scroll option")
        case .activateHide:
            String(localized: "Activate/Hide (same as other apps)", comment: "Dock icon media scroll option")
        }
    }
}

// Media widget scroll behavior
enum MediaWidgetScrollBehavior: String, CaseIterable, Defaults.Serializable {
    case adjustVolume
    case seekPlayback

    var localizedName: String {
        switch self {
        case .adjustVolume:
            String(localized: "Adjust volume", comment: "Media widget scroll option")
        case .seekPlayback:
            String(localized: "Seek playback (scrub through track)", comment: "Media widget scroll option")
        }
    }
}

// Media widget scroll direction
enum MediaWidgetScrollDirection: String, CaseIterable, Defaults.Serializable {
    case vertical
    case horizontal

    var localizedName: String {
        switch self {
        case .vertical:
            String(localized: "Vertical", comment: "Media widget scroll direction option")
        case .horizontal:
            String(localized: "Horizontal", comment: "Media widget scroll direction option")
        }
    }
}

enum WindowPreviewSortOrder: String, CaseIterable, Defaults.Serializable, Identifiable {
    case recentlyUsed
    case creationOrder
    case alphabeticalByTitle
    case alphabeticalByAppName

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .recentlyUsed:
            String(localized: "Recently used", comment: "Window preview sort order option")
        case .creationOrder:
            String(localized: "Creation order (fixed)", comment: "Window preview sort order option")
        case .alphabeticalByTitle:
            String(localized: "Alphabetical by title", comment: "Window preview sort order option")
        case .alphabeticalByAppName:
            String(localized: "Grouped by app name", comment: "Window preview sort order option")
        }
    }

    /// Whether this sort order is applicable only for window switcher (multi-app context)
    var isWindowSwitcherOnly: Bool {
        switch self {
        case .alphabeticalByAppName:
            true
        default:
            false
        }
    }
}

enum SwitcherInvocationMode: String, CaseIterable, Defaults.Serializable, Identifiable {
    case allWindows
    case activeAppOnly
    case currentSpaceOnly
    case activeAppCurrentSpace

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .allWindows:
            String(localized: "All Windows", comment: "Switcher invocation mode")
        case .activeAppOnly:
            String(localized: "Active App Only", comment: "Switcher invocation mode")
        case .currentSpaceOnly:
            String(localized: "Current Space Only", comment: "Switcher invocation mode")
        case .activeAppCurrentSpace:
            String(localized: "Active App + Current Space", comment: "Switcher invocation mode")
        }
    }

    var localizedDescription: String {
        switch self {
        case .allWindows:
            String(localized: "Uses your default window switcher settings", comment: "Switcher invocation mode description")
        case .activeAppOnly:
            String(localized: "Shows only windows from the frontmost application", comment: "Switcher invocation mode description")
        case .currentSpaceOnly:
            String(localized: "Shows only windows from the current Space", comment: "Switcher invocation mode description")
        case .activeAppCurrentSpace:
            String(localized: "Shows only windows from the frontmost app in the current Space", comment: "Switcher invocation mode description")
        }
    }
}

enum LivePreviewQuality: String, CaseIterable, Defaults.Serializable, Identifiable {
    case thumbnail
    case low
    case standard
    case high
    case retina
    case native

    var id: String { rawValue }

    var scaleFactor: Int {
        switch self {
        case .thumbnail: 1
        case .low: 1
        case .standard: 1
        case .high: 1
        case .retina: 2
        case .native: 2
        }
    }

    var useFullResolution: Bool {
        switch self {
        case .thumbnail, .low: false
        case .standard, .high, .retina, .native: true
        }
    }

    var maxDimension: Int {
        switch self {
        case .thumbnail: 320
        case .low: 480
        case .standard: 640
        case .high: 960
        case .retina: 1280
        case .native: 0 // No limit
        }
    }

    var localizedName: String {
        switch self {
        case .thumbnail:
            String(localized: "Thumbnail (320px)")
        case .low:
            String(localized: "Low (480px)")
        case .standard:
            String(localized: "Standard (640px)")
        case .high:
            String(localized: "High (960px)")
        case .retina:
            String(localized: "Retina (1280px)")
        case .native:
            String(localized: "Native (Best)")
        }
    }
}

enum LivePreviewFrameRate: String, CaseIterable, Defaults.Serializable, Identifiable {
    case fps5
    case fps10
    case fps15
    case fps24
    case fps30
    case fps60
    case fps120

    var id: String { rawValue }

    var frameRate: Int32 {
        switch self {
        case .fps5: 5
        case .fps10: 10
        case .fps15: 15
        case .fps24: 24
        case .fps30: 30
        case .fps60: 60
        case .fps120: 120
        }
    }

    var localizedName: String {
        switch self {
        case .fps5:
            String(localized: "5 FPS")
        case .fps10:
            String(localized: "10 FPS")
        case .fps15:
            String(localized: "15 FPS")
        case .fps24:
            String(localized: "24 FPS")
        case .fps30:
            String(localized: "30 FPS")
        case .fps60:
            String(localized: "60 FPS")
        case .fps120:
            String(localized: "120 FPS (ProMotion)")
        }
    }
}

enum CompactModeTitleFormat: String, CaseIterable, Defaults.Serializable, Identifiable {
    case appNameAndTitle // App name on top, window title below
    case titleOnly // Window title only (or app name if no title)
    case appNameOnly // App name only

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .appNameAndTitle:
            String(localized: "App Name + Window Title")
        case .titleOnly:
            String(localized: "Window Title Only")
        case .appNameOnly:
            String(localized: "App Name Only")
        }
    }
}

enum CompactModeItemSize: Int, CaseIterable, Defaults.Serializable, Identifiable {
    case xSmall = 0
    case small = 1
    case medium = 2
    case large = 3
    case xLarge = 4
    case xxLarge = 5
    case xxxLarge = 6

    var id: Int { rawValue }

    var localizedName: String {
        switch self {
        case .xSmall:
            String(localized: "X-Small", comment: "Compact mode item size option")
        case .small:
            String(localized: "Small", comment: "Compact mode item size option")
        case .medium:
            String(localized: "Medium", comment: "Compact mode item size option")
        case .large:
            String(localized: "Large", comment: "Compact mode item size option")
        case .xLarge:
            String(localized: "X-Large", comment: "Compact mode item size option")
        case .xxLarge:
            String(localized: "2X-Large", comment: "Compact mode item size option")
        case .xxxLarge:
            String(localized: "3X-Large", comment: "Compact mode item size option")
        }
    }

    var primaryFont: Font {
        switch self {
        case .xSmall: .caption
        case .small: .callout
        case .medium: .system(size: 13, weight: .medium)
        case .large: .headline
        case .xLarge: .title3
        case .xxLarge: .title2
        case .xxxLarge: .title
        }
    }

    var secondaryFont: Font {
        switch self {
        case .xSmall: .caption2
        case .small: .caption
        case .medium: .system(size: 11)
        case .large: .callout
        case .xLarge: .body
        case .xxLarge: .headline
        case .xxxLarge: .title3
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .xSmall: 24
        case .small: 28
        case .medium: 32
        case .large: 36
        case .xLarge: 40
        case .xxLarge: 48
        case .xxxLarge: 56
        }
    }

    var rowHeight: CGFloat {
        switch self {
        case .xSmall: 36
        case .small: 40
        case .medium: 48
        case .large: 52
        case .xLarge: 56
        case .xxLarge: 64
        case .xxxLarge: 72
        }
    }
}

/// Window Switcher live preview scope - determines which windows get live preview
enum WindowSwitcherLivePreviewScope: String, CaseIterable, Defaults.Serializable, Identifiable {
    case selectedWindowOnly
    case selectedAppWindows
    case allWindows

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .selectedWindowOnly:
            String(localized: "Selected Window Only")
        case .selectedAppWindows:
            String(localized: "Selected App's Windows")
        case .allWindows:
            String(localized: "All Windows")
        }
    }

    var localizedDescription: String {
        switch self {
        case .selectedWindowOnly:
            String(localized: "Only the currently selected window gets live preview")
        case .selectedAppWindows:
            String(localized: "All windows from the selected app get live preview")
        case .allWindows:
            String(localized: "All windows get live preview (may cause lag with many windows)")
        }
    }
}
