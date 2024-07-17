//
//  consts.swift
//  DockDoor
//
//  Created by Ethan Bills on 6/6/24.
//

import Cocoa
import Defaults
import Foundation

let optimisticScreenSizeWidth = NSScreen.main!.frame.width
let optimisticScreenSizeHeight = NSScreen.main!.frame.height

let roughHeightCap = optimisticScreenSizeHeight / 3
let roughWidthCap = optimisticScreenSizeWidth / 3

extension Defaults.Keys {
    static let sizingMultiplier = Key<CGFloat>("sizingMultiplier", default: 3 )
    static let bufferFromDock = Key<CGFloat>("bufferFromDock", default: 0 )
    static let hoverWindowOpenDelay = Key<CGFloat>("openDelay", default: 0 )
    
    static let screenCaptureCacheLifespan = Key<CGFloat>("screenCaptureCacheLifespan", default: 60 )
    static let uniformCardRadius = Key<Bool>("uniformCardRadius", default: true )
    static let tapEquivalentInterval = Key<CGFloat>("tapEquivalentInterval", default: 1.5 )
    static let previewHoverAction = Key<PreviewHoverAction>("previewHoverAction", default: .none )
    
    static let showAnimations = Key<Bool>("showAnimations", default: true )
    static let enableWindowSwitcher = Key<Bool>("enableWindowSwitcher", default: true )
    static let showMenuBarIcon = Key<Bool>("showMenuBarIcon", default: true)
    static let defaultCMDTABKeybind = Key<Bool>("defaultCMDTABKeybind", default: true )
    static let launched = Key<Bool>("launched", default: false )
    static let Int64maskCommand = Key<Int>("Int64maskCommand", default: 1048840 )
    static let Int64maskControl = Key<Int>("Int64maskControl", default: 262401 )
    static let Int64maskAlternate = Key<Int>("Int64maskAlternate", default: 524576 )
    static let UserKeybind = Key<UserKeyBind>("UserKeybind", default: UserKeyBind(keyCode: 48, modifierFlags: Defaults[.Int64maskControl]))
    
    static let showAppName = Key<Bool>("showAppName", default: true)
    static let appNameStyle = Key<AppNameStyle>("appNameStyle", default: .default )
    
    static let showWindowTitle = Key<Bool>("showWindowTitle", default: true )
    static let windowTitleDisplayCondition = Key<WindowTitleDisplayCondition>("windowTitleDisplayCondition", default: .all)
    static let windowTitleVisibility = Key<WindowTitleVisibility>("windowTitleVisibility", default: .whenHoveringPreview)
    static let windowTitlePosition = Key<WindowTitlePosition>("windowTitlePosition", default: .bottomLeft )
    
    static let trafficLightButtonsVisibility = Key<TrafficLightButtonsVisibility>("trafficLightButtonsVisibility", default: .dimmedOnPreviewHover )
    static let trafficLightButtonsPosition = Key<TrafficLightButtonsPosition>("trafficLightButtonsPosition", default: .topLeft)
}

enum WindowTitleDisplayCondition: String, CaseIterable, Defaults.Serializable {
    case all = "all"
    case dockPreviewsOnly = "dockPreviewsOnly"
    case windowSwitcherOnly = "windowSwitcherOnly"
    
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
    case embedded
    case popover
    
    var localizedName: String {
        switch self {
        case .default:
            String(localized: "Default", comment: "Preview title style option")
        case .embedded:
            String(localized: "Embedded", comment: "Preview title style option")
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
            String(localized: "See a large preview of the window", comment: "Window popup hover action option")
        }
    }
}
