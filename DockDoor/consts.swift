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
    static let sizingMultiplier = Key<CGFloat>("sizingMultiplier", default: DockUtils.getDockPosition() == .bottom ? 5 : 4)
    static let bufferFromDock = Key<CGFloat>("bufferFromDock", default: CoreDockIsMagnificationEnabled() ? -25 : DockUtils.getDockPosition() == .right ? -18 : -20)
    static let globalPaddingMultiplier = Key<CGFloat>("globalPaddingMultiplier", default: 1.0)
    static let useAccentColorForSelection = Key<Bool>("useAccentColorForSelection", default: false)
    static let hoverWindowOpenDelay = Key<CGFloat>("openDelay", default: 0.2)
    static let lateralMovement = Key<Bool>("lateralMovement", default: true)
    static let preventDockHide = Key<Bool>("preventDockHide", default: false)
    static let preventSwitcherHide = Key<Bool>("preventSwitcherHide", default: false)
    static let shouldHideOnDockItemClick = Key<Bool>("shouldHideOnDockItemClick", default: false)
    static let dockClickAction = Key<DockClickAction>("dockClickAction", default: .hide)

    static let screenCaptureCacheLifespan = Key<CGFloat>("screenCaptureCacheLifespan", default: 60)
    static let windowPreviewImageScale = Key<CGFloat>("windowPreviewImageScale", default: 1)

    static let uniformCardRadius = Key<Bool>("uniformCardRadius", default: true)
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
    static let selectionColor = Key<Color?>("selectionColor", default: nil)

    static let showWindowTitle = Key<Bool>("showWindowTitle", default: true)
    static let showAppIconOnly = Key<Bool>("showAppIconOnly", default: false)
    static let windowTitleDisplayCondition = Key<WindowTitleDisplayCondition>("windowTitleDisplayCondition", default: .all)
    static let windowTitleVisibility = Key<WindowTitleVisibility>("windowTitleVisibility", default: .whenHoveringPreview)
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
    static let dimInSwitcherUntilSelected = Key<Bool>("dimInSwitcherUntilSelected", default: false)
    static let pinnedScreenIdentifier = Key<String>("pinnedScreenIdentifier", default: NSScreen.main?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? String ?? "")

    // MARK: - Window Switcher Filters

    static let limitSwitcherToFrontmostApp = Key<Bool>("limitSwitcherToFrontmostApp", default: false)
    static let fullscreenAppBlacklist = Key<[String]>("fullscreenAppBlacklist", default: [])

    // MARK: - Filters

    static let appNameFilters = Key<[String]>("appNameFilters", default: [])
    static let windowTitleFilters = Key<[String]>("windowTitleFilters", default: [])
    static let customAppDirectories = Key<[String]>("customAppDirectories", default: [])
}

// MARK: Display Configurations

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
