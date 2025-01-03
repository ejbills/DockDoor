import Cocoa

enum MessageUtil {
    enum ButtonAction {
        case ok
        case cancel
    }

    static func showAlert(title: String, message: String, actions: [ButtonAction], completion: ((ButtonAction) -> Void)? = nil) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning

        for action in actions {
            switch action {
            case .ok:
                alert.addButton(withTitle: String(localized: "OK"))
            case .cancel:
                alert.addButton(withTitle: String(localized: "Cancel"))
            }
        }

        let modalResult = alert.runModal()
        let buttonAction: ButtonAction = switch modalResult {
        case .alertFirstButtonReturn:
            actions[0]
        case .alertSecondButtonReturn:
            actions[1]
        default:
            actions.last ?? .cancel
        }

        if buttonAction != .cancel {
            completion?(buttonAction)
        }
    }
}
