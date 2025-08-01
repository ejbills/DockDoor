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
    static let lateralMovement = Key<Bool>("lateralMovement", default: true)
    static let preventDockHide = Key<Bool>("preventDockHide", default: false)
    static let preventSwitcherHide = Key<Bool>("preventSwitcherHide", default: false)
    static let shouldHideOnDockItemClick = Key<Bool>("shouldHideOnDockItemClick", default: false)
    static let dockClickAction = Key<DockClickAction>("dockClickAction", default: .hide)

    static let screenCaptureCacheLifespan = Key<CGFloat>("screenCaptureCacheLifespan", default: 60)
    static let windowPreviewImageScale = Key<CGFloat>("windowPreviewImageScale", default: 1)

    static let uniformCardRadius = Key<Bool>("uniformCardRadius", default: true)
    static let allowDynamicImageSizing = Key<Bool>("allowDynamicImageSizing", default: false)
    static let tapEquivalentInterval = Key<CGFloat>("tapEquivalentInterval", default: 1.5)
    static let fadeOutDuration = Key<CGFloat>("fadeOutDuration", default: 0.4)
    static let inactivityTimeout = Key<CGFloat>("inactivityTimeout", default: 1.5)
    static let previewHoverAction = Key<PreviewHoverAction>("previewHoverAction", default: .none)
    static let aeroShakeAction = Key<AeroShakeAction>("aeroShakeAction", default: .none)

    static let showSpecialAppControls = Key<Bool>("showSpecialAppControls", default: true)
    static let useEmbeddedMediaControls = Key<Bool>("useEmbeddedMediaControls", default: false)
    static let showBigControlsWhenNoValidWindows = Key<Bool>("showBigControlsWhenNoValidWindows", default: true)
    static let enablePinning = Key<Bool>("enablePinning", default: true)

    static let showAnimations = Key<Bool>("showAnimations", default: true)
    static let gradientColorPalette = Key<GradientColorPaletteSettings>("gradientColorPalette", default: .init())
    static let enableWindowSwitcher = Key<Bool>("enableWindowSwitcher", default: true)
    static let sortWindowsByDate = Key<Bool>("sortWindowsByDate", default: true)
    static let useClassicWindowOrdering = Key<Bool>("useClassicWindowOrdering", default: true)
    static let includeHiddenWindowsInSwitcher = Key<Bool>("includeHiddenWindowsInSwitcher", default: true)
    static let ignoreAppsWithSingleWindow = Key<Bool>("ignoreAppsWithSingleWindow", default: false)
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
    static let unselectedContentOpacity = Key<CGFloat>("unselectedContentOpacity", default: 0.85)
    static let hoverHighlightColor = Key<Color?>("hoverHighlightColor", default: nil)
    static let dockPreviewBackgroundOpacity = Key<CGFloat>("dockPreviewBackgroundOpacity", default: 1.0)

    static let showWindowTitle = Key<Bool>("showWindowTitle", default: true)
    static let showAppIconOnly = Key<Bool>("showAppIconOnly", default: false)
    static let windowTitleDisplayCondition = Key<WindowTitleDisplayCondition>("windowTitleDisplayCondition", default: .all)
    static let windowTitleVisibility = Key<WindowTitleVisibility>("windowTitleVisibility", default: .alwaysVisible)
    static let windowTitlePosition = Key<WindowTitlePosition>("windowTitlePosition", default: .bottomLeft)

    static let trafficLightButtonsVisibility = Key<TrafficLightButtonsVisibility>("trafficLightButtonsVisibility", default: .dimmedOnPreviewHover)
    static let trafficLightButtonsPosition = Key<TrafficLightButtonsPosition>("trafficLightButtonsPosition", default: .topLeft)
    static let enabledTrafficLightButtons = Key<Set<WindowAction>>("enabledTrafficLightButtons", default: [.quit, .close, .minimize, .toggleFullScreen])
    static let useMonochromeTrafficLights = Key<Bool>("useMonochromeTrafficLights", default: false)

    static let previewMaxColumns = Key<Int>("previewMaxColumns", default: 2) // For left/right dock
    static let previewMaxRows = Key<Int>("previewMaxRows", default: 1) // For bottom dock only
    static let switcherMaxRows = Key<Int>("switcherMaxRows", default: 2) // For window switcher

    static let windowSwitcherPlacementStrategy = Key<WindowSwitcherPlacementStrategy>("windowSwitcherPlacementStrategy", default: .screenWithMouse)
    static let windowSwitcherControlPosition = Key<WindowSwitcherControlPosition>("windowSwitcherControlPosition", default: .topTrailing)
    static let dockPreviewControlPosition = Key<WindowSwitcherControlPosition>("dockPreviewControlPosition", default: .topTrailing)
    static let pinnedScreenIdentifier = Key<String>("pinnedScreenIdentifier", default: NSScreen.main?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? String ?? "")

    // MARK: - Window Switcher Filters

    static let limitSwitcherToFrontmostApp = Key<Bool>("limitSwitcherToFrontmostApp", default: false)
    static let fullscreenAppBlacklist = Key<[String]>("fullscreenAppBlacklist", default: [])

    // MARK: - Filters

    static let appNameFilters = Key<[String]>("appNameFilters", default: [])
    static let windowTitleFilters = Key<[String]>("windowTitleFilters", default: [])
    static let customAppDirectories = Key<[String]>("customAppDirectories", default: [])
    static let orphanedWindowAssociations = Key<[OrphanedWindowAssociation]>("orphanedWindowAssociations", default: [])
}
