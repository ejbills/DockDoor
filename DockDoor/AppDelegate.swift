//
//  AppDelegate.swift
//  DockDoor
//
//  Created by Ethan Bills on 6/3/24.
//

import Cocoa
import SwiftUI
import Defaults
import Settings
import Sparkle

class AppDelegate: NSObject, NSApplicationDelegate {
    private var dockObserver: DockObserver?
    private var keybindHelper: KeybindHelper?
    private var statusBarItem: NSStatusItem?
    
    private var updaterController: SPUStandardUpdaterController
    
    // settings
    private var settingsWindow: NSWindow?
    private lazy var settingsWindowController = SettingsWindowController(
        panes: [
            GeneralSettingsViewController(),
            WindowSwitcherSettingsViewController(),
            PermissionsSettingsViewController(),
            UpdatesSettingsViewController(updater: updaterController.updater)
        ]
    )
    
    override init() {
        self.updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        self.updaterController.startUpdater()
        super.init()
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if !Defaults[.launched] {
            handleFirstTimeLaunch()
        } else {
            self.configureMenuBar()
            dockObserver = DockObserver.shared
            if Defaults[.showWindowSwitcher] {
                keybindHelper = KeybindHelper.shared
            }
        }
    }
    
    private func configureMenuBar() {
        // Show the menu bar icon initially
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: false)
        NSApp.hide(nil)
        
        let icon = NSImage(systemSymbolName: "door.right.hand.open", accessibilityDescription: nil)!
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusBarItem?.button {
            button.image = icon
            button.action = #selector(statusBarButtonClicked(_:))
            button.target = self
            
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
            
            button.menu = menu
        }
        
        // Schedule a timer to remove the menu bar icon after 10 seconds if it's turned off
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            self.removeMenuBarIconIfNeeded()
        }
    }
    
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
        settingsWindowController.show()
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    private func handleFirstTimeLaunch() {
        let contentView = FirstTimeView()
        
        // Save that the app has launched
        Defaults[.launched] = true
        
        // Create a hosting controller
        let hostingController = NSHostingController(rootView: contentView)
        
        // Create the settings window
        settingsWindow = NSWindow(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 400, height: 400)),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered, defer: false)
        settingsWindow?.center()
        settingsWindow?.setFrameAutosaveName("DockDoor Permissions")
        settingsWindow?.contentView = hostingController.view
        settingsWindow?.title = "DockDoor Permissions"
        
        // Make the window key and order it front
        settingsWindow?.makeKeyAndOrderFront(nil)
        
        // Calculate the preferred size of the SwiftUI view
        let preferredSize = hostingController.view.fittingSize
        
        // Resize the window to fit the content view
        settingsWindow?.setContentSize(preferredSize)
    }
    
    private func removeMenuBarIconIfNeeded() {
        if !Defaults[.showMenuBarIcon], let statusBarItem = statusBarItem {
            NSStatusBar.system.removeStatusItem(statusBarItem)
            self.statusBarItem = nil
        }
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window == settingsWindow {
            settingsWindow = nil
        }
    }
}
