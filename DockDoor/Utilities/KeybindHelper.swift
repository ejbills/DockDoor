//
//  KeybindHelper.swift
//  DockDoor
//
//  Created by Ethan Bills on 6/13/24.
//

import AppKit

class KeybindHelper {
    static let shared = KeybindHelper()
    
    private var isControlKeyPressed = false
    private var globalMonitors: [Any?] = []
    
    private init() {
        globalMonitors.append(
            NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown, .keyUp], handler: handleGlobalEvent)
        )
    }
    
    deinit {
        KeybindHelper.shared.removeEventMonitors()
    }
    
    // Handle global key events
    private func handleGlobalEvent(event: NSEvent) {
        switch event.type {
        case .flagsChanged:
            let optionKeyCurrentlyPressed = event.modifierFlags.contains(.control)
            if optionKeyCurrentlyPressed != isControlKeyPressed {
                isControlKeyPressed = optionKeyCurrentlyPressed
                if isControlKeyPressed {
                    // Show hover window
                    showHoverWindow()
                } else {
                    // Option key released, bring current window to front
                    HoverWindow.shared.selectAndBringToFrontCurrentWindow()
                    HoverWindow.shared.hideWindow()
                }
            }
        case .keyDown:
            if isControlKeyPressed && event.keyCode == 48 { // '48' is the keyCode for Tab
                // Cycle through windows
                HoverWindow.shared.cycleWindows()
            }
        default:
            break
        }
    }
    
    private func showHoverWindow() {
        Task {
            let windows = await WindowUtil.activeWindows(for: "")
            DispatchQueue.main.async {
                HoverWindow.shared.showWindow(appName: "Alt-Tab", windows: windows, mouseLocation: .zero, onWindowTap: nil)
            }
        }
    }
    
    func removeEventMonitors() {
        for monitor in globalMonitors {
            if let monitor = monitor as? NSObject {
                NSEvent.removeMonitor(monitor)
            }
        }
        globalMonitors.removeAll()
    }
}
