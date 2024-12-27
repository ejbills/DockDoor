import ApplicationServices
import Cocoa
import Defaults
import ScreenCaptureKit

let filteredBundleIdentifiers: [String] = ["com.apple.notificationcenterui", NSRunningApplication.current.bundleIdentifier!] // filters desktop widgets

struct WindowInfo: Identifiable, Hashable {
    let id: CGWindowID
    let window: SCWindow
    let app: NSRunningApplication
    var windowName: String?
    var image: CGImage?
    var axElement: AXUIElement
    var appAxElement: AXUIElement
    var closeButton: AXUIElement?
    var isMinimized: Bool
    var isHidden: Bool
    var date: Date

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(app.bundleIdentifier ?? String(app.processIdentifier))
    }

    static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        lhs.id == rhs.id &&
            lhs.app.processIdentifier == rhs.app.processIdentifier &&
            lhs.isMinimized == rhs.isMinimized &&
            lhs.isHidden == rhs.isHidden &&
            lhs.axElement == rhs.axElement
    }
}

enum WindowAction {
    case quit, close, minimize, toggleFullScreen, hide
}

struct CachedImage {
    let image: CGImage
    let timestamp: Date
    let windowname: String?
}

enum WindowUtil {
    private static var imageCache: [CGWindowID: CachedImage] = [:]
    private static let cacheQueue = DispatchQueue(label: "com.dockdoor.cacheQueue", attributes: .concurrent)
    private static var cacheExpirySeconds: Double = Defaults[.screenCaptureCacheLifespan]

    private static let desktopSpaceWindowCacheManager = SpaceWindowCacheManager()

    // MARK: - Cache Management

    static func clearExpiredCache() {
        let now = Date()
        cacheQueue.async(flags: .barrier) {
            imageCache = imageCache.filter { now.timeIntervalSince($0.value.timestamp) <= cacheExpirySeconds }
        }
    }

    static func resetCache() {
        cacheQueue.async(flags: .barrier) {
            imageCache.removeAll()
        }
    }

    static func clearWindowCache(for app: NSRunningApplication) {
        desktopSpaceWindowCacheManager.writeCache(pid: app.processIdentifier, windowSet: [])
    }

    static func updateWindowCache(for app: NSRunningApplication, update: @escaping (inout Set<WindowInfo>) -> Void) {
        desktopSpaceWindowCacheManager.updateCache(pid: app.processIdentifier, update: update)
    }

    // MARK: - Helper Functions

    /// Main function to capture a window image using ScreenCaptureKit, with fallback to legacy methods for older macOS versions.
    static func captureWindowImage(window: SCWindow, forceRefresh: Bool = false) async throws -> CGImage {
        clearExpiredCache()
        if let cachedImage = getCachedImage(window: window), !forceRefresh {
            return cachedImage
        }

        let captureError = NSError(
            domain: "WindowCaptureError",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Failed to create image for window"]
        )

        var cgImage: CGImage

        if forceRefresh {
            let connectionID = CGSMainConnectionID()
            var windowID = UInt32(window.windowID)

            guard let capturedWindows = CGSHWCaptureWindowList(
                connectionID,
                &windowID,
                1,
                0x0200 // kCGSWindowCaptureNominalResolution
            ) as? [CGImage],
                let capturedImage = capturedWindows.first
            else {
                throw captureError
            }
            cgImage = capturedImage
        } else {
            guard let windowImage = CGWindowListCreateImage(
                .null,
                .optionIncludingWindow,
                CGWindowID(window.windowID),
                [.bestResolution, .boundsIgnoreFraming]
            ) else {
                throw captureError
            }
            cgImage = windowImage
        }

        let previewScale = Int(Defaults[.windowPreviewImageScale])
        // Only scale down if previewScale is greater than 1
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

        let cachedImage = CachedImage(image: cgImage, timestamp: Date(), windowname: window.title)
        imageCache[window.windowID] = cachedImage
        return cgImage
    }

    private static func getCachedImage(window: SCWindow) -> CGImage? {
        if let cachedImage = imageCache[window.windowID], cachedImage.windowname == window.title, Date().timeIntervalSince(cachedImage.timestamp) <= cacheExpirySeconds {
            return cachedImage.image
        }
        return nil
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
                updateWindowDateTime(windowInfo)
                return false // Successfully un-minimized
            } catch {
                print("Error un-minimizing window")
                return nil
            }
        } else {
            do {
                try windowInfo.axElement.setAttribute(kAXMinimizedAttribute, true)
                updateWindowDateTime(windowInfo)
                return true // Successfully minimized
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
            updateWindowDateTime(windowInfo)
            return newHiddenState // Successfully toggled hidden state
        } catch {
            print("Error toggling hidden state of application")
            return nil // Failed to toggle hidden state
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
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate { // clean up lingering settings pane windows which interfere with AX actions
            appDelegate.settingsWindowController.close()
        }

        do {
            // Attempt to raise and focus the specific window
            try windowInfo.axElement.performAction(kAXRaiseAction)
            try windowInfo.axElement.performAction(kAXPressAction)
            try windowInfo.axElement.setAttribute(kAXMainAttribute, true)
            try windowInfo.axElement.setAttribute(kAXFocusedAttribute, true)
            try windowInfo.axElement.setAttribute(kAXFrontmostAttribute, true)

            if !windowInfo.app.activate() {
                // if individual windows cannot be activated, we activate and order forward the entire application
                try windowInfo.appAxElement.setAttribute(kAXFocusedAttribute, true)
                try windowInfo.appAxElement.setAttribute(kAXFrontmostAttribute, true)
                throw NSError(domain: "FailedToActivate", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to activate application"])
            }

            // If we've reached this point without throwing an error, consider it a success
            updateWindowDateTime(windowInfo)

        } catch {
            print("Failed to bring window to front: \(error)")
            // Check if the error is AxError.runtimeError
            if error is AxError {
                removeWindowFromDesktopSpaceCache(with: windowInfo.id, in: windowInfo.app.processIdentifier)
            }
        }
    }

    static func openNewWindow(app: NSRunningApplication) {
        let source = CGEventSource(stateID: .combinedSessionState)
        // Create keydown event for 'N'
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x2D, keyDown: true)
        // Add Command modifier
        keyDown?.flags = .maskCommand
        // Post the event to the application
        keyDown?.postToPid(app.processIdentifier)

        // Create keyup event
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x2D, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.postToPid(app.processIdentifier)
    }

    static func updateWindowDateTime(_ windowInfo: WindowInfo) {
        guard Defaults[.sortWindowsByDate] else { return }
        desktopSpaceWindowCacheManager.updateCache(pid: windowInfo.app.processIdentifier) { windowSet in
            if let index = windowSet.firstIndex(where: { $0.axElement == windowInfo.axElement }) {
                var updatedWindow = windowSet[index]
                updatedWindow.date = Date()
                windowSet.remove(at: index)
                windowSet.insert(updatedWindow)
            }
        }
    }

    static func updateWindowDateTime(for app: NSRunningApplication) {
        guard Defaults[.sortWindowsByDate] else { return }
        desktopSpaceWindowCacheManager.updateCache(pid: app.processIdentifier) { windowSet in
            if windowSet.isEmpty {
                return
            }
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            if let windows = try? appElement.windows() {
                for window in windows {
                    if let cgWindowId = try? window.cgWindowId(), let index = windowSet.firstIndex(where: { $0.id == cgWindowId }) {
                        var updatedWindow = windowSet[index]
                        updatedWindow.date = Date()
                        windowSet.remove(at: index)
                        windowSet.insert(updatedWindow)
                        return
                    }
                }
            }
        }
    }

    static func updateStatusOfWindowCache(pid: pid_t, isParentAppHidden: Bool) {
        let appElement = AXUIElementCreateApplication(pid)
        desktopSpaceWindowCacheManager.updateCache(pid: pid) { cachedWindows in
            if let windows = try? appElement.windows() {
                for window in windows {
                    if let cgWindowId = try? window.cgWindowId() {
                        let isMinimized: Bool = (try? window.isMinimized()) ?? false
                        cachedWindows = Set(cachedWindows.map { windowInfo in
                            var updatedWindow = windowInfo
                            if windowInfo.id == cgWindowId {
                                updatedWindow.isMinimized = isMinimized
                                updatedWindow.isHidden = isParentAppHidden
                            }
                            return updatedWindow
                        })
                    }
                }
            }

            // Always update for parent app hidden status, which can be blanket applied
            cachedWindows = Set(cachedWindows.map { windowInfo in
                var updatedWindow = windowInfo
                updatedWindow.isHidden = isParentAppHidden
                return updatedWindow
            })
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

    // MARK: - Active Window Handling

    static func getAllWindowsOfAllApps() -> [WindowInfo] {
        var windows = desktopSpaceWindowCacheManager.getAllWindows()

        if !Defaults[.includeHiddenWindowsInSwitcher] {
            windows = windows.filter { !$0.isHidden && !$0.isMinimized }
        }

        // If classic ordering is enabled and there are at least two windows,
        // swap the first and second windows
        if Defaults[.useClassicWindowOrdering], windows.count >= 2 {
            var modifiedWindows = windows
            modifiedWindows.swapAt(0, 1)
            return modifiedWindows
        }

        // Otherwise return natural date-based ordering
        return windows
    }

    static func getActiveWindows(of app: NSRunningApplication) async throws -> [WindowInfo] {
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

            // Process inactive windows
            for windowInfo in inactiveWindows {
                try await captureAndCacheWindowInfo(window: windowInfo.window, app: app, isMinimizedOrHidden: true)
            }

            // Get final window list with all updates
            let finalWindows = await WindowUtil.purifyAppCache(with: app.processIdentifier, removeAll: false) ?? []
            return finalWindows.sorted(by: { $0.date > $1.date })
        }

        return []
    }

    static func updateAllWindowsInCurrentSpace() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)

            let group = LimitedTaskGroup<Void>(maxConcurrentTasks: 4)

            for window in content.windows {
                guard let scApp = window.owningApplication,
                      !filteredBundleIdentifiers.contains(scApp.bundleIdentifier)
                else {
                    continue
                }

                // Convert SCRunningApplication to NSRunningApplication
                if let nsApp = NSRunningApplication(processIdentifier: scApp.processID) {
                    await group.addTask { try? await captureAndCacheWindowInfo(window: window, app: nsApp) }
                }
            }

            // Wait for all tasks to complete
            _ = try await group.waitForAll()

        } catch {
            print("Error updating windows: \(error)")
        }
    }

    static func captureAndCacheWindowInfo(window: SCWindow, app: NSRunningApplication, isMinimizedOrHidden: Bool = false) async throws {
        let windowID = window.windowID

        // If window is minimized/hidden, just take picture and update cache
        if isMinimizedOrHidden {
            if let existingWindow = desktopSpaceWindowCacheManager.readCache(pid: app.processIdentifier).first(where: { $0.id == windowID }) {
                var updatedWindow = existingWindow
                updatedWindow.image = try await captureWindowImage(window: window, forceRefresh: true)
                updateDesktopSpaceWindowCache(with: updatedWindow)
            }
            return
        }

        // Check basic window validity
        guard window.owningApplication != nil,
              window.isOnScreen,
              window.windowLayer == 0,
              window.frame.size.width >= 0,
              window.frame.size.height >= 0,
              !(window.frame.size.width < 100 || window.frame.size.height < 100) || window.title?.isEmpty == false
        else {
            return
        }

        // Check if app bundle ID is in filtered list
        if let bundleId = app.bundleIdentifier {
            if filteredBundleIdentifiers.contains(bundleId) {
                purgeAppCache(with: app.processIdentifier)
                return
            }
        }

        // Check if app name matches any filters
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

        // Check window title against filters and remove if matched
        if let windowTitle = window.title {
            let windowTitleFilters = Defaults[.windowTitleFilters]
            if !windowTitleFilters.isEmpty {
                for filter in windowTitleFilters {
                    if windowTitle.lowercased().contains(filter.lowercased()) {
                        // Remove this specific window if it exists in cache
                        removeWindowFromDesktopSpaceCache(with: windowID, in: app.processIdentifier)
                        return
                    }
                }
            }
        }

        // Additional check for existing windows in cache that might match filters
        desktopSpaceWindowCacheManager.updateCache(pid: app.processIdentifier) { windowSet in
            windowSet = windowSet.filter { cachedWindow in
                // Keep window only if it passes all filters
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

        var windowInfo = WindowInfo(id: windowID,
                                    window: window,
                                    app: app,
                                    windowName: window.title,
                                    image: nil,
                                    axElement: windowRef,
                                    appAxElement: appElement,
                                    closeButton: closeButton,
                                    isMinimized: false,
                                    isHidden: false,
                                    date: Date.now)

        do {
            windowInfo.image = try await captureWindowImage(window: window)
            updateDesktopSpaceWindowCache(with: windowInfo)
        } catch {
            print("Error capturing window image: \(error)")
        }
    }

    static func updateDesktopSpaceWindowCache(with windowInfo: WindowInfo) {
        desktopSpaceWindowCacheManager.updateCache(pid: windowInfo.app.processIdentifier) { windowSet in
            if let matchingWindow = windowSet.first(where: { $0.axElement == windowInfo.axElement }) {
                var matchingWindowCopy = matchingWindow
                matchingWindowCopy.windowName = windowInfo.windowName
                matchingWindowCopy.image = windowInfo.image
                matchingWindowCopy.isHidden = windowInfo.isHidden
                matchingWindowCopy.isMinimized = windowInfo.isMinimized
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
}
