import ApplicationServices
import Cocoa
import Defaults

struct ApplicationInfo: Sendable {
    let processIdentifier: pid_t
    let bundleIdentifier: String?
    let localizedName: String?

    func app() -> NSRunningApplication? {
        NSRunningApplication(processIdentifier: processIdentifier)
    }
}

struct ApplicationReturnType {
    enum Status: Equatable {
        case success(NSRunningApplication)
        case notRunning(bundleIdentifier: String)
        case notFound
    }

    let status: Status
    let dockItemElement: AXUIElement?
}

func handleSelectedDockItemChangedNotification(observer _: AXObserver, element _: AXUIElement, notificationName _: CFString, context: UnsafeMutableRawPointer?) {
    DockObserver.activeInstance?.processSelectedDockItemChanged()
}

final class DockObserver {
    weak static var activeInstance: DockObserver?
    private let previewCoordinator: SharedPreviewWindowCoordinator

    var axObserver: AXObserver?
    var lastAppUnderMouse: ApplicationInfo?
    private var previousStatus: ApplicationReturnType.Status?
    private var hoverProcessingTask: Task<Void, Error>?
    private var isProcessing: Bool = false

    private var currentDockPID: pid_t?
    private var healthCheckTimer: Timer?

    private var lastNotificationTime: TimeInterval = 0
    private var lastNotificationId: String = ""
    private let artifactTimeThreshold: TimeInterval = 0.05
    private var pendingShows: Set<pid_t> = []

    private var emptyAppStreakCount: Int = 0
    private let maxEmptyAppStreak: Int = 3

    init(previewCoordinator: SharedPreviewWindowCoordinator) {
        self.previewCoordinator = previewCoordinator
        DockObserver.activeInstance = self
        setupSelectedDockItemObserver()
        startHealthCheckTimer()
    }

    deinit {
        if DockObserver.activeInstance === self {
            DockObserver.activeInstance = nil
        }
        healthCheckTimer?.invalidate()
        teardownObserver()
    }

    private func startHealthCheckTimer() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.performHealthCheck()
        }
    }

    private func performHealthCheck() {
        guard let currentDockPID else {
            setupSelectedDockItemObserver()
            return
        }

        let currentDockApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first

        if currentDockApp?.processIdentifier != currentDockPID {
            teardownObserver()
            setupSelectedDockItemObserver()
        }
    }

    private func teardownObserver() {
        if let observer = axObserver {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        axObserver = nil
        currentDockPID = nil
    }

    private func setupSelectedDockItemObserver() {
        guard let dockApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            return
        }

        let dockAppPID = dockApp.processIdentifier
        currentDockPID = dockAppPID

        let dockAppElement = AXUIElementCreateApplication(dockAppPID)

        guard AXIsProcessTrusted() else {
            MessageUtil.showAlert(
                title: "Accessibility Permissions Required",
                message: "You need to enable accessibility permissions for DockDoor to function, click OK to open System Preferences. A restart is required after granting permissions.",
                actions: [.ok, .cancel],
                completion: { _ in
                    SystemPreferencesHelper.openAccessibilityPreferences()
                    askUserToRestartApplication()
                }
            )
            return
        }

        guard let children = try? dockAppElement.children(), let axList = children.first(where: { element in
            try! element.role() == kAXListRole
        }) else {
            return
        }

        if AXObserverCreate(dockAppPID, handleSelectedDockItemChangedNotification, &axObserver) != .success {
            return
        }

        guard let axObserver else { return }

        do {
            try axList.subscribeToNotification(axObserver, kAXSelectedChildrenChangedNotification) {
                CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(axObserver), .commonModes)
            }
        } catch {
            return
        }
    }

    private func resetLastAppUnderMouse() { lastAppUnderMouse = nil }

    private func hideWindowAndResetLastApp() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            previewCoordinator.hideWindow()
            resetLastAppUnderMouse()
            lastNotificationTime = 0
            lastNotificationId = ""
            emptyAppStreakCount = 0
            pendingShows.removeAll()
        }
    }

    func processSelectedDockItemChanged() {
        let currentTime = ProcessInfo.processInfo.systemUptime
        let currentMouseLocation = DockObserver.getMousePosition()
        let appUnderMouseElement = getDockItemAppStatusUnderMouse()

        // If so, ignore this duplicate notification so we don't keep
        // cancelling the in-flight task that will eventually show the preview.
        if
            case let .success(dupApp) = appUnderMouseElement.status,
            let existingTask = hoverProcessingTask,
            !existingTask.isCancelled,
            lastAppUnderMouse?.processIdentifier == dupApp.processIdentifier,
            isProcessing
        {
            // Duplicate notification for the same PID while we're still
            // working on it – swallow it.
            return
        }

        if case let .notRunning(bundleIdentifier) = appUnderMouseElement.status {
            if lastNotificationId == bundleIdentifier {
                let timeSinceLastNotification = currentTime - lastNotificationTime
                if timeSinceLastNotification < artifactTimeThreshold {
                    return
                }
            }
            lastNotificationTime = currentTime
            lastNotificationId = bundleIdentifier

            if !Defaults[.lateralMovement] {
                hideWindowAndResetLastApp()
            } else {
                emptyAppStreakCount += 1
                if emptyAppStreakCount >= maxEmptyAppStreak {
                    hideWindowAndResetLastApp()
                }
            }
            previousStatus = appUnderMouseElement.status
            resetLastAppUnderMouse()
            return
        } else if case .notFound = appUnderMouseElement.status {
            let mouseScreen = NSScreen.screenContainingMouse(currentMouseLocation)
            let convertedMouseLocation = DockObserver.nsPointFromCGPoint(currentMouseLocation, forScreen: mouseScreen)
            let isWithinBuffer = previewCoordinator.frame.extended(by: abs(Defaults[.bufferFromDock])).contains(convertedMouseLocation)

            if !isWithinBuffer || !Defaults[.lateralMovement] {
                hideWindowAndResetLastApp()
            }
            previousStatus = appUnderMouseElement.status
            resetLastAppUnderMouse()
            return
        }

        if let existingTask = hoverProcessingTask,
           !existingTask.isCancelled,
           case let .success(newApp) = appUnderMouseElement.status,
           lastAppUnderMouse?.processIdentifier != newApp.processIdentifier
        {
            isProcessing = false
            existingTask.cancel()
            pendingShows.removeAll()
        }

        Task { @MainActor in
            self.previewCoordinator.cancelDebounceWorkItem()
        }

        hoverProcessingTask = Task { @MainActor [weak self] in
            guard let self else {
                self?.isProcessing = false
                return
            }

            do {
                try Task.checkCancellation()

                guard case let .success(currentApp) = appUnderMouseElement.status,
                      let dockItemElement = appUnderMouseElement.dockItemElement
                else {
                    isProcessing = false
                    return
                }

                let pid = currentApp.processIdentifier

                if lastNotificationId == String(pid) {
                    let timeSinceLastNotification = currentTime - lastNotificationTime
                    if timeSinceLastNotification < artifactTimeThreshold {
                        pendingShows.remove(pid)
                        isProcessing = false
                        return
                    }
                }

                lastNotificationTime = currentTime
                lastNotificationId = String(pid)

                guard !isProcessing, !previewCoordinator.windowSwitcherCoordinator.windowSwitcherActive else {
                    return
                }

                isProcessing = true
                defer {
                    isProcessing = false
                }

                let currentAppInfo = ApplicationInfo(
                    processIdentifier: currentApp.processIdentifier,
                    bundleIdentifier: currentApp.bundleIdentifier,
                    localizedName: currentApp.localizedName
                )

                let isWindowVisible = previewCoordinator.isVisible && previewCoordinator.alphaValue == 1.0

                if currentAppInfo.processIdentifier != lastAppUnderMouse?.processIdentifier || !isWindowVisible {
                    pendingShows.insert(currentAppInfo.processIdentifier)
                    lastAppUnderMouse = currentAppInfo

                    var appsToFetchWindowsFrom: [NSRunningApplication] = []
                    if let bundleId = currentApp.bundleIdentifier, !bundleId.isEmpty {
                        let potentialApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
                        if !potentialApps.isEmpty {
                            appsToFetchWindowsFrom = potentialApps
                        } else {
                            appsToFetchWindowsFrom = [currentApp]
                        }
                    } else {
                        appsToFetchWindowsFrom = [currentApp]
                    }

                    guard !appsToFetchWindowsFrom.isEmpty else {
                        let isSpecialApp = currentApp.bundleIdentifier == spotifyAppIdentifier ||
                            currentApp.bundleIdentifier == appleMusicAppIdentifier ||
                            currentApp.bundleIdentifier == calendarAppIdentifier

                        // This case should ideally not be hit if currentApp is valid.
                        // If it is, treat as "empty" for streak purposes if lateral movement is on.
                        if Defaults[.lateralMovement] {
                            if !(isSpecialApp && Defaults[.showSpecialAppControls]) {
                                emptyAppStreakCount += 1
                                if emptyAppStreakCount >= maxEmptyAppStreak {
                                    hideWindowAndResetLastApp()
                                }
                            }
                        } else {
                            if !(isSpecialApp && Defaults[.showSpecialAppControls]) {
                                hideWindowAndResetLastApp()
                            }
                        }
                        pendingShows.remove(currentAppInfo.processIdentifier)
                        return
                    }

                    var combinedWindows: [WindowInfo] = []
                    for appInstance in appsToFetchWindowsFrom {
                        let windowsForInstance = try await WindowUtil.getActiveWindows(of: appInstance)
                        combinedWindows.append(contentsOf: windowsForInstance)
                    }

                    if combinedWindows.isEmpty {
                        let isSpecialApp = currentApp.bundleIdentifier == spotifyAppIdentifier ||
                            currentApp.bundleIdentifier == appleMusicAppIdentifier ||
                            currentApp.bundleIdentifier == calendarAppIdentifier

                        if !Defaults[.lateralMovement] {
                            if !(isSpecialApp && Defaults[.showSpecialAppControls]) {
                                hideWindowAndResetLastApp()
                                pendingShows.remove(currentAppInfo.processIdentifier)
                                return
                            }
                        } else {
                            if !(isSpecialApp && Defaults[.showSpecialAppControls]) {
                                emptyAppStreakCount += 1
                                if emptyAppStreakCount >= maxEmptyAppStreak {
                                    hideWindowAndResetLastApp()
                                    pendingShows.remove(currentAppInfo.processIdentifier)
                                    return
                                }
                            }
                            // If streak not maxed, proceed to showWindow (might show special view)
                            // emptyAppStreakCount remains incremented.
                        }
                    } else {
                        // Successfully found windows for the app, reset the streak.
                        emptyAppStreakCount = 0
                    }

                    if !pendingShows.contains(currentAppInfo.processIdentifier) {
                        return
                    }

                    let mouseScreen = NSScreen.screenContainingMouse(currentMouseLocation)
                    let convertedMouseLocation = DockObserver.nsPointFromCGPoint(currentMouseLocation, forScreen: mouseScreen)

                    previewCoordinator.showWindow(
                        appName: currentAppInfo.localizedName ?? "Unknown",
                        windows: combinedWindows,
                        mouseLocation: convertedMouseLocation,
                        mouseScreen: mouseScreen,
                        dockItemElement: dockItemElement,
                        overrideDelay: lastAppUnderMouse == nil && Defaults[.hoverWindowOpenDelay] == 0,
                        onWindowTap: { [weak self] in
                            self?.hideWindowAndResetLastApp()
                        },
                        bundleIdentifier: currentAppInfo.bundleIdentifier
                    )

                    pendingShows.remove(currentAppInfo.processIdentifier)
                }
                previousStatus = .success(currentApp)
            } catch {
                isProcessing = false
            }
        }
    }

    func getHoveredApplicationDockItem() -> AXUIElement? {
        guard let dockAppPID = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.processIdentifier else {
            return nil
        }

        let dockAppElement = AXUIElementCreateApplication(dockAppPID)

        var dockItems: CFTypeRef?
        guard AXUIElementCopyAttributeValue(dockAppElement, kAXChildrenAttribute as CFString, &dockItems) == .success, let dockItems = dockItems as? [AXUIElement], !dockItems.isEmpty else {
            return nil
        }

        var hoveredDockItem: CFTypeRef?
        guard AXUIElementCopyAttributeValue(dockItems.first!, kAXSelectedChildrenAttribute as CFString, &hoveredDockItem) == .success, !dockItems.isEmpty, let hoveredDockItem = (hoveredDockItem as! [AXUIElement]).first else {
            return nil
        }

        let subrole = try? hoveredDockItem.subrole()
        guard subrole == "AXApplicationDockItem" else {
            return nil
        }

        return hoveredDockItem
    }

    func getDockItemAppStatusUnderMouse() -> ApplicationReturnType {
        guard let hoveredDockItem = getHoveredApplicationDockItem() else {
            return ApplicationReturnType(status: .notFound, dockItemElement: nil)
        }

        do {
            guard let appURL = try hoveredDockItem.attribute(kAXURLAttribute, NSURL.self)?.absoluteURL else {
                throw AxError.runtimeError
            }

            let bundle = Bundle(url: appURL)
            guard let bundleIdentifier = bundle?.bundleIdentifier else {
                guard let dockItemTitle = try hoveredDockItem.title() else {
                    return ApplicationReturnType(status: .notFound, dockItemElement: hoveredDockItem)
                }

                if let app = WindowUtil.findRunningApplicationByName(named: dockItemTitle) {
                    return ApplicationReturnType(status: .success(app), dockItemElement: hoveredDockItem)
                } else {
                    return ApplicationReturnType(status: .notFound, dockItemElement: hoveredDockItem)
                }
            }

            if let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first {
                return ApplicationReturnType(status: .success(runningApp), dockItemElement: hoveredDockItem)
            } else {
                return ApplicationReturnType(status: .notRunning(bundleIdentifier: bundleIdentifier), dockItemElement: hoveredDockItem)
            }
        } catch {
            return ApplicationReturnType(status: .notFound, dockItemElement: hoveredDockItem)
        }
    }

    static func getMousePosition() -> NSPoint {
        guard let event = CGEvent(source: nil) else {
            fatalError("Unable to get mouse event")
        }

        let mouseLocation = event.location

        let mousePosition = NSPoint(x: mouseLocation.x, y: mouseLocation.y)
        return mousePosition
    }

    private static func computeOffsets(for screen: NSScreen, primaryScreen: NSScreen) -> (CGFloat, CGFloat) {
        var offsetLeft = screen.frame.origin.x
        var offsetTop = primaryScreen.frame.size.height - (screen.frame.origin.y + screen.frame.size.height)

        if screen == primaryScreen {
            offsetTop = 0
            offsetLeft = 0
        }

        return (offsetLeft, offsetTop)
    }

    static func nsPointFromCGPoint(_ point: CGPoint, forScreen: NSScreen?) -> NSPoint {
        guard let screen = forScreen,
              let primaryScreen = NSScreen.screens.first
        else {
            return NSPoint(x: point.x, y: point.y)
        }

        let (_, offsetTop) = computeOffsets(for: screen, primaryScreen: primaryScreen)

        let y: CGFloat
        if screen == primaryScreen {
            y = screen.frame.size.height - point.y
        } else {
            let screenBottomOffset = primaryScreen.frame.size.height - (screen.frame.size.height + offsetTop)
            y = screen.frame.size.height + screenBottomOffset - (point.y - offsetTop)
        }

        return NSPoint(x: point.x, y: y)
    }

    static func cgPointFromNSPoint(_ point: CGPoint, forScreen: NSScreen?) -> CGPoint {
        guard let screen = forScreen,
              let primaryScreen = NSScreen.screens.first
        else {
            return CGPoint(x: point.x, y: point.y)
        }

        let (_, offsetTop) = computeOffsets(for: screen, primaryScreen: primaryScreen)
        let menuScreenHeight = screen.frame.maxY

        return CGPoint(x: point.x, y: menuScreenHeight - point.y + offsetTop)
    }
}
