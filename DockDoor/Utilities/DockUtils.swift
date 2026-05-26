import Cocoa
import Defaults

enum DockPosition {
    case top
    case bottom
    case left
    case right
    case cmdTab
    case cli
    case unknown

    var isHorizontalFlow: Bool {
        switch self {
        case .top, .bottom, .cmdTab, .cli:
            true
        case .left, .right:
            false
        case .unknown:
            true
        }
    }
}

class DockUtils {
    static func getDockPosition() -> DockPosition {
        var orientation: Int32 = 0
        var pinning: Int32 = 0
        CoreDockGetOrientationAndPinning(&orientation, &pinning)
        switch orientation {
        case 1: return .top
        case 2: return .bottom
        case 3: return .left
        case 4: return .right
        default: return .unknown
        }
    }

    /// Returns the dock size in points based on the screen's visible frame.
    static func getDockSize(on screen: NSScreen? = nil) -> CGFloat {
        let dockPosition = getDockPosition()

        if let screen {
            return dockSize(on: screen, dockPosition: dockPosition)
        }

        return NSScreen.screens
            .map { dockSize(on: $0, dockPosition: dockPosition) }
            .max() ?? 0
    }

    private static func dockSize(on screen: NSScreen, dockPosition: DockPosition) -> CGFloat {
        switch dockPosition {
        case .right:
            screen.frame.maxX - screen.visibleFrame.maxX
        case .left:
            screen.visibleFrame.minX - screen.frame.minX
        case .bottom:
            screen.visibleFrame.minY - screen.frame.minY
        case .top:
            screen.frame.maxY - screen.visibleFrame.maxY
        case .cmdTab, .cli, .unknown:
            0
        }
    }
}

final class DockAutoHideManager {
    private var wasAutoHideEnabled: Bool?
    private var isManagingDock: Bool = false

    func preventDockHiding(_ windowSwitcherActive: Bool = false) {
        guard Defaults[.preventDockHide], !windowSwitcherActive else { return }
        let currentAutoHideState = CoreDockGetAutoHideEnabled()

        if currentAutoHideState {
            wasAutoHideEnabled = currentAutoHideState
            isManagingDock = true
            CoreDockSetAutoHideEnabled(false)
        }
    }

    func restoreDockState() {
        if isManagingDock, let wasEnabled = wasAutoHideEnabled {
            CoreDockSetAutoHideEnabled(wasEnabled)
            wasAutoHideEnabled = nil
            isManagingDock = false
        }
    }

    func cleanup() {
        restoreDockState()
    }
}
