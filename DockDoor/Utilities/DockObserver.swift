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
    let previewCoordinator: SharedPreviewWindowCoordinator

    var axObserver: AXObserver?
    private var previousStatus: ApplicationReturnType.Status?

    private var currentDockPID: pid_t?
    private var healthCheckTimer: Timer?
    private var subscribedDockList: AXUIElement?

    // Cmd+Tab switcher monitoring (accessed from extension file)
    var cmdTabObserver: AXObserver?
    var cmdTabPollingTimer: Timer?

    private var eventTap: CFMachPort?

    // Dock click behavior state
    var currentClickedAppPID: pid_t?
    var lastHoveredPID: pid_t?
    var lastHoveredAppWasFrontmost: Bool = false
    var lastHoveredAppNeedsRestore: Bool = false
    var lastHoveredAppHadWindows: Bool = false

    // Scroll gesture state
    private var lastScrollActionTime: Date = .distantPast
    private let scrollActionDebounceInterval: TimeInterval = 0.3

    private static func isSpecialControlsApp(_ bundleId: String?) -> Bool {
        bundleId == spotifyAppIdentifier ||
            bundleId == appleMusicAppIdentifier ||
            bundleId == calendarAppIdentifier
    }

    static func isDockVisible() -> Bool {
        DockUtils.getDockSize() > 0
    }

    init(previewCoordinator: SharedPreviewWindowCoordinator) {
        self.previewCoordinator = previewCoordinator
        DockObserver.activeInstance = self
        setupSelectedDockItemObserver()
        startHealthCheckTimer()
        enableDockClickDetection()
    }

    deinit {
        if DockObserver.activeInstance === self {
            DockObserver.activeInstance = nil
        }
        healthCheckTimer?.invalidate()
        teardownObserver()
        teardownCmdTabObserver()

        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
    }

    private func startHealthCheckTimer() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.performHealthCheck()
        }
    }

    private func reset() {
        teardownObserver()
        teardownCmdTabObserver()
        setupSelectedDockItemObserver()
    }

    private func performHealthCheck() {
        guard let currentDockPID else {
            setupSelectedDockItemObserver()
            return
        }

        let currentDockApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first

        if currentDockApp?.processIdentifier != currentDockPID {
            reset()
            return
        }

        // Verify the subscribed dock list element is still valid
        // If the dock rebuilds its UI, the element becomes invalid and notifications stop
        if let subscribedElement = subscribedDockList {
            var role: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(subscribedElement, kAXRoleAttribute as CFString, &role)
            if result == .invalidUIElement || result == .cannotComplete {
                reset()
            }
        } else if axObserver != nil {
            // We have an observer but no subscribed element reference - reset to fix state
            reset()
        }
    }

    private func teardownObserver() {
        if let observer = axObserver {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        axObserver = nil
        currentDockPID = nil
        subscribedDockList = nil
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
            subscribedDockList = axList
        } catch {
            return
        }
    }

    func hideWindowAndResetLastApp() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            previewCoordinator.hideWindow()
        }
    }

    func processSelectedDockItemChanged() {
        let currentMouseLocation = DockObserver.getMousePosition()
        let appUnderMouseElement = DebugLogger.measureSlow("getDockItemAppStatusUnderMouse", thresholdMs: 100) {
            getDockItemAppStatusUnderMouse()
        }

        guard case let .success(currentApp) = appUnderMouseElement.status,
              let dockItemElement = appUnderMouseElement.dockItemElement,
              !previewCoordinator.windowSwitcherCoordinator.windowSwitcherActive
        else {
            return
        }

        if WindowUtil.isAppFiltered(currentApp) {
            return
        }

        let currentAppInfo = ApplicationInfo(
            processIdentifier: currentApp.processIdentifier,
            bundleIdentifier: currentApp.bundleIdentifier,
            localizedName: currentApp.localizedName
        )

        // Build list of apps to fetch windows from
        var appsToFetchWindowsFrom: [NSRunningApplication] = []
        if Defaults[.groupAppInstancesInDock],
           let bundleId = currentApp.bundleIdentifier, !bundleId.isEmpty
        {
            let potentialApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
            if !potentialApps.isEmpty {
                appsToFetchWindowsFrom = potentialApps
            } else {
                appsToFetchWindowsFrom = [currentApp]
            }
        } else {
            appsToFetchWindowsFrom = [currentApp]
        }

        guard !appsToFetchWindowsFrom.isEmpty else { return }

        var cachedWindows: [WindowInfo] = []
        for appInstance in appsToFetchWindowsFrom {
            cachedWindows.append(contentsOf: WindowUtil.readCachedWindows(for: appInstance.processIdentifier))
        }

        lastHoveredPID = currentApp.processIdentifier
        lastHoveredAppWasFrontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier == currentApp.processIdentifier
        lastHoveredAppNeedsRestore = currentApp.isHidden || cachedWindows.contains(where: \.isMinimized)
        lastHoveredAppHadWindows = !cachedWindows.isEmpty

        if Defaults[.ignoreAppsWithSingleWindow], cachedWindows.count <= 1 {
            cachedWindows = []
        }

        guard Defaults[.enableDockPreviews] else { return }

        let mouseScreen = NSScreen.screenContainingMouse(currentMouseLocation)
        let convertedMouseLocation = DockObserver.nsPointFromCGPoint(currentMouseLocation, forScreen: mouseScreen)
        let screenOrigin = mouseScreen.frame.origin
        let currentAppPID = currentApp.processIdentifier
        let currentAppBundleId = currentApp.bundleIdentifier

        let shouldShowCachedPreview = !cachedWindows.isEmpty ||
            (Self.isSpecialControlsApp(currentApp.bundleIdentifier) && Defaults[.showSpecialAppControls])

        if shouldShowCachedPreview {
            previewCoordinator.showWindow(
                appName: currentAppInfo.localizedName ?? "Unknown",
                windows: cachedWindows,
                mouseLocation: convertedMouseLocation,
                mouseScreen: mouseScreen,
                dockItemElement: dockItemElement,
                overrideDelay: false,
                onWindowTap: { [weak self] in
                    self?.hideWindowAndResetLastApp()
                },
                bundleIdentifier: currentAppInfo.bundleIdentifier
            )
            previousStatus = .success(currentApp)
        }

        Task.detached { [weak self] in
            guard let self else { return }

            do {
                var windows: [WindowInfo] = []
                for appInstance in appsToFetchWindowsFrom {
                    try await windows.append(contentsOf: DebugLogger.measureAsync("getActiveWindows (dock hover)", details: "PID: \(appInstance.processIdentifier)") {
                        try await WindowUtil.getActiveWindows(of: appInstance)
                    })
                }

                if Defaults[.showWindowsFromCurrentSpaceOnly] {
                    windows = await WindowUtil.filterWindowsByCurrentSpace(windows)
                }

                let freshWindows = windows

                await MainActor.run { [weak self] in
                    guard let self else { return }

                    let currentAppStatus = getDockItemAppStatusUnderMouse()
                    guard case let .success(stillHoveredApp) = currentAppStatus.status,
                          stillHoveredApp.processIdentifier == currentAppPID
                    else { return }

                    let dockPosition = DockUtils.getDockPosition()
                    guard let monitor = screenOrigin.screen() else { return }

                    if freshWindows.isEmpty {
                        if !Self.isSpecialControlsApp(currentAppBundleId) || !Defaults[.showSpecialAppControls] {
                            return
                        }
                    }

                    previewCoordinator.mergeWindowsIfShowing(
                        for: currentAppPID,
                        windows: freshWindows,
                        dockPosition: dockPosition,
                        bestGuessMonitor: monitor
                    )
                }
            } catch {
                DebugLogger.log("DockObserver", details: "Failed to fetch windows for dock hover: \(error)")
            }
        }
    }

    /// Returns the currently selected (hovered) dock item, if any.
    private func getSelectedDockItem() -> AXUIElement? {
        guard let dockAppPID = currentDockPID else {
            return nil
        }

        let dockAppElement = AXUIElementCreateApplication(dockAppPID)

        var dockItems: CFTypeRef?
        guard AXUIElementCopyAttributeValue(dockAppElement, kAXChildrenAttribute as CFString, &dockItems) == .success,
              let dockItems = dockItems as? [AXUIElement],
              !dockItems.isEmpty
        else {
            return nil
        }

        var selectedChildren: CFTypeRef?
        guard AXUIElementCopyAttributeValue(dockItems.first!, kAXSelectedChildrenAttribute as CFString, &selectedChildren) == .success,
              let selected = selectedChildren as? [AXUIElement],
              let hoveredItem = selected.first
        else {
            return nil
        }

        return hoveredItem
    }

    func getHoveredApplicationDockItem() -> AXUIElement? {
        guard let item = getSelectedDockItem(),
              (try? item.subrole()) == "AXApplicationDockItem"
        else {
            return nil
        }
        return item
    }

    /// Returns all dock item children from the dock list.
    private func getAllDockItemChildren() -> [AXUIElement]? {
        guard let dockAppPID = currentDockPID else {
            return nil
        }

        let dockAppElement = AXUIElementCreateApplication(dockAppPID)

        var dockItems: CFTypeRef?
        guard AXUIElementCopyAttributeValue(dockAppElement, kAXChildrenAttribute as CFString, &dockItems) == .success,
              let dockItemsList = dockItems as? [AXUIElement],
              let dockList = dockItemsList.first
        else {
            return nil
        }

        var children: CFTypeRef?
        guard AXUIElementCopyAttributeValue(dockList, kAXChildrenAttribute as CFString, &children) == .success,
              let dockChildren = children as? [AXUIElement]
        else {
            return nil
        }

        return dockChildren
    }

    /// Finds the instance index of a hovered dock item among all dock items with the same bundle identifier.
    /// This is used to correctly identify which instance of a multi-instance app is being hovered.
    private func findDockItemInstanceIndex(_ hoveredItem: AXUIElement, bundleIdentifier: String) -> Int {
        guard let allDockItems = getAllDockItemChildren() else {
            return 0
        }

        // Filter to only AXApplicationDockItems with the same bundle ID
        var matchingItems: [AXUIElement] = []
        for item in allDockItems {
            guard (try? item.subrole()) == "AXApplicationDockItem",
                  let itemURL = try? item.attribute(kAXURLAttribute, NSURL.self)?.absoluteURL,
                  let itemBundle = Bundle(url: itemURL),
                  itemBundle.bundleIdentifier == bundleIdentifier
            else {
                continue
            }
            matchingItems.append(item)
        }

        // Find the index of the hovered item among matching items
        for (index, item) in matchingItems.enumerated() {
            if CFEqual(item, hoveredItem) {
                return index
            }
        }

        return 0
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

            let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)

            // For multiple instances, find the correct one based on dock position
            if runningApps.count > 1 {
                let instanceIndex = findDockItemInstanceIndex(hoveredDockItem, bundleIdentifier: bundleIdentifier)
                if instanceIndex < runningApps.count {
                    return ApplicationReturnType(status: .success(runningApps[instanceIndex]), dockItemElement: hoveredDockItem)
                }
            }

            if let runningApp = runningApps.first {
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

    // Enable dock click detection
    func enableDockClickDetection() {
        setupEventTap()
    }

    private func setupEventTap() {
        let eventMask: CGEventMask = (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.scrollWheel.rawValue)

        guard let eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .tailAppendEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let observer = Unmanaged<DockObserver>.fromOpaque(refcon).takeUnretainedValue()
                return observer.eventTapCallback(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("Failed to create event tap")
            return
        }

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)

        self.eventTap = eventTap
    }

    private func eventTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .scrollWheel {
            guard Defaults[.enableDockScrollGesture] else {
                return Unmanaged.passUnretained(event)
            }

            let appUnderMouse = getDockItemAppStatusUnderMouse()
            if case let .success(app) = appUnderMouse.status {
                let handled = handleDockScroll(app: app, event: event)
                if handled {
                    return nil
                }
            }
            return Unmanaged.passUnretained(event)
        }

        let appUnderMouse = getDockItemAppStatusUnderMouse()

        if case let .success(app) = appUnderMouse.status {
            if type == .rightMouseDown, event.flags.contains(.maskCommand), Defaults[.enableCmdRightClickQuit] {
                handleCmdRightClickQuit(app: app, event: event)
                return nil
            }

            if type == .leftMouseDown, !previewCoordinator.mouseIsWithinPreviewWindow {
                let shouldIntercept = handleDockClick(app: app)
                if shouldIntercept {
                    return nil
                }
            }
        }

        return Unmanaged.passUnretained(event)
    }

    private func handleDockClick(app: NSRunningApplication) -> Bool {
        let pid = app.processIdentifier
        let appName = app.localizedName ?? "Unknown"

        // Skip DockDoor itself to prevent crashes when clicking own dock icon
        if app.bundleIdentifier == Bundle.main.bundleIdentifier {
            return false
        }

        currentClickedAppPID = pid

        let isFrontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier == pid
        let hasValidHoverState = lastHoveredPID == pid
        let wasFrontmostOnHover = hasValidHoverState ? lastHoveredAppWasFrontmost : isFrontmost

        guard Defaults[.shouldHideOnDockItemClick] else { return false }

        // Defer to native behavior for simple activation
        if hasValidHoverState, !lastHoveredAppWasFrontmost, !lastHoveredAppNeedsRestore {
            lastHoveredPID = nil
            return false
        }

        // If app had no windows at hover time, defer to native behavior
        // This prevents minimizing newly created windows when clicking an app with no windows
        if hasValidHoverState, !lastHoveredAppHadWindows, !app.isHidden {
            lastHoveredPID = nil
            return false
        }

        // If no hover state, query AX directly to check if windows are minimized at click time
        var hasMinimizedWindowsAtClickTime = false
        if !hasValidHoverState {
            let axApp = AXUIElementCreateApplication(pid)
            if let windowList = try? axApp.windows() {
                for window in windowList {
                    if (try? window.isMinimized()) == true {
                        hasMinimizedWindowsAtClickTime = true
                        break
                    }
                }
            }
        }

        // Capture restoration need from hover state OR from AX query at click time
        let restorationNeededFromHover = hasValidHoverState && lastHoveredAppNeedsRestore
        let restorationNeededAtClickTime = restorationNeededFromHover || hasMinimizedWindowsAtClickTime || app.isHidden

        lastHoveredPID = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self else { return }

            previewCoordinator.hideWindow()

            Task { @MainActor [weak self] in
                guard let self else { return }

                let windows = try await WindowUtil.getActiveWindows(of: app, ignoreSingleWindowFilter: true)
                let currentlyHasMinimizedWindows = windows.contains(where: \.isMinimized)

                // Use the state captured at click time to determine intent
                // This prevents native dock's restore from confusing our logic
                let needsRestore = restorationNeededAtClickTime || currentlyHasMinimizedWindows

                if needsRestore {
                    DebugLogger.log("DockClick", details: "\(appName): restoring (needsRestore=true, minimized=\(currentlyHasMinimizedWindows))")
                    restoreAppWindows(windows: windows, app: app, appName: appName)
                } else if wasFrontmostOnHover, !windows.isEmpty {
                    DebugLogger.log("DockClick", details: "\(appName): hiding (wasFrontmost=true, windows=\(windows.count))")
                    hideAppWindows(windows: windows, app: app, appName: appName)
                }
            }
        }

        return false
    }

    private func hideAppWindows(windows: [WindowInfo], app: NSRunningApplication, appName: String) {
        let windowsToMinimize = windows.filter { !$0.isMinimized }
        guard !windowsToMinimize.isEmpty else { return }

        if Defaults[.dockClickAction] == .hide {
            DispatchQueue.main.async {
                app.hide()
            }
        } else {
            WindowUtil.minimizeWindowsAsync(windowsToMinimize)
        }
    }

    private func restoreAppWindows(windows: [WindowInfo], app: NSRunningApplication, appName: String) {
        let windowsToRestore = windows.filter(\.isMinimized)
        guard !windowsToRestore.isEmpty || app.isHidden else { return }

        if Defaults[.dockClickAction] == .hide {
            app.activate()
        } else {
            for window in windowsToRestore {
                var mutableWindow = window
                _ = mutableWindow.toggleMinimize()
            }
            app.activate()
        }
    }

    private func showPreviewForFocusedApp(app: NSRunningApplication) {
        if WindowUtil.isAppFiltered(app) {
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }

            let currentMouseLocation = DockObserver.getMousePosition()
            let appUnderMouseElement = getDockItemAppStatusUnderMouse()

            guard case let .success(currentApp) = appUnderMouseElement.status,
                  currentApp.processIdentifier == app.processIdentifier,
                  let dockItemElement = appUnderMouseElement.dockItemElement
            else {
                return
            }

            do {
                let windows = try await WindowUtil.getActiveWindows(of: app)
                let mouseScreen = NSScreen.screenContainingMouse(currentMouseLocation)
                let convertedMouseLocation = DockObserver.nsPointFromCGPoint(currentMouseLocation, forScreen: mouseScreen)

                previewCoordinator.showWindow(
                    appName: app.localizedName ?? "Unknown",
                    windows: windows,
                    mouseLocation: convertedMouseLocation,
                    mouseScreen: mouseScreen,
                    dockItemElement: dockItemElement,
                    overrideDelay: true,
                    onWindowTap: { [weak self] in
                        self?.hideWindowAndResetLastApp()
                    },
                    bundleIdentifier: app.bundleIdentifier
                )
            } catch {
                // If we can't get windows, still show the preview for special apps if enabled
                if Self.isSpecialControlsApp(app.bundleIdentifier), Defaults[.showSpecialAppControls] {
                    let mouseScreen = NSScreen.screenContainingMouse(currentMouseLocation)
                    let convertedMouseLocation = DockObserver.nsPointFromCGPoint(currentMouseLocation, forScreen: mouseScreen)

                    previewCoordinator.showWindow(
                        appName: app.localizedName ?? "Unknown",
                        windows: [],
                        mouseLocation: convertedMouseLocation,
                        mouseScreen: mouseScreen,
                        dockItemElement: dockItemElement,
                        overrideDelay: true,
                        onWindowTap: { [weak self] in
                            self?.hideWindowAndResetLastApp()
                        },
                        bundleIdentifier: app.bundleIdentifier
                    )
                }
            }
        }
    }

    private func handleCmdRightClickQuit(app: NSRunningApplication, event: CGEvent) {
        Task { @MainActor in
            if event.flags.contains(.maskAlternate) {
                app.forceTerminate()
            } else {
                app.terminate()
            }
        }
    }

    private func handleDockScroll(app: NSRunningApplication, event: CGEvent) -> Bool {
        let deltaY = event.getDoubleValueField(.scrollWheelEventDeltaAxis1)

        // Ignore noise (very small scroll amounts)
        guard abs(deltaY) > 0.1 else { return false }

        let nsEvent = NSEvent(cgEvent: event)
        let isNaturalScrolling = nsEvent?.isDirectionInvertedFromDevice ?? false
        let normalizedDeltaY = isNaturalScrolling ? -deltaY : deltaY

        if isMediaApp(app.bundleIdentifier) {
            if Defaults[.dockIconMediaScrollBehavior] == .adjustVolume {
                handleVolumeScroll(deltaY: normalizedDeltaY)
                return true
            }
        }

        let now = Date()
        guard now.timeIntervalSince(lastScrollActionTime) >= scrollActionDebounceInterval else {
            return true // Still consume the event during debounce
        }
        lastScrollActionTime = now

        if normalizedDeltaY > 0 {
            activateApp(app)
        } else {
            hideApp(app)
        }

        return true
    }

    private func handleVolumeScroll(deltaY: Double) {
        let sensitivity: Float = 0.015
        let current = AudioDeviceManager.getSystemVolume()
        let newVolume = max(0, min(1, current + Float(deltaY) * sensitivity))
        AudioDeviceManager.setSystemVolume(newVolume)
    }

    private func activateApp(_ app: NSRunningApplication) {
        Task { @MainActor in
            if app.isHidden {
                app.unhide()
            }
            app.activate(options: [.activateIgnoringOtherApps])
            previewCoordinator.hideWindow()
        }
    }

    private func hideApp(_ app: NSRunningApplication) {
        Task { @MainActor in
            app.hide()
            previewCoordinator.hideWindow()
        }
    }
}
