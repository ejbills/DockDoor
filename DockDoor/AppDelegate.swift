//
//  AppDelegate.swift
//  DockDoor
//
//  Created by Ethan Bills on 6/3/24.
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var dockObserver: DockObserver?
    private var keybindHelper: KeybindHelper?
    private var statusBarItem: NSStatusItem?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        self.configureMenuBar()
        dockObserver = DockObserver.shared
        keybindHelper = KeybindHelper.shared
    }

    private func configureMenuBar() {
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: false)
        NSApp.hide(nil)

        let icon = ZStack(alignment: .center) { Image(systemName: "door.right.hand.open") }
        let iconView = NSHostingView(rootView: icon)
        iconView.frame = NSRect(x: 0, y: 0, width: 20, height: 23)

        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusBarItem?.button {
            button.addSubview(iconView)
            button.frame = iconView.frame
            button.action = #selector(openSettingsWindow(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func openSettingsWindow(_ sender: Any?) {
        if settingsWindow == nil {
            // Create the settings window if it does not exist
            let settingsWindow = NSWindow(
                contentRect: NSRect(x: 100, y: 100, width: 400, height: 300),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            settingsWindow.center()
            settingsWindow.title = "DockDoor Settings"
            settingsWindow.isReleasedWhenClosed = false
            settingsWindow.delegate = self
            settingsWindow.contentView = NSHostingView(rootView: SettingsView())
            self.settingsWindow = settingsWindow
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window == settingsWindow {
            settingsWindow = nil
        }
    }
}
