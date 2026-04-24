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
    private var dockLocker: DockLocker?
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
        applyAppearanceMode(Defaults[.appAppearanceMode])

        // Set global AX timeout to prevent hangs from unresponsive apps
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 1.0)

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSystemWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        if Defaults[.showMenuBarIcon] {
            setupMenuBar()
        } else {
            removeMenuBar()
        }

        MediaRemoteService.shared.activate()

        if !Defaults[.launched] {
            handleFirstTimeLaunch()
        } else {
            let currentPreviewCoordinator = SharedPreviewWindowCoordinator()
            previewCoordinator = currentPreviewCoordinator

            let dockObs = DockObserver(previewCoordinator: currentPreviewCoordinator)
            dockObserver = dockObs

            appClosureObserver = WindowManipulationObservers(previewCoordinator: currentPreviewCoordinator)

            if Defaults[.enableWindowSwitcher] || Defaults[.enableCmdTabEnhancements] {
                keybindHelper = KeybindHelper(previewCoordinator: currentPreviewCoordinator)
            }

            if Defaults[.showActiveAppIndicator] {
                activeAppIndicator = ActiveAppIndicatorCoordinator()
            }

            if Defaults[.enableDockLocking] {
                dockLocker = DockLocker()
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

        if Defaults[.reopenSettingsAfterRestart] {
            Defaults[.reopenSettingsAfterRestart] = false
            openSettingsWindow(nil)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettingsWindow(nil)
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        wakeRecoveryTask?.cancel()
        WindowUtil.saveWindowOrderFromCache()
        URLCache.shared.removeAllCachedResponses()
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
        menu.addItem(NSMenuItem(title: String(localized: "Check for Updates…"), action: #selector(checkForUpdatesWrapper), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: String(localized: "Support DockDoor"), action: #selector(openDonationPage), keyEquivalent: ""))
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

    @objc private func checkForUpdatesWrapper() {
        updater.checkForUpdates()
    }

    @objc private func openDonationPage() {
        if let url = URL(string: "https://dockdoor.net/donate") {
            NSWorkspace.shared.open(url)
        }
    }

    private var wakeRecoveryTask: Task<Void, Never>?

    @objc private func handleSystemWake() {
        wakeRecoveryTask?.cancel()

        wakeRecoveryTask = Task {
            var delay: UInt64 = 1_000_000_000 // 1s
            var totalWaited: UInt64 = 0
            let maxWait: UInt64 = 15_000_000_000 // 15s

            while !Task.isCancelled, totalWaited < maxWait {
                try? await Task.sleep(nanoseconds: delay)
                guard !Task.isCancelled else { return }
                totalWaited += delay

                if isAccessibilityReady() {
                    DebugLogger.log("Wake recovery", details: "AX canary passed after \(totalWaited / 1_000_000)ms")
                    break
                }

                DebugLogger.log("Wake recovery", details: "AX canary failed after \(totalWaited / 1_000_000)ms, backing off")
                delay = min(delay * 2, maxWait - totalWaited)
            }

            guard !Task.isCancelled else { return }

            await MainActor.run { [weak self] in
                guard let self else { return }
                if Defaults[.activateOnWake] {
                    NSApp.activate(ignoringOtherApps: true)
                }
                dockObserver?.reset()
                keybindHelper?.reset()
                appClosureObserver?.reset()
                dockLocker?.reset()
            }
        }
    }

    @objc func openSettingsWindow(_ sender: Any?) {
        if NSApp.mainMenu == nil {
            NSApp.mainMenu = MainMenuBuilder.buildSettingsMenu()
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        settingsManager?.showSettings()
    }

    @objc func handleSettingsTabMenu(_ sender: NSMenuItem) {
        guard let tab = sender.representedObject as? String else { return }
        settingsManager?.showSettings()
        NotificationCenter.default.post(
            name: .dockDoorSelectSettingsTab,
            object: nil,
            userInfo: ["tab": tab]
        )
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
        let screen = NSScreen.screenFromQuartzPoint(currentMouseLocation)

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

extension Notification.Name {
    static let dockDoorSelectSettingsTab = Notification.Name("DockDoor.SelectSettingsTab")
}

enum MainMenuBuilder {
    static func buildSettingsMenu() -> NSMenu {
        let mainMenu = NSMenu()

        mainMenu.addItem(buildAppMenuItem())
        mainMenu.addItem(buildEditMenuItem())
        mainMenu.addItem(buildSettingsNavMenuItem())
        mainMenu.addItem(buildWindowMenuItem())
        mainMenu.addItem(buildHelpMenuItem())

        return mainMenu
    }

    private static func buildAppMenuItem() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu()

        menu.addItem(withTitle: String(localized: "About DockDoor", comment: "Main menu item"),
                     action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                     keyEquivalent: "")
        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: String(localized: "Settings…", comment: "Main menu item"),
            action: #selector(AppDelegate.openSettingsWindow(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = NSApp.delegate
        menu.addItem(settingsItem)
        menu.addItem(.separator())

        let servicesItem = NSMenuItem(
            title: String(localized: "Services", comment: "Main menu item"),
            action: nil, keyEquivalent: ""
        )
        let servicesMenu = NSMenu()
        servicesItem.submenu = servicesMenu
        NSApp.servicesMenu = servicesMenu
        menu.addItem(servicesItem)
        menu.addItem(.separator())

        menu.addItem(withTitle: String(localized: "Hide DockDoor", comment: "Main menu item"),
                     action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = NSMenuItem(
            title: String(localized: "Hide Others", comment: "Main menu item"),
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h"
        )
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(hideOthers)
        menu.addItem(withTitle: String(localized: "Show All", comment: "Main menu item"),
                     action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: String(localized: "Quit DockDoor", comment: "Main menu item"),
                     action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        item.submenu = menu
        return item
    }

    private static func buildEditMenuItem() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: String(localized: "Edit", comment: "Main menu title"))

        menu.addItem(withTitle: String(localized: "Undo", comment: "Main menu item"),
                     action: Selector(("undo:")), keyEquivalent: "z")
        let redo = NSMenuItem(title: String(localized: "Redo", comment: "Main menu item"),
                              action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(redo)
        menu.addItem(.separator())
        menu.addItem(withTitle: String(localized: "Cut", comment: "Main menu item"),
                     action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        menu.addItem(withTitle: String(localized: "Copy", comment: "Main menu item"),
                     action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        menu.addItem(withTitle: String(localized: "Paste", comment: "Main menu item"),
                     action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        menu.addItem(withTitle: String(localized: "Delete", comment: "Main menu item"),
                     action: #selector(NSText.delete(_:)), keyEquivalent: "")
        menu.addItem(withTitle: String(localized: "Select All", comment: "Main menu item"),
                     action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        item.submenu = menu
        return item
    }

    private static func buildSettingsNavMenuItem() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: String(localized: "Go", comment: "Main menu title"))

        menu.addItem(tabItem(title: String(localized: "General", comment: "Settings tab title"),
                             tab: "General", keyEquivalent: "1"))
        menu.addItem(.separator())

        menu.addItem(sectionHeader(String(localized: "Features", comment: "Settings section header")))
        menu.addItem(tabItem(title: String(localized: "Dock Previews", comment: "Settings tab title"),
                             tab: "DockPreviews", keyEquivalent: "2"))
        menu.addItem(tabItem(title: String(localized: "Window Switcher", comment: "Settings tab title"),
                             tab: "WindowSwitcher", keyEquivalent: "3"))
        menu.addItem(tabItem(title: String(localized: "Cmd+Tab", comment: "Settings tab title"),
                             tab: "CmdTab", keyEquivalent: "4"))
        menu.addItem(tabItem(title: String(localized: "Dock Locking", comment: "Settings tab title"),
                             tab: "DockLocking", keyEquivalent: "5"))
        menu.addItem(.separator())

        menu.addItem(sectionHeader(String(localized: "Customization", comment: "Settings section header")))
        menu.addItem(tabItem(title: String(localized: "Appearance", comment: "Settings Tab"),
                             tab: "Appearance", keyEquivalent: "6"))
        menu.addItem(tabItem(title: String(localized: "Gestures & Keybinds", comment: "Settings tab title"),
                             tab: "GesturesKeybinds", keyEquivalent: "7"))
        menu.addItem(tabItem(title: String(localized: "Filters", comment: "Filters tab title"),
                             tab: "Filters", keyEquivalent: "8"))
        menu.addItem(tabItem(title: String(localized: "Widgets", comment: "Widget settings tab title"),
                             tab: "Widgets", keyEquivalent: "9"))
        menu.addItem(.separator())

        menu.addItem(sectionHeader(String(localized: "System", comment: "Settings section header")))
        menu.addItem(tabItem(title: String(localized: "Advanced", comment: "Settings tab title"),
                             tab: "Advanced", keyEquivalent: "0"))
        menu.addItem(tabItem(title: String(localized: "Support", comment: "Settings tab title"),
                             tab: "Support", keyEquivalent: ""))

        item.submenu = menu
        return item
    }

    private static func buildWindowMenuItem() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: String(localized: "Window", comment: "Main menu title"))

        menu.addItem(withTitle: String(localized: "Minimize", comment: "Main menu item"),
                     action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        menu.addItem(withTitle: String(localized: "Zoom", comment: "Main menu item"),
                     action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: String(localized: "Bring All to Front", comment: "Main menu item"),
                     action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")

        NSApp.windowsMenu = menu
        item.submenu = menu
        return item
    }

    private static func buildHelpMenuItem() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: String(localized: "Help", comment: "Main menu title"))

        let support = NSMenuItem(
            title: String(localized: "DockDoor Help", comment: "Main menu item"),
            action: #selector(AppDelegate.handleSettingsTabMenu(_:)),
            keyEquivalent: "?"
        )
        support.representedObject = "Support"
        support.target = NSApp.delegate
        menu.addItem(support)

        NSApp.helpMenu = menu
        item.submenu = menu
        return item
    }

    private static func tabItem(title: String, tab: String, keyEquivalent: String) -> NSMenuItem {
        let item = NSMenuItem(
            title: title,
            action: #selector(AppDelegate.handleSettingsTabMenu(_:)),
            keyEquivalent: keyEquivalent
        )
        item.representedObject = tab
        item.target = NSApp.delegate
        return item
    }

    private static func sectionHeader(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }
}
