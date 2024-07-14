//
//  WindowManager.swift
//  DockDoor
//
//  Created by Ethan Bills on 6/3/24.
//

import Cocoa
import ApplicationServices
import ScreenCaptureKit
import Defaults

let filteredBundleIdentifiers: [String] = ["com.apple.notificationcenterui"] // filters widgets

/// Struct representing window information.
struct WindowInfo: Identifiable, Hashable {
    let id: CGWindowID
    let window: SCWindow?
    let appName: String
    let bundleID: String
    let pid: pid_t
    let windowName: String?
    var image: CGImage?
    var axElement: AXUIElement
    var closeButton: AXUIElement?
    let isMinimized: Bool
    let isHidden: Bool
}

/// Cache item structure for storing captured window images.
struct CachedImage {
    let image: CGImage
    let timestamp: Date
}

/// Cache item structure for storing app icons.
struct CachedAppIcon {
    let icon: NSImage
    let timestamp: Date
}

final class WindowUtil {
    private static var imageCache: [CGWindowID: CachedImage] = [:]
    private static let cacheQueue = DispatchQueue(label: "com.dockdoor.cacheQueue", attributes: .concurrent)
    private static var cacheExpirySeconds: Double = Defaults[.screenCaptureCacheLifespan]
    private static var desktopSpaceWindowCache: [String: Set<WindowInfo>] = [:]
    private static var appNameBundleIdTracker: [String: String] = [:]
    
    // MARK: - Cache Management
    
    /// Clears expired cache items based on cache expiry time.
    static func clearExpiredCache() {
        let now = Date()
        cacheQueue.async(flags: .barrier) {
            imageCache = imageCache.filter { now.timeIntervalSince($0.value.timestamp) <= cacheExpirySeconds }
        }
    }
    
    /// Resets the image and icon cache.
    static func resetCache() {
        cacheQueue.async(flags: .barrier) {
            imageCache.removeAll()
        }
    }
    
    // MARK: - Helper Functions
    
    /// Captures the image of a given window.
    static func captureWindowImage(window: SCWindow) async throws -> CGImage {
        clearExpiredCache()
        
        if let cachedImage = getCachedImage(window: window) {
            return cachedImage
        }
        
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        
        // Configure the stream to capture only the window content
        config.scalesToFit = false
        config.backgroundColor = .clear
        config.ignoreGlobalClipDisplay = true
        config.ignoreShadowsDisplay = true
        config.shouldBeOpaque = false
        if #available(macOS 14.2, *) { config.includeChildWindows = false }
        config.width = Int(window.frame.width)
        config.height = Int(window.frame.height)
        config.showsCursor = false
        config.captureResolution = .best
        
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        
        let cachedImage = CachedImage(image: image, timestamp: Date())
        imageCache[window.windowID] = cachedImage
        
        return image
    }
    
    private static func getCachedImage(window: SCWindow) -> CGImage? {
        if let cachedImage = imageCache[window.windowID], Date().timeIntervalSince(cachedImage.timestamp) <= cacheExpirySeconds {
            return cachedImage.image
        }
        return nil
    }
    
    /// Creates an AXUIElement for a given process ID.
    static func createAXUIElement(for pid: pid_t) -> AXUIElement {
        return AXUIElementCreateApplication(pid)
    }
    
    /// Retrieves the AXUIElement windows for an application reference.
    static func getAXWindows(for appRef: AXUIElement) -> [AXUIElement]? {
        var windowList: AnyObject?
        let result = AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowList)
        return result == .success ? windowList as? [AXUIElement] : nil
    }
    
    /// Finds a window by its name in the provided AXUIElement windows.
    static func findWindow(matchingWindow window: SCWindow, in axWindows: [AXUIElement]) -> AXUIElement? {
        for axWindow in axWindows {
            var cgWindowId: CGWindowID = 0
            let windowIDStatus = _AXUIElementGetWindow(axWindow, &cgWindowId)
            if windowIDStatus == .success && window.windowID == cgWindowId {
                return axWindow
            }
            
            var axTitle: CFTypeRef?
            AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &axTitle)
            let axTitleString = (axTitle as? String) ?? ""
            
            var axPosition: CFTypeRef?
            AXUIElementCopyAttributeValue(axWindow, kAXPositionAttribute as CFString, &axPosition)
            let axPositionValue = axPosition as? CGPoint
            
            var axSize: CFTypeRef?
            AXUIElementCopyAttributeValue(axWindow, kAXSizeAttribute as CFString, &axSize)
            let axSizeValue = axSize as? CGSize
            
            // Use the new isFuzzyMatch function for title matching
            if let windowTitle = window.title, isFuzzyMatch(windowTitle: windowTitle, axTitleString: axTitleString) {
                return axWindow
            }
            
            // Position and size matching (if available and non-zero)
            if let axPositionValue = axPositionValue,
               let axSizeValue = axSizeValue,
               axPositionValue != .zero,
               axSizeValue != .zero {
                
                let positionThreshold: CGFloat = 10  // Allow for small discrepancies in position
                let sizeThreshold: CGFloat = 10  // Allow for small discrepancies in size
                
                let positionMatch = abs(axPositionValue.x - window.frame.origin.x) <= positionThreshold &&
                abs(axPositionValue.y - window.frame.origin.y) <= positionThreshold
                
                let sizeMatch = abs(axSizeValue.width - window.frame.size.width) <= sizeThreshold &&
                abs(axSizeValue.height - window.frame.size.height) <= sizeThreshold
                
                if positionMatch && sizeMatch {
                    return axWindow
                }
            }
        }
        
        print("No matching AX window found")
        return nil
    }
    
    /// Fuzzy title matching
    static func isFuzzyMatch(windowTitle: String, axTitleString: String) -> Bool {
        let axTitleWords = axTitleString.lowercased().split(separator: " ")
        let windowTitleWords = windowTitle.lowercased().split(separator: " ")
        
        let matchingWords = axTitleWords.filter { windowTitleWords.contains($0) }
        let matchPercentage = Double(matchingWords.count) / Double(windowTitleWords.count)
        
        return matchPercentage >= 0.90 || matchPercentage.isNaN || axTitleString.lowercased().contains(windowTitle.lowercased())
    }
    
    /// Retrieves the close button for a given window reference.
    static func getCloseButton(for windowRef: AXUIElement) -> AXUIElement? {
        var closeButton: AnyObject?
        let result = AXUIElementCopyAttributeValue(windowRef, kAXCloseButtonAttribute as CFString, &closeButton)
        
        // Ensure the result is success and closeButton is not nil
        guard result == .success, let closeButtonElement = closeButton else {
            return nil
        }
        
        return (closeButtonElement as! AXUIElement)
    }
    
    /// Retrieves the running application by its name.
    static func getRunningApplication(named applicationName: String) -> NSRunningApplication? {
        return NSWorkspace.shared.runningApplications.first {
            applicationName.contains($0.localizedName ?? "") || ($0.localizedName?.contains(applicationName) ?? false)
        }
    }
    
    private static func getAllWindowInfosAsList() -> [WindowInfo] {
        return Array(desktopSpaceWindowCache.values.joined())
    }
    
    // MARK: - Window Manipulation Functions
    
    /// Toggles the minimize state of a window.
    static func toggleMinimize(windowInfo: WindowInfo) {
        if windowInfo.isMinimized {
            // Check if the parent app is hidden
            if let app = NSRunningApplication(processIdentifier: windowInfo.pid), app.isHidden {
                // Unhide the entire app
                app.unhide()
            }
            
            // Un-minimize the window
            let minimizeResult = AXUIElementSetAttributeValue(windowInfo.axElement, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            
            if minimizeResult != .success {
                print("Error un-minimizing window: \(minimizeResult.rawValue)")
                //                if let (key, index) = findKeyAndIndex(for: windowInfo.id) {
                //                    deleteWindowFromListUsingKeyIndex(key, index)
                //                }
            } else {
                NSRunningApplication(processIdentifier: windowInfo.pid)?.activate()
                focusOnSpecificWindow(windowInfo: windowInfo)
            }
        } else {
            // Minimize the window
            let minimizeResult = AXUIElementSetAttributeValue(windowInfo.axElement, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
            
            if minimizeResult != .success {
                print("Error minimizing window: \(minimizeResult.rawValue)")
            }
        }
    }
    
    /// Toggles the hidden state of a window.
    static func toggleHidden(windowInfo: WindowInfo) {
        let appElement = AXUIElementCreateApplication(windowInfo.pid)
        
        // Toggle the hidden state
        let newHiddenState = !windowInfo.isHidden
        
        // Set the new hidden state
        let setResult = AXUIElementSetAttributeValue(appElement, kAXHiddenAttribute as CFString, newHiddenState as CFTypeRef)
        
        if setResult != .success {
            print("Error toggling hidden state of application: \(setResult.rawValue)")
            return
        }
        
        // If we're unhiding the app, focus on the specific window
        if !newHiddenState {
            // Activate the application and specific window with best guess
            NSRunningApplication(processIdentifier: windowInfo.pid)?.activate()
            focusOnSpecificWindow(windowInfo: windowInfo)
        }
    }
    
    static func focusOnSpecificWindow(windowInfo: WindowInfo) {
        let appElement = AXUIElementCreateApplication(windowInfo.pid)
        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)
        
        guard result == .success, let windows = windowsRef as? [AXUIElement] else {
            print("Failed to get windows for the application")
            return
        }
        
        for window in windows {
            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)
            if let title = titleRef as? String, isFuzzyMatch(windowTitle: windowInfo.windowName ?? "", axTitleString: title) {
                AXUIElementPerformAction(window, kAXRaiseAction as CFString)
                AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, kCFBooleanTrue)
                return
            }
        }
        
        print("Failed to find and focus on the specific window")
    }
    /// Toggles the full-screen state of a window.
    static func toggleFullScreen(windowInfo: WindowInfo) {
        let kAXFullscreenAttribute = "AXFullScreen" as CFString
        var isCurrentlyInFullScreen: CFTypeRef?
        
        let currentState = AXUIElementCopyAttributeValue(windowInfo.axElement, kAXFullscreenAttribute, &isCurrentlyInFullScreen)
        if currentState == .success {
            if let isFullScreen = isCurrentlyInFullScreen as? Bool {
                AXUIElementSetAttributeValue(windowInfo.axElement, kAXFullscreenAttribute, !isFullScreen as CFBoolean)
            }
            
        }
    }
    
    /// Brings a window to the front and focuses it.
    static func bringWindowToFront(windowInfo: WindowInfo) {
        let raiseResult = AXUIElementPerformAction(windowInfo.axElement, kAXRaiseAction as CFString)
        let focusResult = AXUIElementSetAttributeValue(windowInfo.axElement, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(windowInfo.axElement, kAXFrontmostAttribute as CFString, kCFBooleanTrue) // set frontmost window
        let activateResult = NSRunningApplication(processIdentifier: windowInfo.pid)?.activate()
        
        if activateResult != true || raiseResult != .success || focusResult != .success {
            let fallbackActivateResult = NSRunningApplication(processIdentifier: windowInfo.pid)?.activate(options: [.activateAllWindows])
            let fallbackResult = AXUIElementSetAttributeValue(windowInfo.axElement, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
            
            if fallbackActivateResult != true || fallbackResult != .success {
                //                    if let (key, index) = findKeyAndIndex(for: windowInfo.id) {
                //                        deleteWindowFromListUsingKeyIndex(key, index)
                //                    } else {
                print("Failed to bring window to front with fallback attempts.")
                //                    }
            }
        }
    }
    
    /// Closes a window using its close button.
    static func closeWindow(windowInfo: WindowInfo) {
        guard let closeButton = windowInfo.closeButton else {
            print("Error: closeButton is nil.")
            return
        }
        
        let closeResult = AXUIElementPerformAction(closeButton, kAXPressAction as CFString)
        removeWindowFromDesktopSpaceCache(with: windowInfo.id, in: windowInfo.bundleID)

        if closeResult != .success {
            print("Error closing window: \(closeResult.rawValue)")
            return
        }
    }
    
    /// Terminates the window's application.
    static func quitApp(windowInfo: WindowInfo, force: Bool) {
        guard let app = NSRunningApplication(processIdentifier: windowInfo.pid) else {
            print("No running application associated with PID \(windowInfo.pid)")
            NSSound.beep()
            return
        }
        
        if force {
            app.forceTerminate()
        } else {
            app.terminate()
        }
    }
    
    // MARK: - Minimized Window Handling
    
    /// Retrieves minimized windows' information for a given process ID, bundle ID, and app name.
    static func getMinimizedOrHiddenWindows(pid: pid_t, bundleID: String, appName: String, isParentAppHidden: Bool) -> [WindowInfo] {
        var minimizedOrHiddenWindowsInfo: [WindowInfo] = []
        let appElement = AXUIElementCreateApplication(pid)
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value)
        
        if result == .success, let windows = value as? [AXUIElement] {
            for (index, window) in windows.enumerated() {
                let isMinimized: Bool = getAXAttribute(element: window, attribute: kAXMinimizedAttribute as CFString) ?? false
                
                let windowName: String? = getAXAttribute(element: window, attribute: kAXTitleAttribute as CFString)
                
                if isMinimized || isParentAppHidden {
                    let windowInfo = WindowInfo(id: UInt32(index), window: nil, appName: appName, bundleID: bundleID,
                                                pid: pid, windowName: windowName, image: nil, axElement: window,
                                                closeButton: nil, isMinimized: isMinimized, isHidden: isParentAppHidden)
                    minimizedOrHiddenWindowsInfo.append(windowInfo)
                }
            }
        }
        return minimizedOrHiddenWindowsInfo
    }
    
    /// Retrieves a value for a given AXUIElement attribute.
    static func getAXAttribute<T>(element: AXUIElement, attribute: CFString) -> T? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        return result == .success ? value as? T : nil
    }
    
    // MARK: - Active Window Handling
    
    /// Retrieves the active windows for a given application name.
    static func activeWindows(for applicationName: String) async throws -> [WindowInfo] {
        // If the application name is empty, return all windows
        if applicationName.isEmpty {
            return getAllWindowInfosAsList()
        }

        func getNonLocalizedAppName(forBundleIdentifier bundleIdentifier: String) -> String? {
            guard let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
                return nil
            }
            
            let bundle = Bundle(url: bundleURL)
            let appName = bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            
            return appName
        }
        
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        let group = LimitedTaskGroup<WindowInfo?>(maxConcurrentTasks: 4)
        var foundApp: SCRunningApplication?
        var potentialMatches: [SCRunningApplication] = []
        
        for window in content.windows {
            if let app = window.owningApplication,
               let nonLocalName = getNonLocalizedAppName(forBundleIdentifier: app.bundleIdentifier) {
                
                // Collect potential matches
                if applicationName.contains(app.applicationName) || app.applicationName.contains(applicationName) {
                    potentialMatches.append(app)
                }
                
                if (app.applicationName == applicationName) || (nonLocalName == applicationName) {
                    await group.addTask {
                        return try await fetchWindowInfo(window: window, applicationName: applicationName)
                    }
                    foundApp = app
                    if let bundleId = foundApp?.bundleIdentifier {
                        appNameBundleIdTracker[applicationName] = bundleId
                    }
                }
            }
        }
                
        // If no exact match is found, use the best guess from potential matches
        if foundApp == nil, let bestGuessApp = potentialMatches.first {
            foundApp = bestGuessApp
            
            if let bundleId = foundApp?.bundleIdentifier {
                appNameBundleIdTracker[applicationName] = bundleId
            }
            
            // Loop again to fetch window info for the best guess application
            for window in content.windows {
                if let app = window.owningApplication, app == bestGuessApp {
                    await group.addTask {
                        return try await fetchWindowInfo(window: window, applicationName: applicationName)
                    }
                }
            }
        }
        
        if let app = foundApp,
           let isAppHidden = NSRunningApplication(processIdentifier: app.processID)?.isHidden {
            let minimizedOrHiddenWindowsInfo = getMinimizedOrHiddenWindows(pid: app.processID, bundleID: app.bundleIdentifier,
                                                                           appName: applicationName, isParentAppHidden: isAppHidden)
            for windowInfo in minimizedOrHiddenWindowsInfo {
                await group.addTask { return windowInfo }
            }
        }
                        
        let results = try await group.waitForAll()
        let activeWindows = results.compactMap { $0 }.filter { !$0.appName.isEmpty && !$0.bundleID.isEmpty }
        
        if foundApp == nil, let bundleId = appNameBundleIdTracker[applicationName] { // app does not have any active windows in space
            // this is where we need to inject some logic to get the app bundle identifier, foundApp is always nil when the app is running in another space becuase we are relying on the SCShareableContent.excludingDesktopWindows loop, which is current space limited. we cannot rely on the app name like we initially assumed. we will need to discuss this further.

            // for now i am tracking all of the app name to bundle identifers that are came across in the liftime of the app, and then using that to assume the bundle identifier.
            
            let storedWindows = desktopSpaceWindowCache[bundleId] ?? []
                
            let activeWindowsSet = Set(activeWindows)
            let combinedWindowsSet = activeWindowsSet.union(storedWindows)
                        
            return Array(combinedWindowsSet)
        }
        
        return activeWindows
    }
    
    /// Fetches detailed information for a given SCWindow.
    private static func fetchWindowInfo(window: SCWindow, applicationName: String) async throws -> WindowInfo? {
        let windowID = window.windowID
        
        guard let owningApplication = window.owningApplication,
              let title = window.title, !title.isEmpty,
              window.isOnScreen,
              window.windowLayer == 0,
              window.frame.size.width >= 0,
              window.frame.size.height >= 0,
              !filteredBundleIdentifiers.contains(owningApplication.bundleIdentifier) else {
            return nil
        }
        
        let pid = owningApplication.processID
        
        let appRef = createAXUIElement(for: pid)
        
        guard let axWindows = getAXWindows(for: appRef), !axWindows.isEmpty else {
            return nil
        }
        
        guard let windowRef = findWindow(matchingWindow: window, in: axWindows) else {
            print("Failed to find matching AX window")
            return nil
        }
        
        let closeButton = getCloseButton(for: windowRef)
        
        var windowInfo = WindowInfo(id: windowID,
                                    window: window,
                                    appName: owningApplication.applicationName,
                                    bundleID: owningApplication.bundleIdentifier,
                                    pid: pid,
                                    windowName: window.title,
                                    image: nil,
                                    axElement: windowRef,
                                    closeButton: closeButton,
                                    isMinimized: false,
                                    isHidden: false)
        
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
        if var windowSet = desktopSpaceWindowCache[windowInfo.bundleID] {
            if let existingWindow = windowSet.first(where: { $0.id == windowInfo.id }) {
                windowSet.remove(existingWindow)
                windowSet.insert(windowInfo)  // This will update the image
            } else {
                windowSet.insert(windowInfo)  // Add newly discovered window
            }
            desktopSpaceWindowCache[windowInfo.bundleID] = windowSet
        } else {
            desktopSpaceWindowCache[windowInfo.bundleID] = Set([windowInfo])
        }
    }

    static func findWindowInDesktopSpaceCache(for windowID: CGWindowID, in bundleID: String) -> WindowInfo? {
        return desktopSpaceWindowCache[bundleID]?.first { $0.id == windowID }
    }

    static func removeWindowFromDesktopSpaceCache(with id: CGWindowID, in bundleID: String) {
        if let windowToRemove = findWindowInDesktopSpaceCache(for: id, in: bundleID) {
            desktopSpaceWindowCache[bundleID]?.remove(windowToRemove)
        }
        
        if desktopSpaceWindowCache[bundleID]?.isEmpty == true {
            desktopSpaceWindowCache.removeValue(forKey: bundleID)
        }
    }
}

actor LimitedTaskGroup<T> {
    private var tasks: [Task<T, Error>] = []
    private let maxConcurrentTasks: Int
    private var runningTasks = 0
    private let semaphore: AsyncSemaphore
    
    init(maxConcurrentTasks: Int) {
        self.maxConcurrentTasks = maxConcurrentTasks
        self.semaphore = AsyncSemaphore(value: maxConcurrentTasks)
    }
    
    func addTask(_ operation: @escaping () async throws -> T) {
        let task = Task {
            await semaphore.wait()
            defer { Task { await semaphore.signal() } }
            return try await operation()
        }
        tasks.append(task)
    }
    
    func waitForAll() async throws -> [T] {
        defer { tasks.removeAll() }
        
        return try await withThrowingTaskGroup(of: T.self) { group in
            for task in tasks {
                group.addTask {
                    try await task.value
                }
            }
            
            var results: [T] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }
    }
}

actor AsyncSemaphore {
    private var value: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []
    
    init(value: Int) {
        self.value = value
    }
    
    func wait() async {
        if value > 0 {
            value -= 1
        } else {
            await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }
    }
    
    func signal() {
        if let waiter = waiters.first {
            waiters.removeFirst()
            waiter.resume()
        } else {
            value += 1
        }
    }
}
