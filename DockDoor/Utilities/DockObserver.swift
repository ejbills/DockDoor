import ApplicationServices
import ApplicationServices.HIServices.AXNotificationConstants
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
    enum Status {
        case success(NSRunningApplication)
        case notRunning(bundleIdentifier: String)
        case notFound
    }

    let status: Status
    let iconRect: CGRect?
}

func handleSelectedDockItemChangedNotification(observer _: AXObserver, element _: AXUIElement, notificationName _: CFString, _: UnsafeMutableRawPointer?) {
    DockObserver.shared.processSelectedDockItemChanged()
}

final class DockObserver {
    static let shared = DockObserver()

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

    private var notRunningCount: Int = 0
    private let maxNotRunningCount: Int = 3

    private var lastIconRect: CGRect?
    private var pulseWorkItem: DispatchWorkItem?

    private var positionCheckTimer: Timer?
    private var observedDockItem: AXUIElement?
    private var lastCheckedRect: CGRect?

    private(set) var isPositionMonitoringActive: Bool = false

    private init() {
        setupSelectedDockItemObserver()
        startHealthCheckTimer()
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
            SharedPreviewWindowCoordinator.shared.hideWindow()
            resetLastAppUnderMouse()
            lastNotificationTime = 0
            lastNotificationId = ""
            notRunningCount = 0
            pendingShows.removeAll()
        }
    }

    private func cancelPulseWorkItem() {
        pulseWorkItem?.cancel()
        pulseWorkItem = nil
    }

    deinit {
        teardownObserver()
        stopPositionChecking()
    }

    private func startPositionChecking(for dockItem: AXUIElement) {
        stopPositionChecking()

        observedDockItem = dockItem
        lastCheckedRect = getIconRect(for: dockItem)

        positionCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self,
                  let dockItem = observedDockItem
            else {
                return
            }

            // Check if mouse is still over a dock item
            guard getHoveredApplicationDockItem() != nil else {
                stopPositionChecking()
                return
            }

            // Check position changes
            guard let newRect = getIconRect(for: dockItem),
                  let lastRect = lastCheckedRect,
                  newRect != lastRect
            else {
                return
            }

            lastCheckedRect = newRect
            handlePositionChanged(element: dockItem)
        }
    }

    private func stopPositionChecking() {
        positionCheckTimer?.invalidate()
        positionCheckTimer = nil
        observedDockItem = nil
        lastCheckedRect = nil
    }

    private func handlePositionChanged(element: AXUIElement) {
        guard let iconRect = getIconRect(for: element) else { return }

        DispatchQueue.main.async {
            SharedPreviewWindowCoordinator.shared.updatePosition(iconRect: iconRect)
        }
    }

    func startPositionMonitoring() {
        guard let hoveredDockItem = getHoveredApplicationDockItem() else { return }
        startPositionChecking(for: hoveredDockItem)
        isPositionMonitoringActive = true
    }

    func stopPositionMonitoring() {
        stopPositionChecking()
        isPositionMonitoringActive = false
    }

    func processSelectedDockItemChanged() {
        let currentTime = ProcessInfo.processInfo.systemUptime
        let currentMouseLocation = DockObserver.getMousePosition()
        let appUnderMouseElement = getDockItemAppStatusUnderMouse()

        if case let .notRunning(bundleIdentifier: bundleIdentifier) = appUnderMouseElement.status {
            if lastNotificationId == bundleIdentifier {
                let timeSinceLastNotification = currentTime - lastNotificationTime
                if timeSinceLastNotification < artifactTimeThreshold {
                    return
                }
            }

            lastNotificationTime = currentTime
            lastNotificationId = bundleIdentifier

            notRunningCount += 1
            if notRunningCount >= maxNotRunningCount || !Defaults[.lateralMovement] {
                hideWindowAndResetLastApp()
            } else if case .notRunning = previousStatus {
                let timeSinceLastNotification = currentTime - lastNotificationTime
                if timeSinceLastNotification < artifactTimeThreshold {
                    return
                }
                hideWindowAndResetLastApp()
            }
            previousStatus = appUnderMouseElement.status
            resetLastAppUnderMouse()
            return
        } else if case .notFound = appUnderMouseElement.status {
            let mouseScreen = NSScreen.screenContainingMouse(currentMouseLocation)
            let convertedMouseLocation = DockObserver.nsPointFromCGPoint(currentMouseLocation, forScreen: mouseScreen)

            if !SharedPreviewWindowCoordinator.shared.frame.extended(by: abs(Defaults[.bufferFromDock])).contains(convertedMouseLocation)
                || !Defaults[.lateralMovement]
            {
                hideWindowAndResetLastApp()
            }
            previousStatus = appUnderMouseElement.status
            resetLastAppUnderMouse()
            return
        }

        if case .success = appUnderMouseElement.status {
            notRunningCount = 0
        }

        hoverProcessingTask?.cancel()
        pendingShows.removeAll()

        Task { @MainActor in
            SharedPreviewWindowCoordinator.shared.cancelDebounceWorkItem()
        }

        hoverProcessingTask = Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                try Task.checkCancellation()

                guard case let .success(currentApp) = appUnderMouseElement.status,
                      let iconRect = appUnderMouseElement.iconRect
                else {
                    return
                }

                let pid = currentApp.processIdentifier

                if lastNotificationId == String(pid) {
                    let timeSinceLastNotification = currentTime - lastNotificationTime
                    if timeSinceLastNotification < artifactTimeThreshold {
                        pendingShows.remove(pid)
                        return
                    }
                }

                lastNotificationTime = currentTime
                lastNotificationId = String(pid)

                guard !isProcessing, !SharedPreviewWindowCoordinator.shared.windowSwitcherCoordinator.windowSwitcherActive else {
                    return
                }

                isProcessing = true
                defer { isProcessing = false }

                let currentAppInfo = ApplicationInfo(
                    processIdentifier: currentApp.processIdentifier,
                    bundleIdentifier: currentApp.bundleIdentifier,
                    localizedName: currentApp.localizedName
                )

                let isWindowVisible = SharedPreviewWindowCoordinator.shared.isVisible && SharedPreviewWindowCoordinator.shared.alphaValue == 1.0

                if currentAppInfo.processIdentifier != lastAppUnderMouse?.processIdentifier || !isWindowVisible {
                    pendingShows.insert(currentAppInfo.processIdentifier)
                    lastAppUnderMouse = currentAppInfo

                    guard let app = currentAppInfo.app() else {
                        pendingShows.remove(currentAppInfo.processIdentifier)
                        return
                    }

                    let appWindows = try await WindowUtil.getActiveWindows(of: app)

                    if !pendingShows.contains(currentAppInfo.processIdentifier) {
                        return
                    }

                    let mouseScreen = NSScreen.screenContainingMouse(currentMouseLocation)
                    let convertedMouseLocation = DockObserver.nsPointFromCGPoint(currentMouseLocation, forScreen: mouseScreen)

                    SharedPreviewWindowCoordinator.shared.showWindow(
                        appName: currentAppInfo.localizedName ?? "Unknown",
                        windows: appWindows,
                        mouseLocation: convertedMouseLocation,
                        mouseScreen: mouseScreen,
                        iconRect: iconRect,
                        overrideDelay: lastAppUnderMouse == nil && Defaults[.hoverWindowOpenDelay] == 0,
                        onWindowTap: { [weak self] in
                            self?.hideWindowAndResetLastApp()
                        }
                    )

                    pendingShows.remove(currentAppInfo.processIdentifier)
                }
                previousStatus = .success(currentApp)
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
            return ApplicationReturnType(status: .notFound, iconRect: nil)
        }

        let iconRect = getIconRect(for: hoveredDockItem)

        do {
            guard let appURL = try hoveredDockItem.attribute(kAXURLAttribute, NSURL.self)?.absoluteURL else {
                throw AxError.runtimeError
            }

            let bundle = Bundle(url: appURL)
            guard let bundleIdentifier = bundle?.bundleIdentifier else {
                guard let dockItemTitle = try hoveredDockItem.title() else {
                    return ApplicationReturnType(status: .notFound, iconRect: iconRect)
                }

                if let app = WindowUtil.findRunningApplicationByName(named: dockItemTitle) {
                    return ApplicationReturnType(status: .success(app), iconRect: iconRect)
                } else {
                    return ApplicationReturnType(status: .notFound, iconRect: iconRect)
                }
            }

            if let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first {
                return ApplicationReturnType(status: .success(runningApp), iconRect: iconRect)
            } else {
                return ApplicationReturnType(status: .notRunning(bundleIdentifier: bundleIdentifier), iconRect: iconRect)
            }
        } catch {
            return ApplicationReturnType(status: .notFound, iconRect: iconRect)
        }
    }

    private func getIconRect(for dockItem: AXUIElement) -> CGRect? {
        do {
            guard let position = try dockItem.position(),
                  let size = try dockItem.size()
            else {
                return nil
            }
            return CGRect(origin: position, size: size)
        } catch {
            return nil
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
