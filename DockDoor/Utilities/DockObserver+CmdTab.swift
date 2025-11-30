import ApplicationServices
import Cocoa
import Defaults

// AXObserver callback for Cmd+Tab switcher changes
func handleCmdTabSwitcherNotification(observer _: AXObserver, element _: AXUIElement, notificationName: CFString, context: UnsafeMutableRawPointer?) {
    DockObserver.activeInstance?.processCmdTabSwitcherEvent(notificationName)
}

extension DockObserver {
    // MARK: - Cmd+Tab Switcher Monitoring

    func teardownCmdTabObserver() {
        if let observer = cmdTabObserver {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        cmdTabObserver = nil
        stopCmdTabPolling()
    }

    // MARK: - On-Demand Polling (Event-Driven)

    func startCmdTabPolling() {
        guard Defaults[.enableCmdTabEnhancements] else { return }
        guard cmdTabObserver == nil else { return }

        attemptCmdTabSubscription()

        if cmdTabObserver == nil {
            cmdTabPollingTimer?.invalidate()
            cmdTabPollingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
                guard let self else {
                    timer.invalidate()
                    return
                }
                attemptCmdTabSubscription()

                if cmdTabObserver != nil {
                    timer.invalidate()
                    cmdTabPollingTimer = nil
                }
            }
        }
    }

    func stopCmdTabPolling() {
        cmdTabPollingTimer?.invalidate()
        cmdTabPollingTimer = nil
    }

    private func attemptCmdTabSubscription() {
        guard let dockApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            return
        }

        let dockAppPID = dockApp.processIdentifier
        let dockAppElement = AXUIElementCreateApplication(dockAppPID)

        guard let children = try? dockAppElement.children(),
              let processSwitcherList = children.first(where: { element in
                  (try? element.subrole()) == "AXProcessSwitcherList"
              })
        else {
            return
        }

        stopCmdTabPolling()
        subscribeToProcessSwitcher(processSwitcherList: processSwitcherList, dockAppPID: dockAppPID)
        processCmdTabSwitcherChanged()
    }

    private func subscribeToProcessSwitcher(processSwitcherList: AXUIElement, dockAppPID: pid_t) {
        if cmdTabObserver != nil {
            teardownCmdTabObserver()
        }

        guard AXObserverCreate(dockAppPID, handleCmdTabSwitcherNotification, &cmdTabObserver) == .success,
              let cmdTabObserver
        else {
            return
        }

        do {
            try processSwitcherList.subscribeToNotification(cmdTabObserver, kAXSelectedChildrenChangedNotification as String) {
                CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(cmdTabObserver), .commonModes)
            }
            try processSwitcherList.subscribeToNotification(cmdTabObserver, kAXUIElementDestroyedNotification as String)
        } catch {
            // Ignore subscription errors
        }
    }

    func processCmdTabSwitcherEvent(_ notification: CFString) {
        guard Defaults[.enableCmdTabEnhancements] else { return }

        let notif = notification as String

        if notif == (kAXSelectedChildrenChangedNotification as String) {
            processCmdTabSwitcherChanged()
            return
        }

        if notif == (kAXUIElementDestroyedNotification as String) {
            teardownCmdTabObserver()
            return
        }
    }

    func processCmdTabSwitcherChanged() {
        guard Defaults[.enableCmdTabEnhancements] else { return }
        guard let dockApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            return
        }

        let dockAppElement = AXUIElementCreateApplication(dockApp.processIdentifier)

        guard let selectedItem = getSelectedCmdTabItem(dockElement: dockAppElement) else {
            _ = findCmdTabSwitcherElement(in: dockAppElement)
            return
        }

        let resolvedApp = selectedItem.app
        let appName = resolvedApp?.localizedName ?? selectedItem.title ?? "Unknown"
        let bundleId = resolvedApp?.bundleIdentifier ?? selectedItem.bundleId

        Task { @MainActor [weak self] in
            guard let self else { return }

            previewCoordinator.windowSwitcherCoordinator.setIndex(to: -1, shouldScroll: false)

            do {
                var windows: [WindowInfo] = []
                if let app = resolvedApp {
                    windows = try await WindowUtil.getActiveWindows(of: app, context: .cmdTab)

                    // Filter by current space if enabled
                    if Defaults[.showWindowsFromCurrentSpaceOnlyInCmdTab] {
                        windows = await WindowUtil.filterWindowsByCurrentSpace(windows)
                    }
                }

                let elementPos = try? selectedItem.element.position()
                let bestScreen = elementPos?.screen() ?? NSScreen.main!

                previewCoordinator.showWindow(
                    appName: appName,
                    windows: windows,
                    mouseLocation: DockObserver.getMousePosition(),
                    mouseScreen: bestScreen,
                    dockItemElement: selectedItem.element,
                    overrideDelay: true,
                    centeredHoverWindowState: .none,
                    onWindowTap: { [weak self] in
                        self?.hideWindowAndResetLastApp()
                    },
                    bundleIdentifier: bundleId,
                    bypassDockMouseValidation: true,
                    dockPositionOverride: .cmdTab
                )
            } catch {
                let elementPos = try? selectedItem.element.position()
                let bestScreen = elementPos?.screen() ?? NSScreen.main!
                previewCoordinator.showWindow(
                    appName: appName,
                    windows: [],
                    mouseLocation: DockObserver.getMousePosition(),
                    mouseScreen: bestScreen,
                    dockItemElement: selectedItem.element,
                    overrideDelay: true,
                    centeredHoverWindowState: .none,
                    onWindowTap: { [weak self] in
                        self?.hideWindowAndResetLastApp()
                    },
                    bundleIdentifier: bundleId,
                    bypassDockMouseValidation: true,
                    dockPositionOverride: .cmdTab
                )
            }
        }
    }

    // MARK: - Public helper: is Cmd+Tab switcher active now?

    static func isCmdTabSwitcherActive() -> Bool {
        guard AXIsProcessTrusted() else { return false }
        guard let dockApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            return false
        }
        let root = AXUIElementCreateApplication(dockApp.processIdentifier)

        func scan(_ element: AXUIElement) -> Bool {
            if (try? element.subrole()) == "AXProcessSwitcherList" {
                return true
            }
            if let children = try? element.children() {
                for child in children {
                    if scan(child) { return true }
                }
            }
            return false
        }
        return scan(root)
    }

    private func getSelectedCmdTabItem(dockElement: AXUIElement) -> (element: AXUIElement, app: NSRunningApplication?, bundleId: String?, title: String?)? {
        guard let appSwitcherElement = findCmdTabSwitcherElement(in: dockElement) else {
            return nil
        }

        var selectedChildren: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appSwitcherElement, kAXSelectedChildrenAttribute as CFString, &selectedChildren)

        if result == .success,
           let selectedArray = selectedChildren as? [AXUIElement],
           let selectedElement = selectedArray.first
        {
            var resolvedApp: NSRunningApplication?
            var resolvedBundleId: String?
            var resolvedTitle: String?

            if let appURL = try? selectedElement.attribute(kAXURLAttribute as String, NSURL.self)?.absoluteURL,
               let bundle = Bundle(url: appURL),
               let bundleIdentifier = bundle.bundleIdentifier
            {
                resolvedBundleId = bundleIdentifier
                resolvedApp = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first
            }

            if resolvedApp == nil {
                do {
                    if let title = try selectedElement.title(), !title.isEmpty {
                        resolvedTitle = title
                        let allApps = NSWorkspace.shared.runningApplications
                        if let app = allApps.first(where: { $0.localizedName == title }) {
                            resolvedApp = app
                        } else {
                            let lowerTitle = title.lowercased()
                            if let app = allApps.first(where: { ($0.localizedName ?? "").lowercased().contains(lowerTitle) || lowerTitle.contains(($0.localizedName ?? "").lowercased()) }) {
                                resolvedApp = app
                            }
                        }
                        if resolvedBundleId == nil { resolvedBundleId = resolvedApp?.bundleIdentifier }
                    }
                } catch {
                    // ignore
                }
            }

            return (element: selectedElement, app: resolvedApp, bundleId: resolvedBundleId, title: resolvedTitle)
        }

        return nil
    }

    private func findCmdTabSwitcherElement(in dockElement: AXUIElement) -> AXUIElement? {
        do {
            let children = try dockElement.children() ?? []

            for child in children {
                let subrole = try? child.subrole()
                if let subrole, subrole == "AXProcessSwitcherList" {
                    return child
                }

                if let found = findCmdTabSwitcherElement(in: child) {
                    return found
                }
            }
        } catch {
            // Element might not be accessible
        }

        return nil
    }
}
