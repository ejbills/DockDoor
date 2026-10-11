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
    case closeTab
    case toggleFullScreen
    case minimizeFrontWindow
    case restoreLastMinimized
    case quitApp
    case switchApp(forward: Bool)
    case openSwitcher
    case minimizeAllOnDisplay
    case restoreAllOnDisplay

    var isImmediate: Bool {
        switch self {
        case .switchApp, .openSwitcher: true
        default: false
        }
    }

    func title(appName: String?) -> String {
        let name = appName ?? String(localized: "App", comment: "Fallback app name in window gesture tooltip")
        switch self {
        case let .snap(region):
            return region.localizedName
        case .center:
            return String(localized: "Center", comment: "Window gesture tooltip")
        case .minimize, .minimizeFrontWindow:
            return String(localized: "Minimize", comment: "Window gesture tooltip")
        case .close:
            return String(localized: "Close Window", comment: "Window gesture tooltip")
        case .closeTab:
            return String(localized: "Close Tab", comment: "Window gesture tooltip")
        case .toggleFullScreen:
            return String(localized: "Full Screen", comment: "Window gesture tooltip")
        case .restoreLastMinimized:
            return String(localized: "Restore Window", comment: "Window gesture tooltip")
        case .quitApp:
            return String(localized: "Quit \(name)", comment: "Window gesture tooltip, the argument is an app name")
        case let .switchApp(forward):
            return forward
                ? String(localized: "Next App", comment: "Window gesture tooltip")
                : String(localized: "Previous App", comment: "Window gesture tooltip")
        case .openSwitcher:
            return String(localized: "Window Switcher", comment: "Window gesture tooltip")
        case .minimizeAllOnDisplay:
            return String(localized: "Minimize All", comment: "Window gesture tooltip")
        case .restoreAllOnDisplay:
            return String(localized: "Restore All", comment: "Window gesture tooltip")
        }
    }

    var symbolName: String {
        switch self {
        case .snap: "rectangle.split.2x2"
        case .center: "arrow.down.right.and.arrow.up.left"
        case .minimize, .minimizeFrontWindow: "arrow.down.to.line"
        case .close: "xmark.square"
        case .closeTab: "xmark.rectangle"
        case .toggleFullScreen: "arrow.up.left.and.arrow.down.right"
        case .restoreLastMinimized: "arrow.up.to.line"
        case .quitApp: "power"
        case let .switchApp(forward): forward ? "arrow.right" : "arrow.left"
        case .openSwitcher: "uiwindow.split.2x1"
        case .minimizeAllOnDisplay: "rectangle.stack.badge.minus"
        case .restoreAllOnDisplay: "rectangle.stack.badge.plus"
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
    var disabled: Set<WindowGesture> = []
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
            resolveWindow(context, onTab: false, isFullscreen: isFullscreen)
        case let .tab(isFullscreen):
            resolveWindow(context, onTab: true, isFullscreen: isFullscreen)
        case .app:
            resolveApp(context)
        case .menuBar:
            resolveMenuBar(context)
        }
    }

    private static func resolveWindow(_ context: WindowGestureContext, onTab: Bool, isFullscreen: Bool) -> WindowGestureResolution? {
        let steps = context.progress.steps

        if context.doubleTap {
            return isFullscreen ? nil : .init(command: .center, gesture: .snapCenter)
        }

        if !steps.isEmpty, steps.allSatisfy({ $0 == .pinchIn }) {
            return onTab ? .init(command: .closeTab, gesture: .tabClose) : .init(command: .close, gesture: .windowClose)
        }
        if !steps.isEmpty, steps.allSatisfy({ $0 == .pinchOut }) {
            return .init(command: .toggleFullScreen, gesture: .windowFullscreen)
        }
        guard !isFullscreen else { return nil }

        let horizontal = steps.filter(\.isHorizontal)
        let vertical = steps.filter(\.isVertical)
        guard horizontal.count + vertical.count == steps.count, horizontal.count <= 1, vertical.count <= 1 else { return nil }

        switch (horizontal.first, vertical.first) {
        case let (horizontalStep?, nil):
            return .init(command: .snap(horizontalStep == .left ? .leftHalf : .rightHalf), gesture: .snapHalves)
        case (nil, .up?):
            return .init(command: .snap(.maximize), gesture: .snapMax)
        case (nil, .down?):
            return .init(command: .minimize, gesture: .windowMinimize)
        case let (horizontalStep?, verticalStep?):
            let region: SnapRegion = switch (horizontalStep, verticalStep) {
            case (.left, .up): .topLeftQuarter
            case (.right, .up): .topRightQuarter
            case (.left, _): .bottomLeftQuarter
            default: .bottomRightQuarter
            }
            return .init(command: .snap(region), gesture: .snapQuarters)
        default:
            return nil
        }
    }

    private static func resolveApp(_ context: WindowGestureContext) -> WindowGestureResolution? {
        let steps = context.progress.steps
        if !steps.isEmpty, steps.allSatisfy({ $0 == .pinchIn }) {
            return .init(command: .quitApp, gesture: .appQuit)
        }
        switch steps {
        case [.up]: return .init(command: .restoreLastMinimized, gesture: .appUnminimize)
        case [.down]: return .init(command: .minimizeFrontWindow, gesture: .appMinimize)
        default: return nil
        }
    }

    private static func resolveMenuBar(_ context: WindowGestureContext) -> WindowGestureResolution? {
        let steps = context.progress.steps
        guard let first = steps.first, !first.isPinch else { return nil }
        if context.progress.held {
            return .init(command: .openSwitcher, gesture: .menubarAppSwitcher)
        }
        switch steps {
        case [.left]: return .init(command: .switchApp(forward: false), gesture: .menubarAppSwitcher)
        case [.right]: return .init(command: .switchApp(forward: true), gesture: .menubarAppSwitcher)
        case [.down]: return .init(command: .minimizeAllOnDisplay, gesture: .menubarMinimize)
        case [.up]: return .init(command: .restoreAllOnDisplay, gesture: .menubarUnminimize)
        default: return nil
        }
    }
}
