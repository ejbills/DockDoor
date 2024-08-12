import Cocoa

enum MessageUtil {
    enum ButtonAction {
        case ok
        case cancel
    }

    static func showMessage(title: String, message: String, completion: @escaping (ButtonAction) -> Void) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "OK"))
        alert.addButton(withTitle: String(localized: "Cancel"))

        let modalResult = alert.runModal()
        switch modalResult {
        case .alertFirstButtonReturn: // OK button
            completion(.ok)
        default: // Cancel button or other (e.g., window closed)
            completion(.cancel)
        }
    }
}
