import ApplicationServices
import Cocoa
import Defaults
import ScreenCaptureKit

let filteredBundleIdentifiers: [String] = ["com.apple.notificationcenterui"] // filters desktop widgets

protocol WindowPropertiesProviding {
    var windowID: CGWindowID { get }
    var frame: CGRect { get }
    var title: String? { get }
    var owningApplicationBundleIdentifier: String? { get }
    var owningApplicationProcessID: pid_t? { get }
    var isOnScreen: Bool { get }
    var windowLayer: Int { get }
}

extension SCWindow: WindowPropertiesProviding {
    var owningApplicationBundleIdentifier: String? { owningApplication?.bundleIdentifier }
    var owningApplicationProcessID: pid_t? { owningApplication?.processID }
}

struct WindowInfo: Identifiable, Hashable {
    let id: CGWindowID
    let windowProvider: WindowPropertiesProviding
    let app: NSRunningApplication
    var windowName: String?
    var image: CGImage?
    var axElement: AXUIElement
    var appAxElement: AXUIElement
    var closeButton: AXUIElement?
    var spaceID: Int?
    var lastAccessedTime: Date
    var imageCapturedTime: Date

    private var _scWindow: SCWindow?

    var isMinimized: Bool {
        (try? axElement.isMinimized()) ?? false
    }

    var isHidden: Bool {
        app.isHidden
    }

    init(windowProvider: WindowPropertiesProviding, app: NSRunningApplication, image: CGImage?, axElement: AXUIElement, appAxElement: AXUIElement, closeButton: AXUIElement?, lastAccessedTime: Date, imageCapturedTime: Date? = nil, spaceID: Int? = nil) {
        id = windowProvider.windowID
        self.windowProvider = windowProvider
        self.app = app
        windowName = windowProvider.title
        self.image = image
        self.axElement = axElement
        self.appAxElement = appAxElement
        self.closeButton = closeButton
        self.spaceID = spaceID
        self.lastAccessedTime = lastAccessedTime
        self.imageCapturedTime = imageCapturedTime ?? lastAccessedTime
        _scWindow = windowProvider as? SCWindow
    }

    var frame: CGRect { windowProvider.frame }
    var scWindow: SCWindow? { _scWindow }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(app.bundleIdentifier ?? String(app.processIdentifier))
    }

    static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        lhs.id == rhs.id &&
            lhs.app.processIdentifier == rhs.app.processIdentifier &&
            lhs.spaceID == rhs.spaceID &&
            lhs.axElement == rhs.axElement
    }
}

enum WindowAction: String, Hashable, CaseIterable, Defaults.Serializable {
    case quit
    case close
    case minimize
    case toggleFullScreen
    case hide
    case openNewWindow
}

enum WindowUtil {
    private static let desktopSpaceWindowCacheManager = SpaceWindowCacheManager()

    // Track windows explicitly updated by bringWindowToFront to prevent observer duplication
    private static var timestampUpdates: [AXUIElement: Date] = [:]
    private static let updateTimestampLock = NSLock()
    private static let windowUpdateTimeWindow: TimeInterval = 1.5

    private static let captureError = NSError(
        domain: "WindowCaptureError",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Error encountered during image capture"]
    )

    static func clearWindowCache(for app: NSRunningApplication) {
        desktopSpaceWindowCacheManager.writeCache(pid: app.processIdentifier, windowSet: [])
    }

    static func updateWindowCache(for app: NSRunningApplication, update: @escaping (inout Set<WindowInfo>) -> Void) {
        desktopSpaceWindowCacheManager.updateCache(pid: app.processIdentifier, update: update)
    }

    static func updateWindowDateTime(element: AXUIElement, app: NSRunningApplication) {
        guard Defaults[.sortWindowsByDate] else { return }

        updateTimestampLock.lock()
        defer { updateTimestampLock.unlock() }

        // Check if this window was recently updated
        let now = Date()
        if let lastUpdate = timestampUpdates[element],
           now.timeIntervalSince(lastUpdate) < windowUpdateTimeWindow
        {
            // Clean up expired timestamp entries
            cleanupExpiredUpdates(currentTime: now)
            return // Skip update
        }

        desktopSpaceWindowCacheManager.updateCache(pid: app.processIdentifier) { windowSet in
            if let index = windowSet.firstIndex(where: { $0.axElement == element }) {
                var updatedWindow = windowSet[index]
                updatedWindow.lastAccessedTime = now
                windowSet.remove(at: index)
                windowSet.insert(updatedWindow)
            }
        }

        timestampUpdates[element] = now
    }

    // MARK: - Helper Functions

    static func captureWindowImage(window: SCWindow, forceRefresh: Bool = false) async throws -> CGImage {
        guard let pid = window.owningApplication?.processID else {
            throw captureError
        }

        return try await captureWindowImage(
            windowID: window.windowID,
            pid: pid,
            windowTitle: window.title,
            forceRefresh: forceRefresh
        )
    }

    static func captureWindowImage(windowID: CGWindowID, pid: pid_t, windowTitle: String? = nil, forceRefresh: Bool = false) async throws -> CGImage {
        // Check cache first if not forcing refresh
        if !forceRefresh {
            if let cachedWindow = desktopSpaceWindowCacheManager.readCache(pid: pid)
                .first(where: { $0.id == windowID && (windowTitle == nil || $0.windowName == windowTitle) }),
                let cachedImage = cachedWindow.image
            {
                let cacheLifespan = Defaults[.screenCaptureCacheLifespan]
                if Date().timeIntervalSince(cachedWindow.imageCapturedTime) <= cacheLifespan {
                    return cachedImage
                }
            }
        }

        var cgImage: CGImage
        let connectionID = CGSMainConnectionID()
        var windowIDUInt32 = UInt32(windowID)
        let qualityOption: CGSWindowCaptureOptions = (Defaults[.windowImageCaptureQuality] == .best) ? .bestResolution : .nominalResolution
        guard let capturedWindows = CGSHWCaptureWindowList(
            connectionID,
            &windowIDUInt32,
            1,
            [.ignoreGlobalClipShape, qualityOption]
        ) as? [CGImage],
            let capturedImage = capturedWindows.first
        else {
            throw captureError
        }
        cgImage = capturedImage

        // Only scale down if previewScale is greater than 1
        let previewScale = Int(Defaults[.windowPreviewImageScale])
        if previewScale > 1 {
            let newWidth = Int(cgImage.width) / previewScale
            let newHeight = Int(cgImage.height) / previewScale
            let colorSpace = cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = cgImage.bitmapInfo
            guard let context = CGContext(
                data: nil,
                width: newWidth,
                height: newHeight,
                bitsPerComponent: cgImage.bitsPerComponent,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: bitmapInfo.rawValue
            ) else {
                throw captureError
            }
            context.interpolationQuality = .high
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
            if let resizedImage = context.makeImage() {
                cgImage = resizedImage
            }
        }

        return cgImage
    }

    static func isValidElement(_ element: AXUIElement) -> Bool {
        do {
            let position = try element.position()
            let size = try element.size()
            if position != nil, size != nil {
                return true
            }
        } catch AxError.runtimeError {
            return false
        } catch {
            // Geometry check failed, fall through to AX windows list validation
        }

        do {
            if let pid = try element.pid() {
                let appElement = AXUIElementCreateApplication(pid)

                if let windows = try? appElement.windows() {
                    if let elementWindowId = try? element.cgWindowId() {
                        for window in windows {
                            if let windowId = try? window.cgWindowId(), windowId == elementWindowId {
                                return true
                            }
                        }
                    }

                    for window in windows {
                        if CFEqual(element, window) {
                            return true
                        }
                    }
                }
            }
        } catch {
            // Both checks failed
        }

        return false
    }

    static func findWindow(matchingWindow window: SCWindow, in axWindows: [AXUIElement]) -> AXUIElement? {
        if let matchedWindow = axWindows.first(where: { axWindow in
            (try? axWindow.cgWindowId()) == window.windowID
        }) {
            return matchedWindow
        }

        // Fallback metohd
        for axWindow in axWindows {
            if let windowTitle = window.title, let axTitle = try? axWindow.title(), isFuzzyMatch(windowTitle: windowTitle, axTitleString: axTitle) {
                return axWindow
            }

            if let axPosition = try? axWindow.position(), let axSize = try? axWindow.size(), axPosition != .zero, axSize != .zero {
                let positionThreshold: CGFloat = 10
                let sizeThreshold: CGFloat = 10

                let positionMatch = abs(axPosition.x - window.frame.origin.x) <= positionThreshold &&
                    abs(axPosition.y - window.frame.origin.y) <= positionThreshold

                let sizeMatch = abs(axSize.width - window.frame.size.width) <= sizeThreshold &&
                    abs(axSize.height - window.frame.size.height) <= sizeThreshold

                if positionMatch, sizeMatch {
                    return axWindow
                }
            }
        }

        return nil
    }

    static func isFuzzyMatch(windowTitle: String, axTitleString: String) -> Bool {
        let axTitleWords = axTitleString.lowercased().split(separator: " ")
        let windowTitleWords = windowTitle.lowercased().split(separator: " ")

        let matchingWords = axTitleWords.filter { windowTitleWords.contains($0) }
        let matchPercentage = Double(matchingWords.count) / Double(windowTitleWords.count)

        return matchPercentage >= 0.90 || matchPercentage.isNaN || axTitleString.lowercased().contains(windowTitle.lowercased())
    }

    static func findRunningApplicationByName(named applicationName: String) -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { $0.localizedName == applicationName }
    }

    static func toggleMinimize(windowInfo: WindowInfo) -> Bool? {
        if windowInfo.isMinimized {
            if windowInfo.app.isHidden {
                windowInfo.app.unhide()
            }
            do {
                try windowInfo.axElement.setAttribute(kAXMinimizedAttribute, false)
                windowInfo.app.activate()
                bringWindowToFront(windowInfo: windowInfo)
                return false
            } catch {
                return nil
            }
        } else {
            do {
                try windowInfo.axElement.setAttribute(kAXMinimizedAttribute, true)
                return true
            } catch {
                return nil
            }
        }
    }

    static func toggleHidden(windowInfo: WindowInfo) -> Bool? {
        let newHiddenState = !windowInfo.isHidden

        do {
            try windowInfo.appAxElement.setAttribute(kAXHiddenAttribute, newHiddenState)
            if !newHiddenState {
                windowInfo.app.activate()
                bringWindowToFront(windowInfo: windowInfo)
            }
            return newHiddenState
        } catch {
            print("Error toggling hidden state of application")
            return nil
        }
    }

    static func toggleFullScreen(windowInfo: WindowInfo) {
        if let isCurrentlyInFullScreen = try? windowInfo.axElement.isFullscreen() {
            do {
                try windowInfo.axElement.setAttribute(kAXFullscreenAttribute, !isCurrentlyInFullScreen)
            } catch {
                print("Failed to toggle full screen")
            }
        } else {
            print("Failed to determine current full screen state")
        }
    }

    static func bringWindowToFront(windowInfo: WindowInfo) {
        let maxRetries = 3
        var retryCount = 0

        func attemptActivation() -> Bool {
            do {
                // Use AltTab's approach: _SLPSSetFrontProcessWithOptions with userGenerated mode which
                //                        brings only the specific window forward, not all windows of the app
                var psn = ProcessSerialNumber()
                _ = GetProcessForPID(windowInfo.app.processIdentifier, &psn)
                _ = _SLPSSetFrontProcessWithOptions(&psn, UInt32(windowInfo.id), SLPSMode.userGenerated.rawValue)

                // Make the window key using raw event bytes (ported from Hammerspoon/AltTab)
                makeKeyWindow(&psn, windowID: windowInfo.id)

                try windowInfo.axElement.performAction(kAXRaiseAction)
                try windowInfo.axElement.setAttribute(kAXMainWindowAttribute, true)

                return true
            } catch {
                print("Attempt \(retryCount + 1) failed to bring window to front: \(error)")
                if error is AxError {
                    removeWindowFromDesktopSpaceCache(with: windowInfo.id, in: windowInfo.app.processIdentifier)
                }
                return false
            }
        }

        // Try activation with retries
        while retryCount < maxRetries {
            if attemptActivation() {
                // Optimistically update timestamp and leave breadcrumb
                updateTimestampOptimistically(for: windowInfo)
                return
            }
            retryCount += 1
            if retryCount < maxRetries {
                usleep(50000)
            }
        }

        print("Failed to bring window to front after \(maxRetries) attempts")
    }

    static func openNewWindow(app: NSRunningApplication) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x2D, keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.postToPid(app.processIdentifier)

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x2D, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.postToPid(app.processIdentifier)
    }

    static func closeWindow(windowInfo: WindowInfo) {
        guard windowInfo.closeButton != nil else {
            print("Error: closeButton is nil.")
            return
        }

        do {
            try windowInfo.closeButton?.performAction(kAXPressAction)
            removeWindowFromDesktopSpaceCache(with: windowInfo.id, in: windowInfo.app.processIdentifier)
        } catch {
            print("Error closing window")
            return
        }
    }

    static func quitApp(windowInfo: WindowInfo, force: Bool) {
        if force {
            windowInfo.app.forceTerminate()
        } else {
            windowInfo.app.terminate()
        }
        purgeAppCache(with: windowInfo.app.processIdentifier)
    }

    static func getAllWindowsOfAllApps() -> [WindowInfo] {
        let windows = desktopSpaceWindowCacheManager.getAllWindows()
        let filteredWindows = !Defaults[.includeHiddenWindowsInSwitcher]
            ? windows.filter { !$0.isHidden && !$0.isMinimized }
            : windows

        // Filter by frontmost app if enabled
        if Defaults[.limitSwitcherToFrontmostApp] {
            return getWindowsForFrontmostApp(from: filteredWindows)
        }

        return filteredWindows
    }

    static func getWindowsForFrontmostApp(from windows: [WindowInfo]) -> [WindowInfo] {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            return windows
        }

        return windows.filter { windowInfo in
            windowInfo.app.processIdentifier == frontmostApp.processIdentifier
        }
    }

    static func getActiveWindows(of app: NSRunningApplication) async throws -> [WindowInfo] {
        // Fetch SCK windows (visible windows only)
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        let group = LimitedTaskGroup<Void>(maxConcurrentTasks: 4)

        // Build set of SCK window IDs
        let sckWindowIDs = Set(content.windows.filter {
            $0.owningApplication?.processID == app.processIdentifier
        }.map(\.windowID))

        // Process SCK windows
        for window in content.windows where window.owningApplication?.processID == app.processIdentifier {
            await group.addTask { try await captureAndCacheWindowInfo(window: window, app: app) }
        }

        _ = try await group.waitForAll()

        // Discover non-SCK windows via AX (minimized, hidden, other spaces, or SCK-missed)
        await discoverNonSCKWindowsViaAX(app: app, sckWindowIDs: sckWindowIDs)

        // Purify cache and return
        if let finalWindows = await WindowUtil.purifyAppCache(with: app.processIdentifier, removeAll: false) {
            guard !Defaults[.ignoreAppsWithSingleWindow] || finalWindows.count > 1 else { return [] }
            return finalWindows.sorted(by: { $0.lastAccessedTime > $1.lastAccessedTime })
        }

        return []
    }

    private static func discoverNonSCKWindowsViaAX(app: NSRunningApplication, sckWindowIDs: Set<CGWindowID>) async {
        _ = await discoverWindowsViaAX(app: app, excludeWindowIDs: sckWindowIDs)
    }

    static func discoverWindowsViaAX(
        app: NSRunningApplication,
        excludeWindowIDs: Set<CGWindowID> = []
    ) async -> Int {
        let pid = app.processIdentifier

        guard let bundleId = app.bundleIdentifier, !filteredBundleIdentifiers.contains(bundleId) else {
            purgeAppCache(with: pid)
            return 0
        }

        let appName = app.localizedName ?? ""
        let appNameFilters = Defaults[.appNameFilters]
        if !appNameFilters.isEmpty, appNameFilters.contains(where: { appName.lowercased().contains($0.lowercased()) }) {
            purgeAppCache(with: pid)
            return 0
        }

        let appAX = AXUIElementCreateApplication(pid)
        let axWindows = AXUIElement.allWindows(pid, appElement: appAX)
        guard !axWindows.isEmpty else { return 0 }

        let group = LimitedTaskGroup<Void>(maxConcurrentTasks: 4)

        for axWin in axWindows {
            await group.addTask {
                try? await captureAndCacheAXWindowInfo(
                    axWindow: axWin,
                    appAxElement: appAX,
                    app: app,
                    excludeWindowIDs: excludeWindowIDs
                )
            }
        }

        _ = try? await group.waitForAll()

        return axWindows.count
    }

    static func updateNewWindowsForApp(_ app: NSRunningApplication) async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
            let group = LimitedTaskGroup<Void>(maxConcurrentTasks: 4)

            let appWindows = content.windows.filter { window in
                guard let scApp = window.owningApplication else { return false }
                return scApp.processID == app.processIdentifier
            }

            for window in appWindows {
                await group.addTask {
                    try? await captureAndCacheWindowInfo(window: window, app: app)
                }
            }

            _ = try await group.waitForAll()

        } catch {
            print("Error updating windows for \(app.localizedName ?? "unknown app"): \(error)")
        }

        // AX fallback: discover windows that SCK didn't report (e.g., some Adobe apps)
        await discoverNewWindowsViaAXFallback(app: app)
        // Ensure AX-fallback windows get fresh images too
        await refreshAXFallbackWindowImages(for: app.processIdentifier)
    }

    // MARK: - AX Fallback Discovery

    /// Discovers and caches windows via AX + CGS when SCK misses them (e.g., certain Adobe apps)
    private static func discoverNewWindowsViaAXFallback(app: NSRunningApplication) async {
        _ = await discoverWindowsViaAX(app: app)
    }

    static func updateAllWindowsInCurrentSpace() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
            var processedPIDs = Set<pid_t>()
            let group = LimitedTaskGroup<Void>(maxConcurrentTasks: 4)

            for window in content.windows {
                guard let scApp = window.owningApplication,
                      !filteredBundleIdentifiers.contains(scApp.bundleIdentifier)
                else { continue }

                if let nsApp = NSRunningApplication(processIdentifier: scApp.processID) {
                    processedPIDs.insert(nsApp.processIdentifier)
                    await group.addTask {
                        try? await captureAndCacheWindowInfo(window: window, app: nsApp)
                    }
                }
            }
            _ = try await group.waitForAll()

            // After processing windows, purify the cache for each app that had windows in the current space
            for pid in processedPIDs {
                _ = await purifyAppCache(with: pid, removeAll: false)
                // Refresh images for AX-fallback windows (not covered by SCK)
                await refreshAXFallbackWindowImages(for: pid)
            }

        } catch {
            print("Error updating windows: \(error)")
        }
    }

    /// Refresh images for windows discovered via AX fallback (no SCWindow available)
    private static func refreshAXFallbackWindowImages(for pid: pid_t) async {
        let windows = desktopSpaceWindowCacheManager.readCache(pid: pid)
        guard !windows.isEmpty else { return }

        let group = LimitedTaskGroup<Void>(maxConcurrentTasks: 4)

        for window in windows where window.scWindow == nil {
            // Skip invalid AX elements
            if !isValidElement(window.axElement) {
                desktopSpaceWindowCacheManager.removeFromCache(pid: pid, windowId: window.id)
                continue
            }

            await group.addTask {
                if let image = try? await captureWindowImage(windowID: window.id, pid: pid, windowTitle: window.windowName) {
                    var updated = window
                    updated.image = image
                    updated.spaceID = window.id.cgsSpaces().first.map { Int($0) }
                    updateDesktopSpaceWindowCache(with: updated)
                }
            }
        }

        _ = try? await group.waitForAll()
    }

    static func captureAndCacheWindowInfo(window: SCWindow, app: NSRunningApplication) async throws {
        let windowID = window.windowID

        guard window.owningApplication != nil,
              window.isOnScreen,
              window.windowLayer == 0,
              window.frame.size.width >= 100,
              window.frame.size.height >= 100
        else { return }

        guard let bundleId = app.bundleIdentifier else {
            purgeAppCache(with: app.processIdentifier)
            return
        }

        if filteredBundleIdentifiers.contains(bundleId) {
            purgeAppCache(with: app.processIdentifier)
            return
        }

        if let appName = app.localizedName {
            let appNameFilters = Defaults[.appNameFilters]
            if !appNameFilters.isEmpty {
                for filter in appNameFilters {
                    if appName.lowercased().contains(filter.lowercased()) {
                        purgeAppCache(with: app.processIdentifier)
                        return
                    }
                }
            }
        }

        if let windowTitle = window.title {
            let windowTitleFilters = Defaults[.windowTitleFilters]
            if !windowTitleFilters.isEmpty {
                for filter in windowTitleFilters {
                    if windowTitle.lowercased().contains(filter.lowercased()) {
                        removeWindowFromDesktopSpaceCache(with: windowID, in: app.processIdentifier)
                        return
                    }
                }
            }
        }

        desktopSpaceWindowCacheManager.updateCache(pid: app.processIdentifier) { windowSet in
            windowSet = windowSet.filter { cachedWindow in
                if let cachedTitle = cachedWindow.windowName {
                    for filter in Defaults[.windowTitleFilters] {
                        if cachedTitle.lowercased().contains(filter.lowercased()) {
                            return false
                        }
                    }
                }
                return true
            }
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        guard let axWindows = try? appElement.windows(), !axWindows.isEmpty else {
            return
        }

        guard let windowRef = findWindow(matchingWindow: window, in: axWindows) else {
            return
        }

        let closeButton = try? windowRef.closeButton()
        let minimizeButton = try? windowRef.minimizeButton()
        let shouldWindowBeCaptured = (closeButton != nil) || (minimizeButton != nil)

        if shouldWindowBeCaptured {
            var windowInfo = WindowInfo(
                windowProvider: window,
                app: app,
                image: nil,
                axElement: windowRef,
                appAxElement: appElement,
                closeButton: closeButton,
                lastAccessedTime: Date.now,
                spaceID: window.windowID.cgsSpaces().first.map { Int($0) }
            )

            if let image = try? await captureWindowImage(window: window) {
                windowInfo.image = image
                windowInfo.imageCapturedTime = Date()
            }
            updateDesktopSpaceWindowCache(with: windowInfo)
        }
    }

    static func captureAndCacheAXWindowInfo(
        axWindow: AXUIElement,
        appAxElement: AXUIElement,
        app: NSRunningApplication,
        excludeWindowIDs: Set<CGWindowID>
    ) async throws {
        let pid = app.processIdentifier

        guard isValidAXWindowCandidate(axWindow) else { return }

        let cgCandidates = getCGWindowCandidates(for: pid)
        let usedIDs = Set<CGWindowID>(desktopSpaceWindowCacheManager.readCache(pid: pid).map(\.id))

        var cgID: CGWindowID = 0
        if _AXUIElementGetWindow(axWindow, &cgID) == .success, cgID != 0 {
        } else if let mapped = mapAXToCG(axWindow: axWindow, candidates: cgCandidates, excluding: usedIDs) {
            cgID = mapped
        } else {
            return
        }

        guard !excludeWindowIDs.contains(cgID), !usedIDs.contains(cgID) else { return }

        guard isAtLeastNormalLevel(cgID) else { return }

        let titleFilters = Defaults[.windowTitleFilters]
        if !titleFilters.isEmpty {
            let cgTitle = cgID.cgsTitle() ?? ""
            if titleFilters.contains(where: { cgTitle.lowercased().contains($0.lowercased()) }) {
                return
            }
        }

        guard isValidCGWindowCandidate(cgID, in: cgCandidates) else { return }

        guard let cgEntry = findCGEntry(for: cgID, in: cgCandidates) else { return }

        let activeSpaceIDs = currentActiveSpaceIDs()
        guard shouldAcceptWindow(
            axWindow: axWindow,
            windowID: cgID,
            cgEntry: cgEntry,
            app: app,
            activeSpaceIDs: activeSpaceIDs,
            scBacked: false
        ) else { return }

        let windowTitle = cgID.cgsTitle()
        var info = WindowInfo(
            windowProvider: AXFallbackProvider(cgID: cgID),
            app: app,
            image: nil,
            axElement: axWindow,
            appAxElement: appAxElement,
            closeButton: try? axWindow.closeButton(),
            lastAccessedTime: Date(),
            spaceID: cgID.cgsSpaces().first.map { Int($0) }
        )
        info.windowName = windowTitle

        if let image = try? await captureWindowImage(windowID: cgID, pid: pid, windowTitle: windowTitle) {
            info.image = image
            info.imageCapturedTime = Date()
        }

        updateDesktopSpaceWindowCache(with: info)
    }

    static func updateDesktopSpaceWindowCache(with windowInfo: WindowInfo) {
        desktopSpaceWindowCacheManager.updateCache(pid: windowInfo.app.processIdentifier) { windowSet in
            if let matchingWindow = windowSet.first(where: { $0.axElement == windowInfo.axElement }) {
                var matchingWindowCopy = matchingWindow
                matchingWindowCopy.windowName = windowInfo.windowName
                matchingWindowCopy.image = windowInfo.image
                matchingWindowCopy.imageCapturedTime = windowInfo.imageCapturedTime
                matchingWindowCopy.spaceID = windowInfo.spaceID

                windowSet.remove(matchingWindow)
                windowSet.insert(matchingWindowCopy)
            } else {
                windowSet.insert(windowInfo)
            }
        }
    }

    static func removeWindowFromDesktopSpaceCache(with windowId: CGWindowID, in pid: pid_t) {
        desktopSpaceWindowCacheManager.removeFromCache(pid: pid, windowId: windowId)
    }

    static func removeWindowFromCache(with element: AXUIElement, in pid: pid_t) {
        if let windowId = try? element.cgWindowId() {
            removeWindowFromDesktopSpaceCache(with: windowId, in: pid)
        }
    }

    static func purifyAppCache(with pid: pid_t, removeAll: Bool) async -> Set<WindowInfo>? {
        if removeAll {
            desktopSpaceWindowCacheManager.writeCache(pid: pid, windowSet: [])
            return nil
        } else {
            let existingWindowsSet = desktopSpaceWindowCacheManager.readCache(pid: pid)
            if existingWindowsSet.isEmpty {
                return nil
            }

            var purifiedSet = existingWindowsSet
            for window in existingWindowsSet {
                if !isValidElement(window.axElement) {
                    purifiedSet.remove(window)
                    desktopSpaceWindowCacheManager.removeFromCache(pid: pid, windowId: window.id)
                }
            }
            return purifiedSet
        }
    }

    static func purgeAppCache(with pid: pid_t) {
        desktopSpaceWindowCacheManager.writeCache(pid: pid, windowSet: [])
    }

    /// Checks if the frontmost application is fullscreen and in the blacklist
    static func shouldIgnoreKeybindForFrontmostApp() -> Bool {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            return false
        }

        // Check if the app is in fullscreen mode
        let isFullscreen = isAppInFullscreen(frontmostApp)

        // Check if the app is in the blacklist
        let appName = frontmostApp.localizedName ?? ""
        let bundleIdentifier = frontmostApp.bundleIdentifier ?? ""
        let blacklist = Defaults[.fullscreenAppBlacklist]

        let isInBlacklist = blacklist.contains { blacklistEntry in
            appName.lowercased().contains(blacklistEntry.lowercased()) ||
                bundleIdentifier.lowercased().contains(blacklistEntry.lowercased())
        }

        return isFullscreen && isInBlacklist
    }

    /// Checks if the given application is currently in fullscreen mode
    static func isAppInFullscreen(_ app: NSRunningApplication) -> Bool {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        // Try to get the app's windows
        guard let windows = try? appElement.windows() else {
            return false
        }

        // Check if any window is in fullscreen mode
        for window in windows {
            if let isFullscreen = try? window.isFullscreen(), isFullscreen {
                return true
            }
        }

        return false
    }

    // MARK: - Private Helper Methods

    /// Makes a window key by posting raw event bytes to the Window Server
    /// Ported from https://github.com/Hammerspoon/hammerspoon/issues/370#issuecomment-545545468
    private static func makeKeyWindow(_ psn: inout ProcessSerialNumber, windowID: CGWindowID) {
        var bytes = [UInt8](repeating: 0, count: 0xF8)
        bytes[0x04] = 0xF8
        bytes[0x3A] = 0x10
        var wid = UInt32(windowID)
        memcpy(&bytes[0x3C], &wid, MemoryLayout<UInt32>.size)
        memset(&bytes[0x20], 0xFF, 0x10)
        bytes[0x08] = 0x01
        _ = SLPSPostEventRecordTo(&psn, &bytes)
        bytes[0x08] = 0x02
        _ = SLPSPostEventRecordTo(&psn, &bytes)
    }

    /// Updates window timestamp optimistically and records breadcrumb for observer deduplication
    private static func updateTimestampOptimistically(for windowInfo: WindowInfo) {
        guard Defaults[.sortWindowsByDate] else { return }

        let now = Date()
        desktopSpaceWindowCacheManager.updateCache(pid: windowInfo.app.processIdentifier) { windowSet in
            if let index = windowSet.firstIndex(where: { $0.axElement == windowInfo.axElement }) {
                var updatedWindow = windowSet[index]
                updatedWindow.lastAccessedTime = now
                windowSet.remove(at: index)
                windowSet.insert(updatedWindow)
            }
        }
    }

    /// Removes expired entries from timestamp tracking (must be called with lock held)
    private static func cleanupExpiredUpdates(currentTime: Date) {
        timestampUpdates = timestampUpdates.filter { _, date in
            currentTime.timeIntervalSince(date) < windowUpdateTimeWindow
        }
    }
}
