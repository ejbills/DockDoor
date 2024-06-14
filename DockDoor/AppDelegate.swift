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

        // Create Menu Items
        let openSettingsMenuItem = NSMenuItem(title: "Open Settings", action: #selector(openSettingsWindow(_:)), keyEquivalent: "")
        openSettingsMenuItem.target = self
        let quitMenuItem = NSMenuItem(title: "Quit DockDoor", action: #selector(quitAppWrapper), keyEquivalent: "q")
        quitMenuItem.target = self

        // Create the Menu
        let menu = NSMenu()
        menu.addItem(openSettingsMenuItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(quitMenuItem)

        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusBarItem?.button {
            button.addSubview(iconView)
            button.frame = iconView.frame
            button.action = #selector(statusBarButtonClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp])

            button.menu = menu
        }
    }

    // Add new function to handle button clicks
    @objc func statusBarButtonClicked(_ sender: Any?) {
        // Show the menu
        if let button = statusBarItem?.button {
            button.menu?.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.maxY), in: button)
        }
    }
    
    @objc private func quitAppWrapper() {
        quitApp()
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
    
    @objc func quitApp() { // Now an instance method
        NSApplication.shared.terminate(nil)
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window == settingsWindow {
            settingsWindow = nil
        }
    }
}
