import Cocoa
import Defaults
import Settings
import Sparkle
import SwiftUI

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
    private var appClosureObserver: WindowManipulationObservers?
    private var sharedPreviewWindowCoordinator: SharedPreviewWindowCoordinator?
    private var keybindHelper: KeybindHelper?
    private var statusBarItem: NSStatusItem?

    #if !APPSTORE_BUILD
        private var updaterController: SPUStandardUpdaterController
    #endif

    // settings
    private var firstTimeWindow: NSWindow?
    private lazy var settingsWindowController: SettingsWindowController = {
        var panes: [SettingsPane] = [
            GeneralSettingsViewController(),
            AppearanceSettingsViewController(),
            WindowSwitcherSettingsViewController(),
            PermissionsSettingsViewController(),
        ]

        #if !APPSTORE_BUILD
            panes.append(UpdatesSettingsViewController(updater: updaterController.updater))
        #endif

        return SettingsWindowController(panes: panes)
    }()

    private let settingsWindowControllerDelegate = SettingsWindowControllerDelegate()

    override init() {
        #if !APPSTORE_BUILD
            updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
            updaterController.startUpdater()
        #endif
        super.init()

        if let zoomButton = settingsWindowController.window?.standardWindowButton(.zoomButton) {
            zoomButton.isEnabled = false
        }

        settingsWindowController.window?.delegate = settingsWindowControllerDelegate
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory) // Hide the menubar and dock icons

        if Defaults[.showMenuBarIcon] {
            setupMenuBar()
        } else {
            removeMenuBar()
        }

//        if !Defaults[.launched] {
        handleFirstTimeLaunch()
//        } else {
//            dockObserver = DockObserver.shared
//            appClosureObserver = WindowManipulationObservers.shared
//            sharedPreviewWindowCoordinator = SharedPreviewWindowCoordinator.shared
//            if Defaults[.enableWindowSwitcher] {
//                keybindHelper = KeybindHelper.shared
//            }
//        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettingsWindow(nil)
        return false
    }

    func setupMenuBar() {
        guard statusBarItem == nil else { return }

        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusBarItem?.button else {
            print("Failed to create status bar button")
            return
        }

        if let icon = NSImage(named: .logo) {
            let iconSize = NSStatusBar.system.thickness * 0.9 // Adjust multiplier as needed
            let resizedIcon = icon.resizedToFit(in: NSSize(width: iconSize, height: iconSize))
            resizedIcon.isTemplate = true
            button.image = resizedIcon
        } else {
            print("Failed to load icon")
        }

        button.action = #selector(statusBarButtonClicked(_:))
        button.target = self

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: String(localized: "Open Settings"), action: #selector(openSettingsWindow(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: String(localized: "Quit DockDoor"), action: #selector(quitAppWrapper), keyEquivalent: "q"))
        button.menu = menu
    }

    func removeMenuBar() {
        guard let statusBarItem else { return }
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

    func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    func restartApp() {
        // we use -n to open a new instance, to avoid calling applicationShouldHandleReopen
        // we use Bundle.main.bundlePath in case of multiple DockDoor versions on the machine
        Process.launchedProcess(launchPath: "/usr/bin/open", arguments: ["-n", Bundle.main.bundlePath])
        quitApp()
    }

    private func handleFirstTimeLaunch() {
        guard let screen = NSScreen.main else { return }
        Defaults[.launched] = true

        let newWindow = SwiftUIWindow(
            styleMask: [.titled, .closable, .fullSizeContentView],
            content: {
                FirstTimeView()
            }
        )
        newWindow.isReleasedWhenClosed = false

        let customToolbar = NSToolbar()
        customToolbar.showsBaselineSeparator = false
        newWindow.titlebarAppearsTransparent = true
        newWindow.titleVisibility = .hidden
        newWindow.toolbarStyle = .unified
        newWindow.styleMask.insert(.titled)
        newWindow.toolbar = customToolbar
        newWindow.isOpaque = false

        // Ensure the close button is visible
        newWindow.standardWindowButton(.closeButton)?.isHidden = false
        newWindow.standardWindowButton(.miniaturizeButton)?.isHidden = true
        newWindow.standardWindowButton(.zoomButton)?.isHidden = true

        // Position the window in the center of the main screen
        let screenFrame = screen.visibleFrame
        let windowOrigin = NSPoint(
            x: screenFrame.midX - newWindow.frame.width / 2,
            y: screenFrame.midY - newWindow.frame.height / 2
        )
        newWindow.setFrameOrigin(windowOrigin)

        newWindow.isMovableByWindowBackground = true
        firstTimeWindow = newWindow
        newWindow.show()
        newWindow.makeKeyAndOrderFront(nil)
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window == firstTimeWindow {
            firstTimeWindow = nil
        }
    }
}
