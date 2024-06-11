//
//  AppDelegate.swift
//  DockDoor
//
//  Created by Ethan Bills on 6/3/24.
//

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var dockObserver: DockObserver?
    var statusBarItem: NSStatusItem?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.setActivationPolicy(.accessory) // Set activation policy to accessory
        NSApp.activate(ignoringOtherApps: false) // Deactivate to remove icon from Dock
        NSApp.hide(nil) // Hide the app after deactivation (optional)
        
        // Create the menu bar icon
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusBarItem?.button {
            button.title = "⬛"
        }

        dockObserver = DockObserver()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        if let observer = dockObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            print("DockObserver has stopped observing.")
        }
    }
}
