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
    static let previewHoverAction = Key<PreviewHoverAction>("previewHoverAction", default: PreviewHoverAction.none )
    
    static let showAnimations = Key<Bool>("showAnimations", default: true )
    static let enableWindowSwitcher = Key<Bool>("enableWindowSwitcher", default: true )
    static let showMenuBarIcon = Key<Bool>("showMenuBarIcon", default: true)
    static let defaultCMDTABKeybind = Key<Bool>("defaultCMDTABKeybind", default: true )
    static let launched = Key<Bool>("launched", default: false )
    static let Int64maskCommand = Key<Int>("Int64maskCommand", default: 1048840 )
    static let Int64maskControl = Key<Int>("Int64maskControl", default: 262401 )
    static let Int64maskAlternate = Key<Int>("Int64maskAlternate", default: 524576 )
    static let UserKeybind = Key<UserKeyBind>("UserKeybind", default: UserKeyBind(keyCode: 48, modifierFlags: Defaults[.Int64maskControl]))
    
    static let showWindowTitle = Key<Bool>("showWindowTitle", default: true )
    static let windowTitleDisplayCondition = Key<WindowTitleDisplayCondition>("windowTitleDisplayCondition", default: .always )
    static let windowTitlePosition = Key<WindowTitlePosition>("windowTitlePosition", default: WindowTitlePosition.bottomLeft )
    static let windowTitleStyle = Key<WindowTitleStyle>("windowTitleStyle", default: .default )
    static let trafficLightButtonsVisibility = Key<TrafficLightButtonsVisibility>("trafficLightButtonsVisibility", default: .dimmedOnWindowHover )
}

enum WindowTitleDisplayCondition: String, CaseIterable, Defaults.Serializable {
    case always = "always"
    case dockPreviewsOnly = "dockPreviewsOnly"
    case windowSwitcherOnly = "windowSwitcherOnly"
    
    var localizedName: String {
        switch self {
        case .always:
            String(localized: "Always", comment: "Preview window title condition option")
        case .dockPreviewsOnly:
            String(localized: "When Showing Dock Tile Previews", comment: "Preview window title condition option")
        case .windowSwitcherOnly:
            String(localized: "When Using Window Switcher", comment: "Preview window title condition option")
        }
    }
}

enum WindowTitlePosition: String, CaseIterable, Defaults.Serializable {
    case bottomLeft
    case bottomRight
    case topRight
    
    var localizedName: String {
        switch self {
        case .bottomLeft:
            String(localized: "Bottom Left", comment: "Preview window title position option")
        case .bottomRight:
            String(localized: "Bottom Right", comment: "Preview window title position option")
        case .topRight:
            String(localized: "Top Right", comment: "Preview window title position option")
        }
    }
}

enum WindowTitleStyle: String, CaseIterable, Defaults.Serializable {
    case hidden
    case `default`
    case embedded
    case popover
    
    var localizedName: String {
        switch self {
        case .hidden:
            String(localized: "Hidden", comment: "Preview title style option")
        case .default:
            String(localized: "Default", comment: "Preview title style option")
        case .embedded:
            String(localized: "Embedded", comment: "Preview title style option")
        case .popover:
            String(localized: "Popover", comment: "Preview title style option")
        }
    }
}

enum TrafficLightButtonsVisibility: String, CaseIterable, Defaults.Serializable {
    case never
    case dimmedOnWindowHover
    case fullOpacityOnWindowHover
    case alwaysVisible
    
    var localizedName: String {
        switch self {
        case .never:
            String(localized: "Never visible", comment: "Traffic light buttons visibility option")
        case .dimmedOnWindowHover:
            String(localized: "On window hover; Dimmed until button hover", comment: "Traffic light buttons visibility option")
        case .fullOpacityOnWindowHover:
            String(localized: "On window hover; Full opacity", comment: "Traffic light buttons visibility option")
        case .alwaysVisible:
            String(localized: "Always visible; Full opacity", comment: "Traffic light buttons visibility option")
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
            String(localized: "No hover action", comment: "Window popup hover action option")
        case .tap:
            String(localized: "Simulate a click", comment: "Window popup hover action option")
        case .previewFullSize:
            String(localized: "See a preview of the window", comment: "Window popup hover action option")
        }
    }
}
