//
//  MessageUtil.swift
//  DockDoor
//
//  Created by Ethan Bills on 6/3/24.
//

import Cocoa

struct MessageUtil {
    
    enum ButtonAction {
        case ok
        case cancel
    }

    static func showMessage(title: String, message: String, completion: @escaping (ButtonAction) -> Void) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning // You can change the style as needed
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        let modalResult = alert.runModal()
        switch modalResult {
        case .alertFirstButtonReturn: // OK button
            completion(.ok)
        default: // Cancel button or other (e.g., window closed)
            completion(.cancel)
        }
    }
}
