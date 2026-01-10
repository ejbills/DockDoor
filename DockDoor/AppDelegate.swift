import ApplicationServices
import Cocoa
import Defaults
import Sparkle
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var dockObserver: DockObserver?
    private var appClosureObserver: WindowManipulationObservers?
    private var windowSeeder: WindowSeeder?
    private var previewCoordinator: SharedPreviewWindowCoordinator?
    private var keybindHelper: KeybindHelper?
    private var activeAppIndicator: ActiveAppIndicatorCoordinator?
    private var statusBarItem: NSStatusItem?
    private var updaterController: SPUStandardUpdaterController
    @ObservedObject var updaterState: UpdaterState

    var updater: SPUUpdater {
        updaterController.updater
    }

    private var cinematicOverlay: CinematicOverlay?
    private var onboardingWindow: NSWindow?
    private var settingsManager: SettingsManager?

    override init() {
        let state = UpdaterState()
        updaterState = state

        let anUpdaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: state, userDriverDelegate: nil)
        updaterController = anUpdaterController

        state.updater = anUpdaterController.updater

        super.init()

        settingsManager = SettingsManager(updaterState: state)
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Set global AX timeout to prevent hangs from unresponsive apps
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 1.0)

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

            let needsDockObserver = Defaults[.enableDockPreviews] ||
                Defaults[.shouldHideOnDockItemClick] ||
                Defaults[.enableCmdRightClickQuit] ||
                Defaults[.enableDockScrollGesture]

            if needsDockObserver {
                let dockObs = DockObserver(previewCoordinator: currentPreviewCoordinator)
                dockObserver = dockObs
            }

            appClosureObserver = WindowManipulationObservers(previewCoordinator: currentPreviewCoordinator)

            if Defaults[.enableWindowSwitcher] || Defaults[.enableCmdTabEnhancements] {
                keybindHelper = KeybindHelper(previewCoordinator: currentPreviewCoordinator)
            }

            if Defaults[.showActiveAppIndicator] {
                activeAppIndicator = ActiveAppIndicatorCoordinator()
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

        // Cold-start: seed all windows (including minimized and other Spaces) and start live AX tracker
        let seeder = WindowSeeder()
        seeder.run()
        windowSeeder = seeder
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettingsWindow(nil)
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        WindowUtil.saveWindowOrderFromCache()
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
        menu.addItem(NSMenuItem(title: String(localized: "Restart DockDoor"), action: #selector(restartAppWrapper), keyEquivalent: ""))
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

    @objc private func restartAppWrapper() {
        restartApp()
    }

    @objc func openSettingsWindow(_ sender: Any?) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        settingsManager?.showSettings()
    }

    func closeSettingsWindow() {
        settingsManager?.close()
    }

    func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    func restartApp() {
        Process.launchedProcess(launchPath: "/usr/bin/open", arguments: ["-n", Bundle.main.bundlePath])
        quitApp()
    }

    private func handleFirstTimeLaunch() {
        let currentMouseLocation = CGEvent(source: nil)?.location ?? .zero
        let screen = NSScreen.screenContainingMouse(currentMouseLocation)

        Defaults[.launched] = true

        if !Defaults[.showAnimations] || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            showOnboardingWindow(on: screen)
            return
        }

        let overlay = CinematicOverlay(screen: screen) { [weak self] in
            self?.cinematicOverlay = nil
            self?.showOnboardingWindow(on: screen)
        }
        cinematicOverlay = overlay
        overlay.orderFront(nil)
        overlay.fadeIn()
    }

    private func showOnboardingWindow(on screen: NSScreen) {
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

        newWindow.level = .floating

        let screenFrame = screen.visibleFrame
        let windowOrigin = NSPoint(
            x: screenFrame.midX - newWindow.frame.width / 2,
            y: screenFrame.midY - newWindow.frame.height / 2
        )

        newWindow.setFrameOrigin(windowOrigin)
        newWindow.isMovableByWindowBackground = true
        onboardingWindow = newWindow

        newWindow.alphaValue = 0
        newWindow.show()
        newWindow.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            newWindow.animator().alphaValue = 1
        }
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window == onboardingWindow {
            onboardingWindow = nil
        }
    }
}
