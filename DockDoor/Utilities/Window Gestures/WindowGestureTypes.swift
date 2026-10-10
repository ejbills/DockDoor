import AppKit
import Defaults

enum WindowGestureSection: String, CaseIterable, Identifiable {
    case windows
    case snapping
    case screensAndSpaces
    case tabs
    case dock
    case menuBar

    var id: String { rawValue }

    var title: String {
        switch self {
        case .windows:
            String(localized: "Title Bar", comment: "Window gestures section")
        case .snapping:
            String(localized: "Snapping", comment: "Window gestures section")
        case .screensAndSpaces:
            String(localized: "Displays & Spaces", comment: "Window gestures section")
        case .tabs:
            String(localized: "Tabs", comment: "Window gestures section")
        case .dock:
            String(localized: "Dock & App Menu", comment: "Window gestures section")
        case .menuBar:
            String(localized: "Menu Bar", comment: "Window gestures section")
        }
    }

    var subtitle: String {
        switch self {
        case .windows:
            String(localized: "Swipe, pinch and tap with two fingers on a window's title bar or toolbar.", comment: "Window gestures section description")
        case .snapping:
            String(localized: "Swipe on a title bar to snap the window to a grid. Hold the secondary modifier for thirds, or the tertiary modifier for a 3×3 grid.", comment: "Window gestures section description")
        case .screensAndSpaces:
            String(localized: "Send windows to another display or Desktop space.", comment: "Window gestures section description")
        case .tabs:
            String(localized: "Gestures on a tab in Safari, Chrome, Finder and other apps with tabs.", comment: "Window gestures section description")
        case .dock:
            String(localized: "Gestures on a running app's Dock icon, or on its menu next to the Apple menu.", comment: "Window gestures section description")
        case .menuBar:
            String(localized: "Gestures on an empty part of the menu bar.", comment: "Window gestures section description")
        }
    }

    var gestures: [WindowGesture] {
        WindowGesture.allCases.filter { $0.section == self }
    }
}

enum WindowGesture: String, CaseIterable, Identifiable, Defaults.Serializable {
    case windowClose
    case windowQuit
    case windowMinimize
    case windowFullscreen
    case windowHide

    case snapHalves
    case snapMax
    case snapAlmost
    case snapVertical
    case snapQuarters
    case snapCenter
    case snapThirds
    case snapSixths
    case snapNinths

    case screensMove
    case screensFullscreen
    case spacesMove

    case tabClose
    case tabDetach

    case appCycle
    case appUnminimize
    case appMinimize
    case appQuit
    case appHide
    case appNewTab
    case appChain

    case menubarAppSwitcher
    case menubarMinimize
    case menubarUnminimize
    case menubarUnsnap
    case menubarScreens

    static let disabledByDefault: Set<WindowGesture> = [.snapAlmost]

    var id: String { rawValue }

    var section: WindowGestureSection {
        switch self {
        case .windowClose, .windowQuit, .windowMinimize, .windowFullscreen, .windowHide:
            .windows
        case .snapHalves, .snapMax, .snapAlmost, .snapVertical, .snapQuarters, .snapCenter, .snapThirds, .snapSixths, .snapNinths:
            .snapping
        case .screensMove, .screensFullscreen, .spacesMove:
            .screensAndSpaces
        case .tabClose, .tabDetach:
            .tabs
        case .appCycle, .appUnminimize, .appMinimize, .appQuit, .appHide, .appNewTab, .appChain:
            .dock
        case .menubarAppSwitcher, .menubarMinimize, .menubarUnminimize, .menubarUnsnap, .menubarScreens:
            .menuBar
        }
    }

    var title: String {
        switch self {
        case .windowClose: String(localized: "Close Window", comment: "Window gesture")
        case .windowQuit: String(localized: "Quit App", comment: "Window gesture")
        case .windowMinimize: String(localized: "Minimize", comment: "Window gesture")
        case .windowFullscreen: String(localized: "Full Screen", comment: "Window gesture")
        case .windowHide: String(localized: "Hide App", comment: "Window gesture")
        case .snapHalves: String(localized: "Left & Right Halves", comment: "Window gesture")
        case .snapMax: String(localized: "Fill Screen", comment: "Window gesture")
        case .snapAlmost: String(localized: "Almost Fill Screen", comment: "Window gesture")
        case .snapVertical: String(localized: "Top & Bottom Halves", comment: "Window gesture")
        case .snapQuarters: String(localized: "Quarters", comment: "Window gesture")
        case .snapCenter: String(localized: "Center & Unsnap", comment: "Window gesture")
        case .snapThirds: String(localized: "Thirds", comment: "Window gesture")
        case .snapSixths: String(localized: "Sixths", comment: "Window gesture")
        case .snapNinths: String(localized: "Ninths", comment: "Window gesture")
        case .screensMove: String(localized: "Move to Display", comment: "Window gesture")
        case .screensFullscreen: String(localized: "Full Screen on Other Display", comment: "Window gesture")
        case .spacesMove: String(localized: "Move to Space", comment: "Window gesture")
        case .tabClose: String(localized: "Close Tab", comment: "Window gesture")
        case .tabDetach: String(localized: "Move Tab to New Window", comment: "Window gesture")
        case .appCycle: String(localized: "Cycle Windows", comment: "Window gesture")
        case .appUnminimize: String(localized: "Restore Minimized", comment: "Window gesture")
        case .appMinimize: String(localized: "Minimize Windows", comment: "Window gesture")
        case .appQuit: String(localized: "Quit", comment: "Window gesture")
        case .appHide: String(localized: "Hide", comment: "Window gesture")
        case .appNewTab: String(localized: "New Tab or Window", comment: "Window gesture")
        case .appChain: String(localized: "Pick Up Front Window", comment: "Window gesture")
        case .menubarAppSwitcher: String(localized: "Switch Apps", comment: "Window gesture")
        case .menubarMinimize: String(localized: "Minimize All", comment: "Window gesture")
        case .menubarUnminimize: String(localized: "Restore All", comment: "Window gesture")
        case .menubarUnsnap: String(localized: "Unsnap All", comment: "Window gesture")
        case .menubarScreens: String(localized: "Move Snapped Windows", comment: "Window gesture")
        }
    }

    var instructions: String {
        switch self {
        case .windowClose:
            String(localized: "Pinch in once. You can also swipe down once while holding the general modifier.", comment: "Window gesture instructions")
        case .windowQuit:
            String(localized: "Pinch in twice, pausing in between, or tap and hold and then pinch in. With the general modifier, swipe down twice.", comment: "Window gesture instructions")
        case .windowMinimize:
            String(localized: "Swipe down once. For a full screen window, tap and hold before swiping down.", comment: "Window gesture instructions")
        case .windowFullscreen:
            String(localized: "Pinch out, or tap and hold and then swipe up, to enter or leave full screen.", comment: "Window gesture instructions")
        case .windowHide:
            String(localized: "Double-tap while holding the general modifier to hide the app. Hold the secondary modifier instead to hide every other app.", comment: "Window gesture instructions")
        case .snapHalves:
            String(localized: "Swipe left or right to fill that half of the screen.", comment: "Window gesture instructions")
        case .snapMax:
            String(localized: "Swipe up once to fill the whole screen.", comment: "Window gesture instructions")
        case .snapAlmost:
            String(localized: "Swipe up once to fill the screen with a small margin. Replaces Fill Screen while on.", comment: "Window gesture instructions")
        case .snapVertical:
            String(localized: "Swipe up or down twice, pausing in between, to fill the top or bottom half.", comment: "Window gesture instructions")
        case .snapQuarters:
            String(localized: "Swipe sideways and then up or down, in either order, to fill a quarter.", comment: "Window gesture instructions")
        case .snapCenter:
            String(localized: "Double-tap to center a window and bring back the size it had before it was snapped.", comment: "Window gesture instructions")
        case .snapThirds:
            String(localized: "Hold the secondary modifier and swipe left or right for a third. Swipe twice for two thirds, or tap and hold for the middle third.", comment: "Window gesture instructions")
        case .snapSixths:
            String(localized: "With the secondary modifier, add an up or down swipe to use the top or bottom half of a third.", comment: "Window gesture instructions")
        case .snapNinths:
            String(localized: "Hold the tertiary modifier for a 3×3 grid. Swipe once for an edge row or column and twice to span two.", comment: "Window gesture instructions")
        case .screensMove:
            String(localized: "Hold the screen modifier and swipe toward another display. Snapped windows keep their place in the grid.", comment: "Window gesture instructions")
        case .screensFullscreen:
            String(localized: "Pinch out twice, or pinch out while holding the screen modifier, to go full screen on the other display.", comment: "Window gesture instructions")
        case .spacesMove:
            String(localized: "Tap and hold, then swipe left or right to carry the window to the next Desktop. You can also hold the general modifier instead.", comment: "Window gesture instructions")
        case .tabClose:
            String(localized: "Pinch in on a tab to close it.", comment: "Window gesture instructions")
        case .tabDetach:
            String(localized: "Tap and hold on a tab to move it into its own window, then keep going with any window gesture.", comment: "Window gesture instructions")
        case .appCycle:
            String(localized: "Swipe left or right to bring the app's windows forward one at a time, then keep going with any window gesture.", comment: "Window gesture instructions")
        case .appUnminimize:
            String(localized: "Swipe up to restore the last minimized window. Add the secondary modifier, or pinch out twice, to restore them all.", comment: "Window gesture instructions")
        case .appMinimize:
            String(localized: "Swipe down to minimize the front window. Add the secondary modifier, or pinch in twice, to minimize them all.", comment: "Window gesture instructions")
        case .appQuit:
            String(localized: "Pinch in to quit the app.", comment: "Window gesture instructions")
        case .appHide:
            String(localized: "Double-tap to hide or show the app. Add the secondary modifier to hide every other app instead.", comment: "Window gesture instructions")
        case .appNewTab:
            String(localized: "Pinch out to open a new tab, or a new window in apps without tabs.", comment: "Window gesture instructions")
        case .appChain:
            String(localized: "Tap and hold to bring the app's front window forward, then keep going with any window gesture.", comment: "Window gesture instructions")
        case .menubarAppSwitcher:
            String(localized: "Swipe left or right to switch to the previous or next app in the Dock. Tap and hold, then swipe, to open the window switcher.", comment: "Window gesture instructions")
        case .menubarMinimize:
            String(localized: "Swipe down to minimize every window on this display. Swipe twice, or add the secondary modifier, for all displays.", comment: "Window gesture instructions")
        case .menubarUnminimize:
            String(localized: "Swipe up to restore minimized windows on this display. Swipe twice, or add the secondary modifier, for all displays.", comment: "Window gesture instructions")
        case .menubarUnsnap:
            String(localized: "Double-tap to unsnap every snapped window on this display. Add the secondary modifier for all displays.", comment: "Window gesture instructions")
        case .menubarScreens:
            String(localized: "Hold the screen modifier and swipe to move every snapped window on this display to the next display.", comment: "Window gesture instructions")
        }
    }

    var symbolName: String {
        switch self {
        case .windowClose: "xmark.square"
        case .windowQuit: "xmark.circle"
        case .windowMinimize: "arrow.down.to.line"
        case .windowFullscreen: "arrow.up.left.and.arrow.down.right"
        case .windowHide: "eye.slash"
        case .snapHalves: "rectangle.lefthalf.inset.filled"
        case .snapMax: "rectangle.inset.filled"
        case .snapAlmost: "rectangle.center.inset.filled"
        case .snapVertical: "rectangle.tophalf.inset.filled"
        case .snapQuarters: "rectangle.split.2x2"
        case .snapCenter: "arrow.down.right.and.arrow.up.left"
        case .snapThirds: "rectangle.split.3x1"
        case .snapSixths: "rectangle.split.3x3"
        case .snapNinths: "square.grid.3x3"
        case .screensMove: "display.2"
        case .screensFullscreen: "arrow.up.right.square"
        case .spacesMove: "square.on.square"
        case .tabClose: "xmark.rectangle"
        case .tabDetach: "macwindow.badge.plus"
        case .appCycle: "rectangle.stack"
        case .appUnminimize: "arrow.up.to.line"
        case .appMinimize: "arrow.down.to.line.compact"
        case .appQuit: "power"
        case .appHide: "eye.slash.circle"
        case .appNewTab: "plus.rectangle.on.rectangle"
        case .appChain: "hand.point.up.left"
        case .menubarAppSwitcher: "arrow.left.arrow.right"
        case .menubarMinimize: "rectangle.stack.badge.minus"
        case .menubarUnminimize: "rectangle.stack.badge.plus"
        case .menubarUnsnap: "rectangle.dashed"
        case .menubarScreens: "rectangle.on.rectangle.angled"
        }
    }

    var motionSymbolName: String {
        switch self {
        case .windowClose, .tabClose, .appQuit: "hand.pinch"
        case .windowQuit: "hand.pinch.fill"
        case .windowFullscreen, .appNewTab, .screensFullscreen: "arrow.up.left.and.arrow.down.right"
        case .windowHide, .snapCenter, .appHide, .menubarUnsnap: "hand.tap"
        case .tabDetach, .appChain: "hand.raised"
        case .windowMinimize, .appMinimize, .menubarMinimize: "arrow.down"
        case .snapMax, .snapAlmost, .appUnminimize, .menubarUnminimize: "arrow.up"
        case .snapVertical: "arrow.up.and.down"
        case .snapHalves, .appCycle, .menubarAppSwitcher, .spacesMove: "arrow.left.and.right"
        case .snapQuarters: "arrow.down.right"
        case .snapThirds, .snapSixths, .snapNinths: "square.grid.3x3.topleft.filled"
        case .screensMove, .menubarScreens: "arrow.up.and.down.and.arrow.left.and.right"
        }
    }
}

enum GestureModifierKey: String, CaseIterable, Identifiable, Defaults.Serializable {
    case none
    case function
    case command
    case option
    case control
    case shift

    var id: String { rawValue }

    var eventFlag: CGEventFlags? {
        switch self {
        case .none: nil
        case .function: .maskSecondaryFn
        case .command: .maskCommand
        case .option: .maskAlternate
        case .control: .maskControl
        case .shift: .maskShift
        }
    }

    var symbol: String {
        switch self {
        case .none: ""
        case .function: "fn"
        case .command: "⌘"
        case .option: "⌥"
        case .control: "⌃"
        case .shift: "⇧"
        }
    }

    var localizedName: String {
        switch self {
        case .none: String(localized: "None", comment: "Modifier key option")
        case .function: String(localized: "fn (Globe)", comment: "Modifier key option")
        case .command: String(localized: "Command (⌘)", comment: "Modifier key option")
        case .option: String(localized: "Option (⌥)", comment: "Modifier key option")
        case .control: String(localized: "Control (⌃)", comment: "Modifier key option")
        case .shift: String(localized: "Shift (⇧)", comment: "Modifier key option")
        }
    }
}

enum GestureModifierRole: String, CaseIterable, Identifiable {
    case anywhere
    case general
    case secondary
    case tertiary
    case screen

    var id: String { rawValue }

    var defaultsKey: Defaults.Key<GestureModifierKey> {
        switch self {
        case .anywhere: .windowGestureAnywhereModifier
        case .general: .windowGestureGeneralModifier
        case .secondary: .windowGestureSecondaryModifier
        case .tertiary: .windowGestureTertiaryModifier
        case .screen: .windowGestureScreenModifier
        }
    }

    var title: String {
        switch self {
        case .anywhere: String(localized: "Anywhere Modifier", comment: "Window gesture modifier role")
        case .general: String(localized: "General Modifier", comment: "Window gesture modifier role")
        case .secondary: String(localized: "Secondary Modifier", comment: "Window gesture modifier role")
        case .tertiary: String(localized: "Tertiary Modifier", comment: "Window gesture modifier role")
        case .screen: String(localized: "Screen Modifier", comment: "Window gesture modifier role")
        }
    }

    var explanation: String {
        switch self {
        case .anywhere:
            String(localized: "Hold to use window gestures anywhere on a window, not just its title bar.", comment: "Window gesture modifier role description")
        case .general:
            String(localized: "Close, quit, hide and move between Spaces with swipes and taps.", comment: "Window gesture modifier role description")
        case .secondary:
            String(localized: "Snap to thirds, and act on all windows or all displays.", comment: "Window gesture modifier role description")
        case .tertiary:
            String(localized: "Snap to a 3×3 grid.", comment: "Window gesture modifier role description")
        case .screen:
            String(localized: "Move windows between displays.", comment: "Window gesture modifier role description")
        }
    }

    var symbolName: String {
        switch self {
        case .anywhere: "macwindow"
        case .general: "command"
        case .secondary: "rectangle.split.3x1"
        case .tertiary: "square.grid.3x3"
        case .screen: "display.2"
        }
    }
}

enum WindowGestureTooltipSize: String, CaseIterable, Identifiable, Defaults.Serializable {
    case small
    case medium
    case large

    var id: String { rawValue }

    var scale: CGFloat {
        switch self {
        case .small: 0.85
        case .medium: 1
        case .large: 1.25
        }
    }

    var localizedName: String {
        switch self {
        case .small: String(localized: "Small", comment: "Tooltip size option")
        case .medium: String(localized: "Medium", comment: "Tooltip size option")
        case .large: String(localized: "Large", comment: "Tooltip size option")
        }
    }
}

enum WindowGestureCenterAction: String, CaseIterable, Identifiable, Defaults.Serializable {
    case centerAndRestore
    case restore
    case center

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .centerAndRestore: String(localized: "Center and restore size", comment: "Center gesture option")
        case .restore: String(localized: "Restore size and position", comment: "Center gesture option")
        case .center: String(localized: "Center only", comment: "Center gesture option")
        }
    }
}
