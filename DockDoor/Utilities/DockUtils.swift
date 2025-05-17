import Cocoa
import Defaults

enum DockPosition {
    case top
    case bottom
    case left
    case right
    case unknown

    var isHorizontalFlow: Bool {
        switch self {
        case .top, .bottom:
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
