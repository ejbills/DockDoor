import AppKit

struct WindowActionGroup: Identifiable {
    let id: WindowAction.Group
    let actions: [WindowAction]
}

extension WindowAction {
    enum Group: String, CaseIterable {
        case window
        case arrange
        case app

        var localizedName: String {
            switch self {
            case .window:
                String(localized: "Window", comment: "Window action menu group")
            case .arrange:
                String(localized: "Arrange", comment: "Window action menu group")
            case .app:
                String(localized: "Application", comment: "Window action menu group")
            }
        }

        var actions: [WindowAction] {
            switch self {
            case .window:
                [.openAppWindow, .openNewWindow, .minimize, .hide, .maximize, .toggleFullScreen, .bringToCurrentSpace]
            case .arrange:
                [.fillLeftHalf, .fillRightHalf, .fillTopHalf, .fillBottomHalf,
                 .fillTopLeftQuarter, .fillTopRightQuarter, .fillBottomLeftQuarter, .fillBottomRightQuarter, .center]
            case .app:
                [.close, .quit]
            }
        }
    }

    static func availableGroups(for window: WindowInfo) -> [WindowActionGroup] {
        Group.allCases.compactMap { group in
            let actions = group.actions.filter { $0.isAvailable(for: window) }
            return actions.isEmpty ? nil : WindowActionGroup(id: group, actions: actions)
        }
    }

    func isAvailable(for window: WindowInfo) -> Bool {
        if self == .none { return false }

        if window.isWindowlessApp {
            return self == .openAppWindow || self == .openNewWindow || self == .quit || self == .hide
        }

        switch self {
        case .close:
            return window.closeButton != nil
        case .fillLeftHalf, .fillRightHalf, .fillTopHalf, .fillBottomHalf,
             .fillTopLeftQuarter, .fillTopRightQuarter, .fillBottomLeftQuarter, .fillBottomRightQuarter,
             .center, .maximize, .toggleFullScreen:
            return !window.isMinimized && !window.isHidden
        default:
            return true
        }
    }

    func menuTitle(for window: WindowInfo) -> String {
        switch self {
        case .minimize where window.isMinimized:
            String(localized: "Un-minimize", comment: "Window action for an already minimized window")
        case .hide where window.isHidden:
            String(localized: "Unhide App", comment: "Window action for an already hidden app")
        case .quit where NSEvent.modifierFlags.contains(.option):
            String(localized: "Force Quit App", comment: "Window action when option is held")
        default:
            localizedName
        }
    }

    func menuIcon(for window: WindowInfo) -> String {
        switch self {
        case .minimize where window.isMinimized:
            "arrow.up.left.and.arrow.down.right.square"
        case .hide where window.isHidden:
            "eye"
        default:
            iconName
        }
    }
}
