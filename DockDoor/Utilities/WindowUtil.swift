import ApplicationServices
import Cocoa
import Defaults
import ScreenCaptureKit

let filteredBundleIdentifiers: [String] = ["com.apple.notificationcenterui"] // filters desktop widgets

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
    var lastUsed: Date

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(app.bundleIdentifier ?? String(app.processIdentifier))
    }

    static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        lhs.id == rhs.id && lhs.app.processIdentifier == rhs.app.processIdentifier
    }
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

    static func captureWindowImage(window: SCWindow) async throws -> CGImage {
        clearExpiredCache()

        if let cachedImage = getCachedImage(window: window) {
            return cachedImage
        }

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()

        config.scalesToFit = false
        config.backgroundColor = .clear
        config.ignoreGlobalClipDisplay = true
        config.ignoreShadowsDisplay = true
        config.shouldBeOpaque = false
        if #available(macOS 14.2, *) { config.includeChildWindows = false }

        // Get the scale factor of the display containing the window
        let scaleFactor = await getScaleFactorForWindow(windowID: window.windowID)

        // Convert points to pixels
        config.width = Int(window.frame.width * scaleFactor) / Int(Defaults[.windowPreviewImageScale])
        config.height = Int(window.frame.height * scaleFactor) / Int(Defaults[.windowPreviewImageScale])

        config.showsCursor = false
        config.captureResolution = .best

        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)

        let cachedImage = CachedImage(image: image, timestamp: Date(), windowname: window.title)
        imageCache[window.windowID] = cachedImage

        return image
    }

    // Helper function to get the scale factor for a given window
    private static func getScaleFactorForWindow(windowID: CGWindowID) async -> CGFloat {
        await MainActor.run {
            guard let window = NSApplication.shared.window(withWindowNumber: Int(windowID)) else {
                return NSScreen.main?.backingScaleFactor ?? 2.0
            }

            if NSScreen.screens.count > 1 {
                if let currentScreen = window.screen {
                    return currentScreen.backingScaleFactor
                }
            }

            return NSScreen.main?.backingScaleFactor ?? 2.0
        }
    }

    private static func getCachedImage(window: SCWindow) -> CGImage? {
        if let cachedImage = imageCache[window.windowID], cachedImage.windowname == window.title, Date().timeIntervalSince(cachedImage.timestamp) <= cacheExpirySeconds {
            return cachedImage.image
        }
        return nil
    }

    static func isValidElement(_ element: AXUIElement) -> Bool {
        do {
            let _ = try element.role()
            return true
        } catch {
            return false
        }
    }

    static func findWindow(matchingWindow window: SCWindow, in axWindows: [AXUIElement]) -> AXUIElement? {
        for axWindow in axWindows {
            if let cgWindowId = try? axWindow.cgWindowId(), window.windowID == cgWindowId {
                return axWindow
            }

            // Fallback metohd
            // TODO: May never be needed

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

    static func toggleMinimize(windowInfo: WindowInfo) {
        if windowInfo.isMinimized {
            if windowInfo.app.isHidden {
                windowInfo.app.unhide()
            }

            do {
                try windowInfo.axElement.setAttribute(kAXMinimizedAttribute, false)
                windowInfo.app.activate()
                focusOnSpecificWindow(windowInfo: windowInfo)
            } catch {
                print("Error un-minimizing window")
            }
        } else {
            do {
                try windowInfo.axElement.setAttribute(kAXMinimizedAttribute, true)
            } catch {
                print("Error minimizing window")
            }
        }
        updateWindowDateTime(windowInfo)
    }

    static func toggleHidden(windowInfo: WindowInfo) {
        let newHiddenState = !windowInfo.isHidden

        do {
            try windowInfo.appAxElement.setAttribute(kAXHiddenAttribute, newHiddenState)
        } catch {
            print("Error toggling hidden state of application")
            return
        }

        if !newHiddenState {
            windowInfo.app.activate()
            focusOnSpecificWindow(windowInfo: windowInfo)
        }
        updateWindowDateTime(windowInfo)
    }

    static func focusOnSpecificWindow(windowInfo: WindowInfo) {
        guard let windows = try? windowInfo.appAxElement.windows() else {
            print("Failed to get windows for the application")
            return
        }

        for window in windows {
            if let title = try? window.title(), isFuzzyMatch(windowTitle: windowInfo.windowName ?? "", axTitleString: title) {
                try? window.performAction(kAXRaiseAction)
                try? window.setAttribute(kAXFocusedAttribute, true)
                return
            }
        }

        print("Failed to find and focus on the specific window")
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
        do {
            try windowInfo.axElement.performAction(kAXRaiseAction)
            try windowInfo.axElement.setAttribute(kAXFocusedAttribute, true)
            try? windowInfo.axElement.setAttribute(kAXFrontmostAttribute, true)
            if !windowInfo.app.activate() {
                throw NSError(domain: "FailedToActivate", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to activate application"])
            }

            updateWindowDateTime(windowInfo)
        } catch {
            print("Failed to bring window to front: \(error)")
            removeWindowFromDesktopSpaceCache(with: windowInfo.id, in: windowInfo.app.processIdentifier)
        }
    }

    static func updateWindowDateTime(_ windowInfo: WindowInfo) {
        desktopSpaceWindowCacheManager.updateCache(pid: windowInfo.app.processIdentifier) { windowSet in
            if let index = windowSet.firstIndex(where: { $0.id == windowInfo.id }) {
                var updatedWindow = windowSet[index]
                updatedWindow.lastUsed = Date()
                windowSet.remove(at: index)
                windowSet.insert(updatedWindow)
            }
        }
    }

    static func updateWindowDateTime(for app: NSRunningApplication) {
        desktopSpaceWindowCacheManager.updateCache(pid: app.processIdentifier) { windowSet in
            if windowSet.isEmpty {
                return
            }
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            if let windows = try? appElement.windows() {
                for window in windows {
                    if let cgWindowId = try? window.cgWindowId(), let index = windowSet.firstIndex(where: { $0.id == cgWindowId }) {
                        var updatedWindow = windowSet[index]
                        updatedWindow.lastUsed = Date()
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
        if let windows = try? appElement.windows() {
            desktopSpaceWindowCacheManager.updateCache(pid: pid) { cachedWindows in
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

                if isParentAppHidden {
                    cachedWindows = Set(cachedWindows.map { windowInfo in
                        var updatedWindow = windowInfo
                        updatedWindow.isHidden = true
                        return updatedWindow
                    })
                }
            }
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

        removeWindowFromDesktopSpaceCache(with: windowInfo.app.processIdentifier, removeAll: true)
    }

    // MARK: - Active Window Handling

    static func getAllWindowsOfAllApps() -> [WindowInfo] {
        let sortedWindows = desktopSpaceWindowCacheManager.getAllWindows()

        // If there are at least two windows, swap the first and second
        if sortedWindows.count >= 2 {
            var modifiedWindows = sortedWindows
            modifiedWindows.swapAt(0, 1)
            return modifiedWindows
        } else {
            return sortedWindows
        }
    }

    static func getActiveWindows(of app: NSRunningApplication) async throws -> [WindowInfo] {
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)

        let group = LimitedTaskGroup<WindowInfo?>(maxConcurrentTasks: 4)

        for window in content.windows where window.owningApplication?.processID == app.processIdentifier {
            await group.addTask {
                try await fetchWindowInfo(window: window, app: app)
            }
        }
        let results = try await group.waitForAll()
        let activeWindows = results.compactMap { $0 }

        let cachedWindows = desktopSpaceWindowCacheManager.readCache(pid: app.processIdentifier)
        var combinedWindows = activeWindows
        for cachedWindow in cachedWindows {
            if !combinedWindows.contains(where: { $0.id == cachedWindow.id }) {
                combinedWindows.append(cachedWindow)
            }
        }

        return combinedWindows.sorted(by: { $0.lastUsed > $1.lastUsed })
    }

    static func fetchWindowInfo(window: SCWindow, app: NSRunningApplication) async throws -> WindowInfo? {
        let windowID = window.windowID

        guard window.owningApplication != nil,
              window.isOnScreen,
              window.windowLayer == 0,
              window.frame.size.width >= 0,
              window.frame.size.height >= 0,
              app.bundleIdentifier == nil || !filteredBundleIdentifiers.contains(app.bundleIdentifier!),
              !(window.frame.size.width < 100 || window.frame.size.height < 100) || window.title?.isEmpty == false
        else {
            return nil
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        guard let axWindows = try? appElement.windows(), !axWindows.isEmpty else {
            return nil
        }

        guard let windowRef = findWindow(matchingWindow: window, in: axWindows) else {
            return nil
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
                                    lastUsed: Date())

        do {
            windowInfo.image = try await captureWindowImage(window: window)
            updateDesktopSpaceWindowCache(with: windowInfo)
            return windowInfo
        } catch {
            print("Error capturing window image: \(error)")
            return nil
        }
    }

    static func updateDesktopSpaceWindowCache(with windowInfo: WindowInfo) {
        desktopSpaceWindowCacheManager.updateCache(pid: windowInfo.app.processIdentifier) { windowSet in
            if let matchingWindow = windowSet.first(where: { $0.id == windowInfo.id }) {
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

    static func removeWindowFromDesktopSpaceCache(with pid: pid_t, removeAll: Bool) {
        if removeAll {
            desktopSpaceWindowCacheManager.writeCache(pid: pid, windowSet: [])
        } else {
            Task {
                let existingWindowsSet = desktopSpaceWindowCacheManager.readCache(pid: pid)
                if existingWindowsSet.isEmpty {
                    return
                }
                for window in existingWindowsSet {
                    if !isValidElement(window.axElement) {
                        desktopSpaceWindowCacheManager.removeFromCache(pid: pid, windowId: window.id)
                        return
                    }
                }
            }
        }
    }
}
