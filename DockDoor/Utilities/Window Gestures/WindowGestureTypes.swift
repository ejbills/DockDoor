import AppKit
import Defaults

enum WindowGestureArea: CaseIterable {
    case titleBar
    case dock
    case menuBar

    var gestures: [WindowGesture] {
        WindowGesture.allCases.filter { $0.area == self }
    }

    var title: String {
        switch self {
        case .titleBar: String(localized: "On a Window's Title Bar")
        case .dock: String(localized: "On a Dock Icon")
        case .menuBar: String(localized: "On the Menu Bar")
        }
    }
}

enum WindowGesture: String, CaseIterable, Identifiable, Defaults.Serializable {
    case snapHalves
    case snapMax
    case snapQuarters
    case windowMinimize
    case windowClose
    case tabClose
    case windowFullscreen
    case snapCenter

    case appMinimize
    case appUnminimize
    case appQuit

    case menubarAppSwitcher
    case menubarMinimize
    case menubarUnminimize

    var id: String { rawValue }

    var area: WindowGestureArea {
        switch self {
        case .snapHalves, .snapMax, .snapQuarters, .windowMinimize, .windowClose, .tabClose, .windowFullscreen, .snapCenter:
            .titleBar
        case .appMinimize, .appUnminimize, .appQuit:
            .dock
        case .menubarAppSwitcher, .menubarMinimize, .menubarUnminimize:
            .menuBar
        }
    }

    var title: String {
        switch self {
        case .snapHalves: String(localized: "Snap Left or Right", comment: "Window gesture")
        case .snapMax: String(localized: "Fill Screen", comment: "Window gesture")
        case .snapQuarters: String(localized: "Snap to a Corner", comment: "Window gesture")
        case .windowMinimize: String(localized: "Minimize", comment: "Window gesture")
        case .windowClose: String(localized: "Close Window", comment: "Window gesture")
        case .tabClose: String(localized: "Close Tab", comment: "Window gesture")
        case .windowFullscreen: String(localized: "Full Screen", comment: "Window gesture")
        case .snapCenter: String(localized: "Center Window", comment: "Window gesture")
        case .appMinimize: String(localized: "Minimize Windows", comment: "Window gesture")
        case .appUnminimize: String(localized: "Restore Minimized", comment: "Window gesture")
        case .appQuit: String(localized: "Quit App", comment: "Window gesture")
        case .menubarAppSwitcher: String(localized: "Switch Apps", comment: "Window gesture")
        case .menubarMinimize: String(localized: "Minimize All Windows", comment: "Window gesture")
        case .menubarUnminimize: String(localized: "Restore All Windows", comment: "Window gesture")
        }
    }

    var summary: String {
        switch self {
        case .snapHalves: String(localized: "Swipe left or right on a title bar to fill that half of the screen.", comment: "Window gesture summary")
        case .snapMax: String(localized: "Swipe up on a title bar to fill the screen.", comment: "Window gesture summary")
        case .snapQuarters: String(localized: "Swipe sideways, then up or down, to fill a corner.", comment: "Window gesture summary")
        case .windowMinimize: String(localized: "Swipe down on a title bar.", comment: "Window gesture summary")
        case .windowClose: String(localized: "Pinch in on a title bar.", comment: "Window gesture summary")
        case .tabClose: String(localized: "Pinch in on a tab to close just that tab.", comment: "Window gesture summary")
        case .windowFullscreen: String(localized: "Pinch out on a title bar to enter or leave full screen.", comment: "Window gesture summary")
        case .snapCenter: String(localized: "Double-tap a title bar to center the window at its earlier size.", comment: "Window gesture summary")
        case .appMinimize: String(localized: "Swipe down on a running app's Dock icon to minimize its front window.", comment: "Window gesture summary")
        case .appUnminimize: String(localized: "Swipe up on a Dock icon to bring back its last minimized window.", comment: "Window gesture summary")
        case .appQuit: String(localized: "Pinch in on a running app's Dock icon to quit it.", comment: "Window gesture summary")
        case .menubarAppSwitcher: String(localized: "Swipe left or right on an empty part of the menu bar to go to the previous or next app.", comment: "Window gesture summary")
        case .menubarMinimize: String(localized: "Swipe down on an empty part of the menu bar to minimize every window on that display.", comment: "Window gesture summary")
        case .menubarUnminimize: String(localized: "Swipe up on an empty part of the menu bar to bring those windows back.", comment: "Window gesture summary")
        }
    }

    var symbolName: String {
        switch self {
        case .snapHalves: "rectangle.lefthalf.inset.filled"
        case .snapMax: "rectangle.inset.filled"
        case .snapQuarters: "rectangle.split.2x2"
        case .windowMinimize: "arrow.down.to.line"
        case .windowClose: "xmark.square"
        case .tabClose: "xmark.rectangle"
        case .windowFullscreen: "arrow.up.left.and.arrow.down.right"
        case .snapCenter: "arrow.down.right.and.arrow.up.left"
        case .appMinimize: "arrow.down.to.line.compact"
        case .appUnminimize: "arrow.up.to.line"
        case .appQuit: "power"
        case .menubarAppSwitcher: "arrow.left.arrow.right"
        case .menubarMinimize: "rectangle.stack.badge.minus"
        case .menubarUnminimize: "rectangle.stack.badge.plus"
        }
    }
}
