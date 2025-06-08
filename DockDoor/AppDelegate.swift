import Cocoa
import Defaults
import Settings
import Sparkle
import SwiftUI

class SettingsWindowControllerDelegate: NSObject, NSWindowDelegate {
    func windowDidBecomeKey(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var dockObserver: DockObserver?
    private var appClosureObserver: WindowManipulationObservers?
    private var previewCoordinator: SharedPreviewWindowCoordinator?
    private var keybindHelper: KeybindHelper?
    private var statusBarItem: NSStatusItem?
    private var updaterController: SPUStandardUpdaterController
    @ObservedObject public var updaterState: UpdaterState

    public var updater: SPUUpdater {
        updaterController.updater
    }

    private var firstTimeWindow: NSWindow?
    lazy var settingsWindowController: SettingsWindowController = {
        var panes: [SettingsPane] = [
            GeneralSettingsViewController(),
            AppearanceSettingsViewController(),
            FiltersSettingsViewController(),
            SupportSettingsViewController(updaterState: updaterState),
        ]

        let controller = SettingsWindowController(panes: panes)
        controller.window?.delegate = self.settingsWindowControllerDelegate

        if let window = controller.window {
            window.styleMask.insert(.resizable)

            if let zoomButton = window.standardWindowButton(.zoomButton) {
                zoomButton.isEnabled = true
            }
        }

        return controller
    }()

    private let settingsWindowControllerDelegate = SettingsWindowControllerDelegate()

    override init() {
        let state = UpdaterState()
        updaterState = state

        let anUpdaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: state, userDriverDelegate: nil)
        updaterController = anUpdaterController

        state.updater = anUpdaterController.updater

        super.init()

        settingsWindowController.window?.delegate = settingsWindowControllerDelegate
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if Defaults[.showMenuBarIcon] {
            setupMenuBar()
        } else {
            removeMenuBar()
        }

        if !Defaults[.launched] {
            handleFirstTimeLaunch()
        } else {
            let currentPreviewCoordinator = SharedPreviewWindowCoordinator()
            previewCoordinator = currentPreviewCoordinator

            let currentDockObserver = DockObserver(previewCoordinator: currentPreviewCoordinator)
            dockObserver = currentDockObserver

            appClosureObserver = WindowManipulationObservers(previewCoordinator: currentPreviewCoordinator)

            if Defaults[.enableWindowSwitcher] {
                keybindHelper = KeybindHelper(previewCoordinator: currentPreviewCoordinator, dockObserver: currentDockObserver)
            }
            if updater.automaticallyChecksForUpdates {
                print("AppDelegate: Automatic updates enabled, checking in background.")
                updater.checkForUpdatesInBackground()
            }
        }

        Task(priority: .high) { [weak self] in
            guard self != nil else { return }

            await WindowUtil.updateAllWindowsInCurrentSpace()
        }
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
            let iconSize = NSStatusBar.system.thickness * 0.9
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

        newWindow.standardWindowButton(.closeButton)?.isHidden = false
        newWindow.standardWindowButton(.miniaturizeButton)?.isHidden = true
        newWindow.standardWindowButton(.zoomButton)?.isHidden = true

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
