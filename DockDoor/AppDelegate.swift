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

class SettingsWindowControllerDelegate: NSObject, NSWindowDelegate {
    func windowDidBecomeKey(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular) // Show dock icon on open settings window
    }
    
    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // Hide dock icon back
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var dockObserver: DockObserver?
    private var appClosureObserver: AppClosureObserver?
    private var keybindHelper: KeybindHelper?
    private var statusBarItem: NSStatusItem?
    
    private var updaterController: SPUStandardUpdaterController
    
    // settings
    private var firstTimeWindow: NSWindow?
    private lazy var settingsWindowController = SettingsWindowController(
        panes: [
            GeneralSettingsViewController(),
            AppearanceSettingsViewController(),
            WindowSwitcherSettingsViewController(),
            PermissionsSettingsViewController(),
            UpdatesSettingsViewController(updater: updaterController.updater)
        ]
    )
    private let settingsWindowControllerDelegate = SettingsWindowControllerDelegate()
    
    override init() {
        self.updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        self.updaterController.startUpdater()
        super.init()
        
        settingsWindowController.window?.delegate = settingsWindowControllerDelegate
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory) // Hide the menubar and dock icons
        
        if Defaults[.showMenuBarIcon] {
            self.setupMenuBar()
        } else {
            self.removeMenuBar()
        }
        
        if !Defaults[.launched] {
            handleFirstTimeLaunch()
        } else {
            dockObserver = DockObserver.shared
            appClosureObserver = AppClosureObserver.shared
            if Defaults[.enableWindowSwitcher] {
                keybindHelper = KeybindHelper.shared
            }
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        self.openSettingsWindow(nil)
        return false
    }
    
    func setupMenuBar() {
        guard statusBarItem == nil else { return }
        let icon = NSImage(systemSymbolName: "door.right.hand.open", accessibilityDescription: nil)!
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusBarItem?.button {
            button.image = icon
            button.action = #selector(statusBarButtonClicked(_:))
            button.target = self
            
            // Create Menu Items
            let openSettingsMenuItem = NSMenuItem(title: String(localized: "Open Settings"), action: #selector(openSettingsWindow(_:)), keyEquivalent: "")
            openSettingsMenuItem.target = self
            let quitMenuItem = NSMenuItem(title: String(localized: "Quit DockDoor"), action: #selector(quitAppWrapper), keyEquivalent: "q")
            quitMenuItem.target = self
            
            // Create the Menu
            let menu = NSMenu()
            menu.addItem(openSettingsMenuItem)
            menu.addItem(NSMenuItem.separator())
            menu.addItem(quitMenuItem)
            
            button.menu = menu
        }
    }
    
    func removeMenuBar() {
        guard let statusBarItem = statusBarItem else { return }
        NSStatusBar.system.removeStatusItem(statusBarItem)
        self.statusBarItem = nil
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
    
    @objc func openSettingsWindow(_ sender: Any?) {
        settingsWindowController.show()
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    func restartApp() {
        // we use -n to open a new instance, to avoid calling applicationShouldHandleReopen
        // we use Bundle.main.bundlePath in case of multiple DockDoor versions on the machine
        Process.launchedProcess(launchPath: "/usr/bin/open", arguments: ["-n", Bundle.main.bundlePath])
        self.quitApp()
    }
    
    private func handleFirstTimeLaunch() {
        let contentView = FirstTimeView()
        
        // Save that the app has launched
        Defaults[.launched] = true
        
        // Create a hosting controller
        let hostingController = NSHostingController(rootView: contentView)
        
        // Create the settings window
        firstTimeWindow = NSWindow(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 400, height: 400)),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered, defer: false)
        firstTimeWindow?.center()
        firstTimeWindow?.setFrameAutosaveName("DockDoor Permissions")
        firstTimeWindow?.contentView = hostingController.view
        firstTimeWindow?.title = "DockDoor Permissions"
        
        // Make the window key and order it front
        firstTimeWindow?.makeKeyAndOrderFront(nil)
        
        // Calculate the preferred size of the SwiftUI view
        let preferredSize = hostingController.view.fittingSize
        
        // Resize the window to fit the content view
        firstTimeWindow?.setContentSize(preferredSize)
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window == firstTimeWindow {
            firstTimeWindow = nil
        }
    }
}
