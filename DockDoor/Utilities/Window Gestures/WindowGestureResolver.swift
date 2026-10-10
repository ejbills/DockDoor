import AppKit

enum GestureDirection: Equatable {
    case left
    case right
    case up
    case down

    init?(_ step: GestureStep) {
        switch step {
        case .left: self = .left
        case .right: self = .right
        case .up: self = .up
        case .down: self = .down
        case .pinchIn, .pinchOut: return nil
        }
    }
}

enum WindowGestureZoneKind: Equatable {
    case window(isFullscreen: Bool)
    case tab(isFullscreen: Bool)
    case app
    case menuBar
}

enum WindowGestureCommand: Equatable {
    case snap(SnapRegion)
    case center
    case minimize
    case close
    case quitApp
    case toggleFullScreen
    case fullScreenOnOtherDisplay
    case hideApp
    case hideOtherApps
    case moveToSpace(offset: Int)
    case moveToDisplay(GestureDirection)
    case closeTab
    case detachTab
    case cycleWindows(forward: Bool)
    case restoreLastMinimized
    case restoreAllMinimized
    case minimizeFrontWindow
    case minimizeAllWindows
    case newTabOrWindow
    case toggleHidden
    case pickUpFrontWindow
    case switchApp(forward: Bool)
    case openSwitcher
    case minimizeAllOnDisplay(allDisplays: Bool)
    case restoreAllOnDisplay(allDisplays: Bool)
    case unsnapAll(allDisplays: Bool)
    case moveSnappedWindows(GestureDirection)

    var isImmediate: Bool {
        switch self {
        case .moveToDisplay, .detachTab, .cycleWindows, .restoreLastMinimized, .pickUpFrontWindow, .switchApp, .openSwitcher:
            true
        default:
            false
        }
    }

    var chainsWindow: Bool {
        switch self {
        case .detachTab, .cycleWindows, .restoreLastMinimized, .pickUpFrontWindow:
            true
        default:
            false
        }
    }

    var changesWindowFrame: Bool {
        switch self {
        case .snap, .center: true
        default: false
        }
    }

    func title(appName: String?, centerAction: WindowGestureCenterAction) -> String {
        let name = appName ?? String(localized: "App", comment: "Fallback app name in window gesture tooltip")
        switch self {
        case let .snap(region):
            return region.localizedName
        case .center:
            switch centerAction {
            case .centerAndRestore: return String(localized: "Center & Unsnap", comment: "Window gesture tooltip")
            case .restore: return String(localized: "Unsnap", comment: "Window gesture tooltip")
            case .center: return String(localized: "Center", comment: "Window gesture tooltip")
            }
        case .minimize, .minimizeFrontWindow:
            return String(localized: "Minimize", comment: "Window gesture tooltip")
        case .close:
            return String(localized: "Close Window", comment: "Window gesture tooltip")
        case .quitApp:
            return String(localized: "Quit \(name)", comment: "Window gesture tooltip, the argument is an app name")
        case .toggleFullScreen:
            return String(localized: "Full Screen", comment: "Window gesture tooltip")
        case .fullScreenOnOtherDisplay:
            return String(localized: "Full Screen on Other Display", comment: "Window gesture tooltip")
        case .hideApp:
            return String(localized: "Hide \(name)", comment: "Window gesture tooltip, the argument is an app name")
        case .hideOtherApps:
            return String(localized: "Hide Others", comment: "Window gesture tooltip")
        case let .moveToSpace(offset):
            return offset < 0
                ? String(localized: "Move to Space on the Left", comment: "Window gesture tooltip")
                : String(localized: "Move to Space on the Right", comment: "Window gesture tooltip")
        case .moveToDisplay:
            return String(localized: "Move to Display", comment: "Window gesture tooltip")
        case .closeTab:
            return String(localized: "Close Tab", comment: "Window gesture tooltip")
        case .detachTab:
            return String(localized: "Move Tab to New Window", comment: "Window gesture tooltip")
        case let .cycleWindows(forward):
            return forward
                ? String(localized: "Next Window", comment: "Window gesture tooltip")
                : String(localized: "Previous Window", comment: "Window gesture tooltip")
        case .restoreLastMinimized:
            return String(localized: "Restore Window", comment: "Window gesture tooltip")
        case .restoreAllMinimized:
            return String(localized: "Restore All Windows", comment: "Window gesture tooltip")
        case .minimizeAllWindows:
            return String(localized: "Minimize All Windows", comment: "Window gesture tooltip")
        case .newTabOrWindow:
            return String(localized: "New Tab or Window", comment: "Window gesture tooltip")
        case .toggleHidden:
            return String(localized: "Hide \(name)", comment: "Window gesture tooltip, the argument is an app name")
        case .pickUpFrontWindow:
            return String(localized: "Pick Up Window", comment: "Window gesture tooltip")
        case let .switchApp(forward):
            return forward
                ? String(localized: "Next App", comment: "Window gesture tooltip")
                : String(localized: "Previous App", comment: "Window gesture tooltip")
        case .openSwitcher:
            return String(localized: "Window Switcher", comment: "Window gesture tooltip")
        case let .minimizeAllOnDisplay(allDisplays):
            return allDisplays
                ? String(localized: "Minimize All on Every Display", comment: "Window gesture tooltip")
                : String(localized: "Minimize All on This Display", comment: "Window gesture tooltip")
        case let .restoreAllOnDisplay(allDisplays):
            return allDisplays
                ? String(localized: "Restore All on Every Display", comment: "Window gesture tooltip")
                : String(localized: "Restore All on This Display", comment: "Window gesture tooltip")
        case let .unsnapAll(allDisplays):
            return allDisplays
                ? String(localized: "Unsnap All on Every Display", comment: "Window gesture tooltip")
                : String(localized: "Unsnap All on This Display", comment: "Window gesture tooltip")
        case .moveSnappedWindows:
            return String(localized: "Move Snapped Windows", comment: "Window gesture tooltip")
        }
    }

    var symbolName: String {
        switch self {
        case .snap: "rectangle.split.2x2"
        case .center: "arrow.down.right.and.arrow.up.left"
        case .minimize, .minimizeFrontWindow: "arrow.down.to.line"
        case .close: "xmark.square"
        case .quitApp: "power"
        case .toggleFullScreen: "arrow.up.left.and.arrow.down.right"
        case .fullScreenOnOtherDisplay: "arrow.up.right.square"
        case .hideApp, .toggleHidden: "eye.slash"
        case .hideOtherApps: "eye.slash.circle"
        case let .moveToSpace(offset): offset < 0 ? "arrow.left.square" : "arrow.right.square"
        case let .moveToDisplay(direction), let .moveSnappedWindows(direction):
            switch direction {
            case .left: "arrow.left.to.line"
            case .right: "arrow.right.to.line"
            case .up: "arrow.up.to.line"
            case .down: "arrow.down.to.line"
            }
        case .closeTab: "xmark.rectangle"
        case .detachTab: "macwindow.badge.plus"
        case let .cycleWindows(forward): forward ? "arrow.right.circle" : "arrow.left.circle"
        case .restoreLastMinimized, .restoreAllMinimized: "arrow.up.to.line"
        case .minimizeAllWindows: "arrow.down.to.line.compact"
        case .newTabOrWindow: "plus.rectangle.on.rectangle"
        case .pickUpFrontWindow: "hand.point.up.left"
        case let .switchApp(forward): forward ? "arrow.right" : "arrow.left"
        case .openSwitcher: "uiwindow.split.2x1"
        case .minimizeAllOnDisplay: "rectangle.stack.badge.minus"
        case .restoreAllOnDisplay: "rectangle.stack.badge.plus"
        case .unsnapAll: "rectangle.dashed"
        }
    }
}

struct WindowGestureResolution: Equatable {
    let command: WindowGestureCommand
    let gesture: WindowGesture
}

struct WindowGestureContext {
    var zone: WindowGestureZoneKind
    var progress = GestureProgress()
    var doubleTap = false
    var modifiers: Set<GestureModifierRole> = []
    var isPortrait = false
    var hasOtherDisplays = false
    var disabled: Set<WindowGesture> = WindowGesture.disabledByDefault
}

enum WindowGestureResolver {
    static func resolve(_ context: WindowGestureContext) -> WindowGestureResolution? {
        guard let resolution = rawResolution(context), !context.disabled.contains(resolution.gesture) else {
            return nil
        }
        return resolution
    }

    private static func rawResolution(_ context: WindowGestureContext) -> WindowGestureResolution? {
        switch context.zone {
        case let .window(isFullscreen):
            fullscreenFiltered(resolveWindow(context, onTab: false), isFullscreen: isFullscreen, held: context.progress.held)
        case let .tab(isFullscreen):
            fullscreenFiltered(resolveWindow(context, onTab: true), isFullscreen: isFullscreen, held: context.progress.held)
        case .app:
            resolveApp(context)
        case .menuBar:
            resolveMenuBar(context)
        }
    }

    private static func fullscreenFiltered(_ resolution: WindowGestureResolution?, isFullscreen: Bool, held: Bool) -> WindowGestureResolution? {
        guard isFullscreen, let resolution else { return resolution }
        switch resolution.command {
        case .toggleFullScreen, .close, .quitApp, .hideApp, .hideOtherApps, .closeTab, .detachTab:
            return resolution
        case .minimize:
            return held ? resolution : nil
        default:
            return nil
        }
    }

    // MARK: - Windows

    private static func resolveWindow(_ context: WindowGestureContext, onTab: Bool) -> WindowGestureResolution? {
        let modifiers = context.modifiers
        let steps = context.progress.steps
        let held = context.progress.held

        if context.doubleTap {
            if modifiers.contains(.secondary) { return .init(command: .hideOtherApps, gesture: .windowHide) }
            if modifiers.contains(.general) { return .init(command: .hideApp, gesture: .windowHide) }
            return .init(command: .center, gesture: .snapCenter)
        }

        if let first = steps.first, first.isPinch {
            guard steps.allSatisfy({ $0 == first }) else { return nil }
            if first == .pinchIn {
                if onTab, steps.count == 1, !held, modifiers.isEmpty {
                    return .init(command: .closeTab, gesture: .tabClose)
                }
                if steps.count >= 2 || held {
                    return .init(command: .quitApp, gesture: .windowQuit)
                }
                return .init(command: .close, gesture: .windowClose)
            }
            if steps.count >= 2 || held || modifiers.contains(.screen) {
                guard context.hasOtherDisplays else {
                    return steps.count == 1 ? .init(command: .toggleFullScreen, gesture: .windowFullscreen) : nil
                }
                return .init(command: .fullScreenOnOtherDisplay, gesture: .screensFullscreen)
            }
            return .init(command: .toggleFullScreen, gesture: .windowFullscreen)
        }

        if modifiers.contains(.screen) {
            guard let last = steps.last, let direction = GestureDirection(last) else { return nil }
            return .init(command: .moveToDisplay(direction), gesture: .screensMove)
        }

        if steps.isEmpty {
            guard held else { return nil }
            if onTab { return .init(command: .detachTab, gesture: .tabDetach) }
            if modifiers.contains(.tertiary) {
                return .init(command: .snap(SnapRegion(columns: 3, rows: 3, columnSpan: 1 ... 1, rowSpan: 0 ... 2)), gesture: .snapNinths)
            }
            if modifiers.contains(.secondary) {
                let middle = SnapRegion(columns: 3, rows: 1, columnSpan: 1 ... 1, rowSpan: 0 ... 0)
                return .init(command: .snap(context.isPortrait ? middle.transposed : middle), gesture: .snapThirds)
            }
            return nil
        }

        let horizontal = steps.filter(\.isHorizontal)
        let vertical = steps.filter(\.isVertical)
        guard isConsistent(horizontal), isConsistent(vertical) else { return nil }

        if modifiers.contains(.tertiary) {
            return resolveNinths(horizontal: horizontal, vertical: vertical, held: held)
        }
        if modifiers.contains(.secondary) {
            if let thirds = resolveThirds(horizontal: horizontal, vertical: vertical, held: held, isPortrait: context.isPortrait) {
                return thirds
            }
        }
        if modifiers.contains(.general) || held {
            return resolveGeneral(horizontal: horizontal, vertical: vertical, held: held, general: modifiers.contains(.general))
        }
        return resolveHalvesAndQuarters(horizontal: horizontal, vertical: vertical, disabled: context.disabled)
    }

    private static func resolveGeneral(horizontal: [GestureStep], vertical: [GestureStep], held: Bool, general: Bool) -> WindowGestureResolution? {
        if vertical.isEmpty, let direction = horizontal.first {
            let offset = direction == .left ? -horizontal.count : horizontal.count
            return .init(command: .moveToSpace(offset: offset), gesture: .spacesMove)
        }
        guard horizontal.isEmpty, let direction = vertical.first else { return nil }
        if general {
            guard direction == .down else { return nil }
            return vertical.count >= 2
                ? .init(command: .quitApp, gesture: .windowQuit)
                : .init(command: .close, gesture: .windowClose)
        }
        guard vertical.count == 1 else { return nil }
        return direction == .up
            ? .init(command: .toggleFullScreen, gesture: .windowFullscreen)
            : .init(command: .minimize, gesture: .windowMinimize)
    }

    private static func resolveHalvesAndQuarters(horizontal: [GestureStep], vertical: [GestureStep], disabled: Set<WindowGesture>) -> WindowGestureResolution? {
        switch (horizontal.first, horizontal.count, vertical.first, vertical.count) {
        case let (horizontalStep?, 1, nil, 0):
            return .init(command: .snap(horizontalStep == .left ? .leftHalf : .rightHalf), gesture: .snapHalves)
        case let (horizontalStep?, 1, verticalStep?, 1):
            let region: SnapRegion = switch (horizontalStep, verticalStep) {
            case (.left, .up): .topLeftQuarter
            case (.right, .up): .topRightQuarter
            case (.left, _): .bottomLeftQuarter
            default: .bottomRightQuarter
            }
            return .init(command: .snap(region), gesture: .snapQuarters)
        case (nil, 0, .up?, 1):
            return disabled.contains(.snapAlmost)
                ? .init(command: .snap(.maximize), gesture: .snapMax)
                : .init(command: .snap(.almostMaximize), gesture: .snapAlmost)
        case (nil, 0, .up?, 2):
            return .init(command: .snap(.topHalf), gesture: .snapVertical)
        case (nil, 0, .down?, 1):
            return .init(command: .minimize, gesture: .windowMinimize)
        case (nil, 0, .down?, 2):
            return .init(command: .snap(.bottomHalf), gesture: .snapVertical)
        default:
            return nil
        }
    }

    private static func resolveThirds(horizontal: [GestureStep], vertical: [GestureStep], held: Bool, isPortrait: Bool) -> WindowGestureResolution? {
        let along = isPortrait ? vertical.map(rotatedForPortrait) : horizontal
        let across = isPortrait ? horizontal.map(rotatedForPortrait) : vertical
        guard !along.isEmpty || held else { return nil }
        guard across.count <= 1 else { return nil }

        let columns: ClosedRange<Int> = span(along, negative: .left, held: held)
        let region: SnapRegion
        let gesture: WindowGesture
        if let acrossStep = across.first {
            let row = acrossStep == .up ? 0 : 1
            region = SnapRegion(columns: 3, rows: 2, columnSpan: columns, rowSpan: row ... row)
            gesture = .snapSixths
        } else {
            region = SnapRegion(columns: 3, rows: 1, columnSpan: columns, rowSpan: 0 ... 0)
            gesture = .snapThirds
        }
        return .init(command: .snap(isPortrait ? region.transposed : region), gesture: gesture)
    }

    private static func resolveNinths(horizontal: [GestureStep], vertical: [GestureStep], held: Bool) -> WindowGestureResolution? {
        guard !horizontal.isEmpty || !vertical.isEmpty else { return nil }
        let columns = span(horizontal, negative: .left, held: held)
        let rows = span(vertical, negative: .up, held: false)
        return .init(command: .snap(SnapRegion(columns: 3, rows: 3, columnSpan: columns, rowSpan: rows)), gesture: .snapNinths)
    }

    private static func span(_ steps: [GestureStep], negative: GestureStep, held: Bool) -> ClosedRange<Int> {
        guard let first = steps.first else { return held ? 1 ... 1 : 0 ... 2 }
        let twice = steps.count >= 2
        if first == negative {
            return twice ? 0 ... 1 : 0 ... 0
        }
        return twice ? 1 ... 2 : 2 ... 2
    }

    private static func rotatedForPortrait(_ step: GestureStep) -> GestureStep {
        switch step {
        case .up: .left
        case .down: .right
        case .left: .up
        case .right: .down
        default: step
        }
    }

    private static func isConsistent(_ steps: [GestureStep]) -> Bool {
        guard let first = steps.first else { return true }
        return steps.allSatisfy { $0 == first }
    }

    // MARK: - Apps

    private static func resolveApp(_ context: WindowGestureContext) -> WindowGestureResolution? {
        let modifiers = context.modifiers
        let steps = context.progress.steps

        if context.doubleTap {
            return modifiers.contains(.secondary)
                ? .init(command: .hideOtherApps, gesture: .appHide)
                : .init(command: .toggleHidden, gesture: .appHide)
        }

        if let first = steps.first, first.isPinch {
            guard steps.allSatisfy({ $0 == first }) else { return nil }
            if first == .pinchIn {
                return steps.count >= 2
                    ? .init(command: .minimizeAllWindows, gesture: .appMinimize)
                    : .init(command: .quitApp, gesture: .appQuit)
            }
            return steps.count >= 2
                ? .init(command: .restoreAllMinimized, gesture: .appUnminimize)
                : .init(command: .newTabOrWindow, gesture: .appNewTab)
        }

        guard let first = steps.first else {
            return context.progress.held ? .init(command: .pickUpFrontWindow, gesture: .appChain) : nil
        }
        guard steps.allSatisfy({ $0 == first }) else { return nil }

        switch first {
        case .left, .right:
            guard steps.count == 1 else { return nil }
            return .init(command: .cycleWindows(forward: first == .right), gesture: .appCycle)
        case .up:
            return modifiers.contains(.secondary) || steps.count >= 2
                ? .init(command: .restoreAllMinimized, gesture: .appUnminimize)
                : .init(command: .restoreLastMinimized, gesture: .appUnminimize)
        case .down:
            return modifiers.contains(.secondary) || steps.count >= 2
                ? .init(command: .minimizeAllWindows, gesture: .appMinimize)
                : .init(command: .minimizeFrontWindow, gesture: .appMinimize)
        case .pinchIn, .pinchOut:
            return nil
        }
    }

    // MARK: - Menu Bar

    private static func resolveMenuBar(_ context: WindowGestureContext) -> WindowGestureResolution? {
        let modifiers = context.modifiers
        let steps = context.progress.steps
        let allDisplays = modifiers.contains(.secondary)

        if context.doubleTap {
            return .init(command: .unsnapAll(allDisplays: allDisplays), gesture: .menubarUnsnap)
        }

        guard let first = steps.first, !first.isPinch else { return nil }

        if context.progress.held {
            return .init(command: .openSwitcher, gesture: .menubarAppSwitcher)
        }

        if modifiers.contains(.screen) {
            guard let last = steps.last, let direction = GestureDirection(last) else { return nil }
            return .init(command: .moveSnappedWindows(direction), gesture: .menubarScreens)
        }

        guard steps.allSatisfy({ $0 == first }) else { return nil }
        switch first {
        case .left, .right:
            guard steps.count == 1 else { return nil }
            return .init(command: .switchApp(forward: first == .right), gesture: .menubarAppSwitcher)
        case .down:
            return .init(command: .minimizeAllOnDisplay(allDisplays: allDisplays || steps.count >= 2), gesture: .menubarMinimize)
        case .up:
            return .init(command: .restoreAllOnDisplay(allDisplays: allDisplays || steps.count >= 2), gesture: .menubarUnminimize)
        case .pinchIn, .pinchOut:
            return nil
        }
    }
}
