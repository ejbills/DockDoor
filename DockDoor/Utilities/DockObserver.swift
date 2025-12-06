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

    // Cmd+Tab switcher monitoring (accessed from extension file)
    var cmdTabObserver: AXObserver?
    var cmdTabPollingTimer: Timer?

    private var eventTap: CFMachPort?

    // Dock click behavior state
    var currentClickedAppPID: pid_t?
    var lastHoveredPID: pid_t?
    var lastHoveredAppWasFrontmost: Bool = false
    var lastHoveredAppNeedsRestore: Bool = false

    // Active app indicator hover state tracking
    private var lastIndicatorHoverState: Bool = false

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

    func hideWindowAndResetLastApp() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            previewCoordinator.hideWindow()
        }
    }

    /// Called to check and update the active app indicator hover state.
    /// This provides an additional check when we suspect the dock may no longer be hovered.
    func recheckIndicatorHoverState() {
        let currentHoverState = isAnyDockItemHovered()
        if currentHoverState != lastIndicatorHoverState {
            lastIndicatorHoverState = currentHoverState
            if currentHoverState {
                ActiveAppIndicatorCoordinator.shared?.notifyDockItemHovered()
            } else {
                ActiveAppIndicatorCoordinator.shared?.notifyDockItemUnhovered()
            }
        }
    }

    func processSelectedDockItemChanged() {
        let currentMouseLocation = DockObserver.getMousePosition()
        let appUnderMouseElement = getDockItemAppStatusUnderMouse()

        // Notify active app indicator about dock hover state changes
        // Only send notifications on actual state transitions to prevent duplicate events from canceling the hide timer or causing flickering
        let currentHoverState = isAnyDockItemHovered()
        if currentHoverState != lastIndicatorHoverState {
            lastIndicatorHoverState = currentHoverState
            if currentHoverState {
                ActiveAppIndicatorCoordinator.shared?.notifyDockItemHovered()
            } else {
                ActiveAppIndicatorCoordinator.shared?.notifyDockItemUnhovered()
            }
        }

        guard case let .success(currentApp) = appUnderMouseElement.status,
              let dockItemElement = appUnderMouseElement.dockItemElement,
              !previewCoordinator.windowSwitcherCoordinator.windowSwitcherActive
        else {
            return
        }

        let currentAppInfo = ApplicationInfo(
            processIdentifier: currentApp.processIdentifier,
            bundleIdentifier: currentApp.bundleIdentifier,
            localizedName: currentApp.localizedName
        )

        Task { @MainActor [weak self] in
            guard let self else { return }

            do {
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

                guard !appsToFetchWindowsFrom.isEmpty else {
                    return
                }

                var combinedWindows: [WindowInfo] = []
                for appInstance in appsToFetchWindowsFrom {
                    let windowsForInstance = try await WindowUtil.getActiveWindows(of: appInstance)
                    combinedWindows.append(contentsOf: windowsForInstance)
                }

                // Filter windows to only show those in the current Space if the setting is enabled
                if Defaults[.showWindowsFromCurrentSpaceOnly] {
                    combinedWindows = await WindowUtil.filterWindowsByCurrentSpace(combinedWindows)
                }

                lastHoveredPID = currentApp.processIdentifier
                lastHoveredAppWasFrontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier == currentApp.processIdentifier
                lastHoveredAppNeedsRestore = currentApp.isHidden || combinedWindows.contains(where: \.isMinimized)

                if combinedWindows.isEmpty {
                    let isSpecialApp = currentApp.bundleIdentifier == spotifyAppIdentifier ||
                        currentApp.bundleIdentifier == appleMusicAppIdentifier ||
                        currentApp.bundleIdentifier == calendarAppIdentifier

                    // Only continue if this is a special app with controls enabled
                    guard isSpecialApp, Defaults[.showSpecialAppControls] else {
                        return
                    }
                }

                let mouseScreen = NSScreen.screenContainingMouse(currentMouseLocation)
                let convertedMouseLocation = DockObserver.nsPointFromCGPoint(currentMouseLocation, forScreen: mouseScreen)

                previewCoordinator.showWindow(
                    appName: currentAppInfo.localizedName ?? "Unknown",
                    windows: combinedWindows,
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
            } catch {
                // Silently handle errors
            }
        }
    }

    /// Checks if ANY dock item (app, folder, trash, etc.) is currently being hovered.
    /// Used for visibility decisions where we care about dock visibility, not specific app items.
    func isAnyDockItemHovered() -> Bool {
        guard let dockAppPID = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.processIdentifier else {
            return false
        }

        let dockAppElement = AXUIElementCreateApplication(dockAppPID)

        var dockItems: CFTypeRef?
        guard AXUIElementCopyAttributeValue(dockAppElement, kAXChildrenAttribute as CFString, &dockItems) == .success,
              let dockItems = dockItems as? [AXUIElement],
              !dockItems.isEmpty
        else {
            return false
        }

        var selectedChildren: CFTypeRef?
        guard AXUIElementCopyAttributeValue(dockItems.first!, kAXSelectedChildrenAttribute as CFString, &selectedChildren) == .success,
              let selected = selectedChildren as? [AXUIElement],
              !selected.isEmpty
        else {
            return false
        }

        return true
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

    // Enable dock click detection
    func enableDockClickDetection() {
        setupEventTap()
    }

    private func setupEventTap() {
        let eventMask: CGEventMask = (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.rightMouseDown.rawValue)

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
        let appUnderMouse = getDockItemAppStatusUnderMouse()

        if case let .success(app) = appUnderMouse.status {
            if type == .rightMouseDown, event.flags.contains(.maskCommand), Defaults[.enableCmdRightClickQuit] {
                handleCmdRightClickQuit(app: app, event: event)
                return nil
            }

            if type == .leftMouseDown {
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

        // If no hover state, query AX directly to check if any windows are minimized at click time
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
        let wasRestorationNeededFromHover = hasValidHoverState && lastHoveredAppNeedsRestore
        let restorationNeededAtClickTime = wasRestorationNeededFromHover || hasMinimizedWindowsAtClickTime || app.isHidden

        lastHoveredPID = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self else { return }

            previewCoordinator.hideWindow()

            Task { @MainActor [weak self] in
                guard let self else { return }

                let windows = try await WindowUtil.getActiveWindows(of: app)
                let currentlyHasMinimizedWindows = windows.contains(where: \.isMinimized)

                // Use the state captured at click time to determine intent
                // This prevents native dock's restore from confusing our logic
                let needsRestore = restorationNeededAtClickTime || currentlyHasMinimizedWindows

                if needsRestore {
                    restoreAppWindows(windows: windows, app: app, appName: appName)
                } else if wasFrontmostOnHover, !windows.isEmpty {
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
            for window in windowsToMinimize {
                var mutableWindow = window
                _ = mutableWindow.toggleMinimize()
            }
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
                let isSpecialApp = app.bundleIdentifier == spotifyAppIdentifier ||
                    app.bundleIdentifier == appleMusicAppIdentifier ||
                    app.bundleIdentifier == calendarAppIdentifier

                if isSpecialApp, Defaults[.showSpecialAppControls] {
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
}
