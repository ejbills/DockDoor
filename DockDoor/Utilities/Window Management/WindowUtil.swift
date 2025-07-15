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
    var lastAccessedTime: Date

    private var _scWindow: SCWindow?

    init(windowProvider: WindowPropertiesProviding, app: NSRunningApplication, image: CGImage?, axElement: AXUIElement, appAxElement: AXUIElement, closeButton: AXUIElement?, isMinimized: Bool, isHidden: Bool, lastAccessedTime: Date) {
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
        self.lastAccessedTime = lastAccessedTime
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

    static func clearWindowCache(for app: NSRunningApplication) {
        desktopSpaceWindowCacheManager.writeCache(pid: app.processIdentifier, windowSet: [])
    }

    static func updateWindowCache(for app: NSRunningApplication, update: @escaping (inout Set<WindowInfo>) -> Void) {
        desktopSpaceWindowCacheManager.updateCache(pid: app.processIdentifier, update: update)
    }

    static func updateWindowDateTime(element: AXUIElement, app: NSRunningApplication) {
        guard Defaults[.sortWindowsByDate] else { return }
        desktopSpaceWindowCacheManager.updateCache(pid: app.processIdentifier) { windowSet in
            if let index = windowSet.firstIndex(where: { $0.axElement == element }) {
                var updatedWindow = windowSet[index]
                updatedWindow.lastAccessedTime = Date()
                windowSet.remove(at: index)
                windowSet.insert(updatedWindow)
            }
        }
    }

    // MARK: - Helper Functions

    /// Main function to capture a window image using ScreenCaptureKit, with fallback to legacy methods for older macOS versions.
    static func captureWindowImage(window: SCWindow, forceRefresh: Bool = false) async throws -> CGImage {
        // Check cache first if not forcing refresh
        if !forceRefresh {
            if let pid = window.owningApplication?.processID,
               let cachedWindow = desktopSpaceWindowCacheManager.readCache(pid: pid)
               .first(where: { $0.id == window.windowID && $0.windowName == window.title }),
               let cachedImage = cachedWindow.image
            {
                // Check if we need to refresh the image based on cache lifespan
                let cacheLifespan = Defaults[.screenCaptureCacheLifespan]
                if Date().timeIntervalSince(cachedWindow.lastAccessedTime) <= cacheLifespan {
                    return cachedImage
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
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate, windowInfo.app.localizedName != "DockDoor" { // clean up lingering settings pane windows which interfere with AX actions
            appDelegate.settingsWindowController.close()
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

            let finalWindows = await WindowUtil.purifyAppCache(with: app.processIdentifier, removeAll: false) ?? []
            return finalWindows.sorted(by: { $0.lastAccessedTime > $1.lastAccessedTime })
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
            }

        } catch {
            print("Error updating windows: \(error)")
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
                    if let image = try? await captureWindowImage(window: actualSCWindow, forceRefresh: true) {
                        var mutableCopy = updatedWindow
                        mutableCopy.image = image
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
                lastAccessedTime: Date.now
            )

            await Task.detached(priority: .userInitiated) {
                if let image = try? await captureWindowImage(window: window) {
                    var mutableCopy = windowInfo
                    mutableCopy.image = image
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
}
