import ApplicationServices
import Cocoa
import Defaults
import os.log

// MARK: - Threading Model & Memory Management
//
// This file implements AXObserver lifecycle management for monitoring the Cmd+Tab switcher.
// Critical implementation notes to prevent zombie observers and memory leaks:
//
// 1. CFRunLoop Thread Consistency:
//    - All AXObserver operations (create, add source, remove source) MUST use CFRunLoopGetMain()
//    - Using CFRunLoopGetCurrent() can cause thread mismatches if teardown happens on a different thread
//    - Example: Observer created on thread A, teardown called from thread B → source removal fails → MEMORY LEAK
//
// 2. Observer Retention:
//    - cmdTabObserver MUST be stored as an instance variable (DockObserver.cmdTabObserver)
//    - Using local variables causes immediate deallocation after scope exit → callbacks never fire → ZOMBIE STATE
//    - The observer is properly retained throughout the subscription lifecycle
//
// 3. Retry Logic Threading:
//    - Uses DispatchQueue.main.asyncAfter instead of Task/async to avoid CFRunLoop conflicts
//    - Exponential backoff with random jitter (0-100ms) prevents thundering herd on retry storms
//    - All retry operations stay on main thread for CFRunLoop consistency
//
// 4. Thread-Safe Property Access:
//    - lastCmdTabNotificationTime and cmdTabObserverCreationTime use DispatchQueue for synchronized access
//    - Properties accessed from multiple contexts: AX callbacks, timers, async tasks, deinit

// AXObserver callback for Cmd+Tab switcher changes
func handleCmdTabSwitcherNotification(observer _: AXObserver, element _: AXUIElement, notificationName: CFString, context: UnsafeMutableRawPointer?) {
    DockObserver.activeInstance?.processCmdTabSwitcherEvent(notificationName)
}

extension DockObserver {
    // MARK: - Cmd+Tab Switcher Monitoring
    
    private static let logger = Logger(subsystem: "com.dockdoor.app", category: "CmdTabObserver")
    
    enum CmdTabObserverError: Error {
        case dockAppNotFound
        case accessibilityNotGranted
        case observerCreationFailed
        case subscriptionFailed(String)
    }
    
    private enum CmdTabConstants {
        static let maxObserverRetries = 3
        static let retryBaseDelay: TimeInterval = 0.1
        static let resubscribeInterval: TimeInterval = 0.5
    }

    func setupCmdTabSwitcherObserver() {
        guard Defaults[.enableCmdTabEnhancements] else { return }
        // Ensure a clean state before subscribing (switcher element is ephemeral)
        teardownCmdTabObserver()

        guard let dockApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            Self.logger.warning("Cannot find Dock app for Cmd+Tab observer setup")
            return
        }

        let dockAppPID = dockApp.processIdentifier
        let dockAppElement = AXUIElementCreateApplication(dockAppPID)

        guard AXIsProcessTrusted() else {
            Self.logger.warning("Accessibility permissions not granted for Cmd+Tab observer")
            return
        }

        // Find the process switcher list
        guard let children = try? dockAppElement.children(),
              let processSwitcherList = children.first(where: { element in
                  (try? element.subrole()) == "AXProcessSwitcherList"
              })
        else {
            scheduleCmdTabResubscribe(dockAppPID: dockAppPID)
            return
        }

        subscribeToProcessSwitcher(processSwitcherList: processSwitcherList, dockAppPID: dockAppPID)
        processCmdTabSwitcherChanged()
    }
    
    func teardownCmdTabObserver() {
        if let observer = cmdTabObserver {
            // Always use main RunLoop for consistency - AXObserver callbacks and setup happen on main thread
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
            Self.logger.debug("Tore down Cmd+Tab observer")
        }
        cmdTabObserver = nil
        cmdTabObserverCreationTime = nil
        lastCmdTabNotificationTime = nil
        cmdTabRetryTimer?.invalidate()
        cmdTabRetryTimer = nil
    }

    private func scheduleCmdTabResubscribe(dockAppPID: pid_t) {
        cmdTabRetryTimer?.invalidate()
        cmdTabRetryTimer = Timer.scheduledTimer(withTimeInterval: CmdTabConstants.resubscribeInterval, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }

            let dockAppElement = AXUIElementCreateApplication(dockAppPID)
            guard let children = try? dockAppElement.children(),
                  let processSwitcherList = children.first(where: { element in
                      (try? element.subrole()) == "AXProcessSwitcherList"
                  })
            else {
                return
            }

            timer.invalidate()
            cmdTabRetryTimer = nil
            subscribeToProcessSwitcher(processSwitcherList: processSwitcherList, dockAppPID: dockAppPID)
            // Emit initial selection after resubscribe
            processCmdTabSwitcherChanged()
        }
    }

    private func subscribeToProcessSwitcher(processSwitcherList: AXUIElement, dockAppPID: pid_t) {
        subscribeWithRetry(processSwitcherList: processSwitcherList, dockAppPID: dockAppPID, attempt: 0)
    }
    
    private func subscribeWithRetry(processSwitcherList: AXUIElement, dockAppPID: pid_t, attempt: Int) {
        let result = AXObserverCreate(dockAppPID, handleCmdTabSwitcherNotification, &cmdTabObserver)
        
        if result == .success {
            completeSubscription(processSwitcherList: processSwitcherList)
            return
        }
        
        // Log failure with AXError code
        Self.logger.error("AXObserverCreate failed: code \(result.rawValue, privacy: .public), attempt \(attempt + 1, privacy: .public)/\(CmdTabConstants.maxObserverRetries, privacy: .public)")
        
        guard attempt < CmdTabConstants.maxObserverRetries - 1 else {
            Self.logger.error("AXObserverCreate failed after \(CmdTabConstants.maxObserverRetries, privacy: .public) attempts, giving up")
            return
        }
        
        let delay = calculateBackoffDelay(attempt: attempt)
        Self.logger.warning("Retrying AXObserverCreate in \(String(format: "%.3f", delay), privacy: .public)s")
        
        // Use DispatchQueue for retry scheduling instead of async/await to avoid CFRunLoop conflicts
        // Retries happen on main queue to ensure all CFRunLoop operations are on the same thread
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.subscribeWithRetry(processSwitcherList: processSwitcherList, dockAppPID: dockAppPID, attempt: attempt + 1)
        }
    }
    
    private func calculateBackoffDelay(attempt: Int) -> TimeInterval {
        let baseDelay = CmdTabConstants.retryBaseDelay * pow(2.0, Double(attempt))
        let jitter = Double.random(in: 0...0.1) // 0-100ms randomization to prevent thundering herd
        return min(baseDelay + jitter, 10.0) // Cap at 10s
    }
    
    private func completeSubscription(processSwitcherList: AXUIElement) {
        guard let cmdTabObserver else {
            Self.logger.error("cmdTabObserver is nil after successful creation")
            return
        }
        
        do {
            // Always use main RunLoop for consistency - all AXObserver operations use main thread
            try processSwitcherList.subscribeToNotification(cmdTabObserver, kAXSelectedChildrenChangedNotification as String) {
                CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(cmdTabObserver), .commonModes)
            }
            try processSwitcherList.subscribeToNotification(cmdTabObserver, kAXUIElementDestroyedNotification as String)
            
            cmdTabObserverCreationTime = Date()
            lastCmdTabNotificationTime = Date() // Initialize with creation time
            Self.logger.info("Successfully created Cmd+Tab observer")
        } catch {
            Self.logger.error("Failed to subscribe to Cmd+Tab notifications: \(error.localizedDescription, privacy: .public)")
        }
    }

    func processCmdTabSwitcherEvent(_ notification: CFString) {
        guard Defaults[.enableCmdTabEnhancements] else { return }
        
        // Update last notification time for health check
        lastCmdTabNotificationTime = Date()
        
        let notif = notification as String
        if notif == (kAXSelectedChildrenChangedNotification as String) {
            processCmdTabSwitcherChanged()
            return
        }

        if notif == (kAXUIElementDestroyedNotification as String) {
            // Switcher closed; set up to re-subscribe for the next session
            guard let dockApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
                teardownCmdTabObserver()
                return
            }
            teardownCmdTabObserver()
            scheduleCmdTabResubscribe(dockAppPID: dockApp.processIdentifier)
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
            do {
                var windows: [WindowInfo] = []
                if let app = resolvedApp {
                    windows = try await WindowUtil.getActiveWindows(of: app)
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
            if (try? element.subrole()) == "AXProcessSwitcherList" { return true }
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
