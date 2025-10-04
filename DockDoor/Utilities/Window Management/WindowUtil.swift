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
    var isMinimized: Bool
    var isHidden: Bool
    var spaceID: Int?
    var lastAccessedTime: Date
    var lastImageCaptureTime: Date

    private var _scWindow: SCWindow?

    init(windowProvider: WindowPropertiesProviding, app: NSRunningApplication, image: CGImage?, axElement: AXUIElement, appAxElement: AXUIElement, closeButton: AXUIElement?, isMinimized: Bool, isHidden: Bool, lastAccessedTime: Date, lastImageCaptureTime: Date, spaceID: Int? = nil) {
        id = windowProvider.windowID
        self.windowProvider = windowProvider
        self.app = app
        windowName = windowProvider.title
        self.image = image
        self.axElement = axElement
        self.appAxElement = appAxElement
        self.closeButton = closeButton
        self.isMinimized = isMinimized
        self.isHidden = isHidden
        self.spaceID = spaceID
        self.lastAccessedTime = lastAccessedTime
        self.lastImageCaptureTime = lastImageCaptureTime
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
            lhs.isMinimized == rhs.isMinimized &&
            lhs.isHidden == rhs.isHidden &&
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
    private static var explicitTimestampUpdates: [AXUIElement: Date] = [:]
    private static let explicitUpdateLock = NSLock()
    private static let explicitUpdateTimeWindow: TimeInterval = 1.5

    static func clearWindowCache(for app: NSRunningApplication) {
        desktopSpaceWindowCacheManager.writeCache(pid: app.processIdentifier, windowSet: [])
    }

    static func updateWindowCache(for app: NSRunningApplication, update: @escaping (inout Set<WindowInfo>) -> Void) {
        desktopSpaceWindowCacheManager.updateCache(pid: app.processIdentifier, update: update)
    }

    static func updateWindowDateTime(element: AXUIElement, app: NSRunningApplication) {
        guard Defaults[.sortWindowsByDate] else { return }

        explicitUpdateLock.lock()
        defer { explicitUpdateLock.unlock() }

        // Check if this window was recently updated by bringWindowToFront
        let now = Date()
        if let lastExplicitUpdate = explicitTimestampUpdates[element],
           now.timeIntervalSince(lastExplicitUpdate) < explicitUpdateTimeWindow
        {
            // Clean up expired entries while we're here
            cleanupExpiredExplicitUpdates(currentTime: now)
            return // Skip update to avoid duplication
        }

        desktopSpaceWindowCacheManager.updateCache(pid: app.processIdentifier) { windowSet in
            if let index = windowSet.firstIndex(where: { $0.axElement == element }) {
                var updatedWindow = windowSet[index]
                updatedWindow.lastAccessedTime = now
                windowSet.remove(at: index)
                windowSet.insert(updatedWindow)
            }
        }
    }

    // MARK: - Helper Functions

    /// Main function to capture a window image using ScreenCaptureKit, with fallback to legacy methods for older macOS versions.
    static func captureWindowImage(window: SCWindow, forceRefresh: Bool = false) async throws -> (CGImage, Date) {
        // Check cache first if not forcing refresh
        if !forceRefresh {
            if let pid = window.owningApplication?.processID,
               let cachedWindow = desktopSpaceWindowCacheManager.readCache(pid: pid)
               .first(where: { $0.id == window.windowID && $0.windowName == window.title }),
               let cachedImage = cachedWindow.image
            {
                // Check if we need to refresh the image based on cache lifespan
                let cacheLifespan = Defaults[.screenCaptureCacheLifespan]
                if Date().timeIntervalSince(cachedWindow.lastImageCaptureTime) <= cacheLifespan {
                    return (cachedImage, cachedWindow.lastImageCaptureTime)
                }

                // If we reach here, the image is stale and needs refreshing
                // but we keep the WindowInfo in cache
            }
        }

        let captureError = NSError(
            domain: "WindowCaptureError",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Failed to create image for window"]
        )

        var cgImage: CGImage
        let connectionID = CGSMainConnectionID()
        var windowID = UInt32(window.windowID)
        let qualityOption: CGSWindowCaptureOptions = (Defaults[.windowImageCaptureQuality] == .best) ? .bestResolution : .nominalResolution
        guard let capturedWindows = CGSHWCaptureWindowList(
            connectionID,
            &windowID,
            1,
            [qualityOption, CGSWindowCaptureOptions.fullSize]
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

        return (cgImage, Date.now)
    }

    static func isValidElement(_ element: AXUIElement) -> Bool {
        do {
            // Try to get the window's position
            let position = try element.position()

            // Try to get the window's size
            let size = try element.size()

            // If we can get both position and size, the window likely still exists
            return position != nil && size != nil
        } catch AxError.runtimeError {
            // If we get a runtime error, the app might be unresponsive, so we consider the element invalid
            return false
        } catch {
            // For any other errors, we also consider the element invalid
            return false
        }
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
                print("Error un-minimizing window")
                return nil
            }
        } else {
            do {
                try windowInfo.axElement.setAttribute(kAXMinimizedAttribute, true)
                return true
            } catch {
                print("Error minimizing window")
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
        // Clean up lingering settings pane windows which interfere with AX actions (must be on main thread)
        DispatchQueue.main.async {
            if let appDelegate = NSApplication.shared.delegate as? AppDelegate,
               windowInfo.app.localizedName != "DockDoor"
            {
                appDelegate.settingsWindowController.close()
            }
        }

        let maxRetries = 3
        var retryCount = 0

        func attemptActivation() -> Bool {
            do {
                windowInfo.app.activate()

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

    static func updateStatusOfWindowCache(pid: pid_t, isParentAppHidden: Bool) {
        let appElement = AXUIElementCreateApplication(pid)
        desktopSpaceWindowCacheManager.updateCache(pid: pid) { windowSet in
            guard let axWindows = try? appElement.windows() else {
                // Still apply parent hidden flag
                windowSet = Set(windowSet.map { var w = $0; w.isHidden = isParentAppHidden; return w })
                return
            }

            for ax in axWindows {
                let isMin = (try? ax.isMinimized()) ?? false
                guard let cgId = ((try? ax.cgWindowId()) ?? nil) else { continue }
                if let existing = windowSet.first(where: { $0.id == cgId }) {
                    var updated = existing
                    updated.isMinimized = isMin
                    updated.isHidden = isParentAppHidden
                    windowSet.remove(existing)
                    windowSet.insert(updated)
                }
            }

            // Ensure hidden state is applied universally (legacy behavior)
            windowSet = Set(windowSet.map { var w = $0; w.isHidden = isParentAppHidden; return w })
        }
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
        let windows = desktopSpaceWindowCacheManager.getAllWindows(showOldestWindowsFirst: Defaults[.showOldestWindowsFirst])
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

    static func getActiveWindows(of app: NSRunningApplication, showOldestWindowsFirst: Bool) async throws -> [WindowInfo] {
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        let group = LimitedTaskGroup<Void>(maxConcurrentTasks: 4)

        let activeWindowIDs = content.windows.filter {
            $0.owningApplication?.processID == app.processIdentifier
        }.map(\.windowID)

        for window in content.windows where window.owningApplication?.processID == app.processIdentifier {
            await group.addTask { try await captureAndCacheWindowInfo(window: window, app: app) }
        }

        _ = try await group.waitForAll()

        if let purifiedWindows = await WindowUtil.purifyAppCache(with: app.processIdentifier, removeAll: false) {
            guard !Defaults[.ignoreAppsWithSingleWindow] || purifiedWindows.count > 1 else { return [] }

            let inactiveWindows = purifiedWindows.filter {
                !activeWindowIDs.contains($0.id) && ($0.isMinimized || $0.isHidden)
            }

            for windowInfo in inactiveWindows {
                if let scWin = windowInfo.scWindow {
                    try await captureAndCacheWindowInfo(window: scWin, app: app, isMinimizedOrHidden: true)
                }
            }

            var finalWindows = await WindowUtil.purifyAppCache(with: app.processIdentifier, removeAll: false) ?? []

            // Ensure AX-fallback windows (no SCWindow) get refreshed images on hover
            let lifespan = Defaults[.screenCaptureCacheLifespan]
            let now = Date()
            let toRefresh = finalWindows.filter { $0.scWindow == nil && ($0.image == nil || now.timeIntervalSince($0.lastImageCaptureTime) > lifespan) }
            if !toRefresh.isEmpty {
                for window in toRefresh {
                    if let image = window.id.cgsScreenshot() {
                        var updated = window
                        updated.image = image
                        updated.spaceID = spaceIDForWindowID(window.id)
                        updated.lastImageCaptureTime = Date.now
                        updateDesktopSpaceWindowCache(with: updated)
                    }
                }
                finalWindows = desktopSpaceWindowCacheManager.readCache(pid: app.processIdentifier)
            }

            // Also sync minimized/hidden state for AX-fallback windows from AX attributes
            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            if let axWindows = try? axApp.windows() {
                var updatedAny = false
                for ax in axWindows {
                    guard let cgId = ((try? ax.cgWindowId()) ?? nil) else { continue }
                    let isMin = (try? ax.isMinimized()) ?? false
                    desktopSpaceWindowCacheManager.updateCache(pid: app.processIdentifier) { set in
                        if let existing = set.first(where: { $0.id == cgId && $0.scWindow == nil }) {
                            if existing.isMinimized != isMin || existing.isHidden != app.isHidden {
                                var u = existing
                                u.isMinimized = isMin
                                u.isHidden = app.isHidden
                                set.remove(existing)
                                set.insert(u)
                                updatedAny = true
                            }
                        }
                    }
                }
                if updatedAny {
                    finalWindows = desktopSpaceWindowCacheManager.readCache(pid: app.processIdentifier)
                }
            }

            let sortOrder: (WindowInfo, WindowInfo) -> Bool = showOldestWindowsFirst
                ? { $0.lastAccessedTime < $1.lastAccessedTime }
                : { $0.lastAccessedTime > $1.lastAccessedTime }

            return finalWindows.sorted(by: sortOrder)
        }

        return []
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
        discoverNewWindowsViaAXFallback(app: app)
        // Ensure AX-fallback windows get fresh images too
        refreshAXFallbackWindowImages(for: app.processIdentifier)
    }

    // MARK: - AX Fallback Discovery

    /// Discovers and caches windows via AX + CGS when SCK misses them (e.g., certain Adobe apps)
    private static func discoverNewWindowsViaAXFallback(app: NSRunningApplication) {
        let pid = app.processIdentifier

        // Respect basic filters to avoid polluting cache
        guard let bundleId = app.bundleIdentifier, !filteredBundleIdentifiers.contains(bundleId) else {
            purgeAppCache(with: pid)
            return
        }

        let appName = app.localizedName ?? ""
        let appNameFilters = Defaults[.appNameFilters]
        if !appNameFilters.isEmpty, appNameFilters.contains(where: { appName.lowercased().contains($0.lowercased()) }) {
            purgeAppCache(with: pid)
            return
        }

        let appAX = AXUIElementCreateApplication(pid)
        let axWindows = AXUIElement.allWindows(pid, appElement: appAX)
        if axWindows.isEmpty { return }

        // Build CG candidates for this PID on layer 0
        let cgAll = (CGWindowListCopyWindowInfo([.excludeDesktopElements], kCGNullWindowID) as? [[String: AnyObject]]) ?? []
        let cgCandidates = cgAll.filter { desc in
            let owner = (desc[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value ?? 0
            let layer = (desc[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0
            return owner == pid && layer == 0
        }

        // Avoid re-adding existing windows
        var usedIDs = Set<CGWindowID>(desktopSpaceWindowCacheManager.readCache(pid: pid).map(\.id))
        let activeSpaceIDs = currentActiveSpaceIDs()

        for axWin in axWindows {
            if !isValidAXWindowCandidate(axWin) { continue }
            var cgID: CGWindowID = 0
            if _AXUIElementGetWindow(axWin, &cgID) == .success, cgID != 0 {
            } else if let mapped = mapAXToCG(axWindow: axWin, candidates: cgCandidates, excluding: usedIDs) {
                cgID = mapped
            } else {
                continue
            }

            if usedIDs.contains(cgID) { continue }

            // Basic sanity: only normal and above
            if !isAtLeastNormalLevel(cgID) { continue }

            // Optional title filtering
            let titleFilters = Defaults[.windowTitleFilters]
            if !titleFilters.isEmpty {
                let cgTitle = cgID.cgsTitle() ?? ""
                if titleFilters.contains(where: { cgTitle.lowercased().contains($0.lowercased()) }) {
                    continue
                }
            }

            if !isValidCGWindowCandidate(cgID, in: cgCandidates) { continue }

            // Find matching CG entry for visibility flags
            guard let cgEntry = cgCandidates.first(where: { desc in
                let wid = CGWindowID((desc[kCGWindowNumber as String] as? NSNumber)?.uint32Value ?? 0)
                return wid == cgID
            }) else { continue }

            // Accept window if on-screen, SCK-backed (false here), in other Space, or minimized/fullscreen/hidden
            let scBacked = false
            if !shouldAcceptWindow(axWindow: axWin, windowID: cgID, cgEntry: cgEntry, app: app, activeSpaceIDs: activeSpaceIDs, scBacked: scBacked) {
                continue
            }

            // Capture image via CGS (works even if SCK missed it)
            guard let image = cgID.cgsScreenshot() else { continue }

            let provider = AXFallbackProvider(cgID: cgID)
            var info = WindowInfo(
                windowProvider: provider,
                app: app,
                image: image,
                axElement: axWin,
                appAxElement: appAX,
                closeButton: try? axWin.closeButton(),
                isMinimized: (try? axWin.isMinimized()) ?? false,
                isHidden: app.isHidden,
                lastAccessedTime: Date.now,
                lastImageCaptureTime: Date.now,
                spaceID: spaceIDForWindowID(cgID)
            )
            info.windowName = cgID.cgsTitle()
            updateDesktopSpaceWindowCache(with: info)
            usedIDs.insert(cgID)
        }
    }

    static func updateAllWindowsInCurrentSpace() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
            var processedPIDs = Set<pid_t>()

            await withTaskGroup(of: Void.self) { group in
                var processedCount = 0
                let maxConcurrentTasks = 4

                for window in content.windows {
                    guard let scApp = window.owningApplication,
                          !filteredBundleIdentifiers.contains(scApp.bundleIdentifier)
                    else { continue }

                    if processedCount >= maxConcurrentTasks {
                        await group.next()
                        processedCount -= 1
                    }

                    if let nsApp = NSRunningApplication(processIdentifier: scApp.processID) {
                        processedPIDs.insert(nsApp.processIdentifier)
                        group.addTask {
                            try? await captureAndCacheWindowInfo(window: window, app: nsApp)
                        }
                        processedCount += 1
                    }
                }
                await group.waitForAll()
            }

            // After processing windows, purify the cache for each app that had windows in the current space
            for pid in processedPIDs {
                _ = await purifyAppCache(with: pid, removeAll: false)
                // Refresh images for AX-fallback windows (not covered by SCK)
                refreshAXFallbackWindowImages(for: pid)
            }

        } catch {
            print("Error updating windows: \(error)")
        }
    }

    /// Refresh images for windows discovered via AX fallback (no SCWindow available)
    private static func refreshAXFallbackWindowImages(for pid: pid_t) {
        let windows = desktopSpaceWindowCacheManager.readCache(pid: pid)
        guard !windows.isEmpty else { return }

        for window in windows where window.scWindow == nil {
            // Skip invalid AX elements
            if !isValidElement(window.axElement) {
                desktopSpaceWindowCacheManager.removeFromCache(pid: pid, windowId: window.id)
                continue
            }

            if let image = window.id.cgsScreenshot() {
                var updated = window
                updated.image = image
                updated.lastImageCaptureTime = Date.now
                updated.spaceID = spaceIDForWindowID(window.id)
                updateDesktopSpaceWindowCache(with: updated)
            }
        }
    }

    static func captureAndCacheWindowInfo(window: SCWindow, app: NSRunningApplication, isMinimizedOrHidden: Bool = false) async throws {
        let windowID = window.windowID

        if isMinimizedOrHidden {
            if let existingWindow = desktopSpaceWindowCacheManager.readCache(pid: app.processIdentifier).first(where: { $0.id == windowID }),
               let actualSCWindow = existingWindow.scWindow
            {
                let updatedWindow = existingWindow
                await Task.detached(priority: .userInitiated) {
                    if let (image, imageDate) = try? await captureWindowImage(window: actualSCWindow, forceRefresh: true) {
                        var mutableCopy = updatedWindow
                        mutableCopy.image = image
                        mutableCopy.lastImageCaptureTime = imageDate
                        updateDesktopSpaceWindowCache(with: mutableCopy)
                    }
                }.value
            }
            return
        }

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
            let windowInfo = WindowInfo(
                windowProvider: window,
                app: app,
                image: nil,
                axElement: windowRef,
                appAxElement: appElement,
                closeButton: closeButton,
                isMinimized: false,
                isHidden: false,
                lastAccessedTime: Date.now,
                lastImageCaptureTime: Date.distantPast,
                spaceID: WindowUtil.spaceIDForWindowID(window.windowID)
            )

            await Task.detached(priority: .userInitiated) {
                if let (image, imageDate) = try? await captureWindowImage(window: window) {
                    var mutableCopy = windowInfo
                    mutableCopy.image = image
                    mutableCopy.lastImageCaptureTime = imageDate
                    updateDesktopSpaceWindowCache(with: mutableCopy)
                }
            }.value
        }
    }

    static func updateDesktopSpaceWindowCache(with windowInfo: WindowInfo) {
        desktopSpaceWindowCacheManager.updateCache(pid: windowInfo.app.processIdentifier) { windowSet in
            if let matchingWindow = windowSet.first(where: { $0.axElement == windowInfo.axElement }) {
                var matchingWindowCopy = matchingWindow
                matchingWindowCopy.windowName = windowInfo.windowName
                matchingWindowCopy.image = windowInfo.image
                matchingWindowCopy.lastImageCaptureTime = windowInfo.lastImageCaptureTime
                matchingWindowCopy.isHidden = windowInfo.isHidden
                matchingWindowCopy.isMinimized = windowInfo.isMinimized
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

    // Map a CGWindowID to its Space via private CGS
    static func spaceIDForWindowID(_ id: CGWindowID) -> Int? {
        let arr: CFArray = [NSNumber(value: UInt32(id))] as CFArray
        guard let spaces = CGSCopySpacesForWindows(CGSMainConnectionID(), kCGSAllSpacesMask, arr) as NSArray? else { return nil }
        if let first = spaces.firstObject as? NSNumber { return first.intValue }
        return nil
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

    /// Updates window timestamp optimistically and records breadcrumb for observer deduplication
    private static func updateTimestampOptimistically(for windowInfo: WindowInfo) {
        guard Defaults[.sortWindowsByDate] else { return }

        let now = Date()

        // Record breadcrumb for observer deduplication
        explicitUpdateLock.lock()
        explicitTimestampUpdates[windowInfo.axElement] = now
        explicitUpdateLock.unlock()

        // Update timestamp in cache
        desktopSpaceWindowCacheManager.updateCache(pid: windowInfo.app.processIdentifier) { windowSet in
            if let index = windowSet.firstIndex(where: { $0.axElement == windowInfo.axElement }) {
                var updatedWindow = windowSet[index]
                updatedWindow.lastAccessedTime = now
                windowSet.remove(at: index)
                windowSet.insert(updatedWindow)
            }
        }
    }

    /// Removes expired entries from explicit timestamp tracking (must be called with lock held)
    private static func cleanupExpiredExplicitUpdates(currentTime: Date) {
        explicitTimestampUpdates = explicitTimestampUpdates.filter { _, date in
            currentTime.timeIntervalSince(date) < explicitUpdateTimeWindow
        }
    }
}
