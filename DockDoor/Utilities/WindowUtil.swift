//
//  WindowManager.swift
//  DockDoor
//
//  Created by Ethan Bills on 6/3/24.
//

import Cocoa
import ApplicationServices
import ScreenCaptureKit

/// Struct representing window information.
struct WindowInfo: Identifiable, Hashable {
    let id: CGWindowID
    let window: SCWindow?
    let appName: String
    let bundleID: String
    let windowName: String?
    var image: CGImage?
    var axElement: AXUIElement
    var closeButton: AXUIElement?
    let isMinimized: Bool
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
    private static var cacheExpirySeconds: Double = 60 // 1 min
    
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
    static func captureWindowImage(windowInfo: WindowInfo) async throws -> CGImage {
        clearExpiredCache()
        return try cacheQueue.sync(flags: .barrier) {
            if let cachedImage = imageCache[windowInfo.id], Date().timeIntervalSince(cachedImage.timestamp) <= cacheExpirySeconds {
                return cachedImage.image
            }
            guard CGPreflightScreenCaptureAccess() else {
                throw NSError(domain: "com.dockdoor.permission", code: 2, userInfo: [NSLocalizedDescriptionKey: "Screen recording permission not granted"])
            }
            guard let frame = windowInfo.window?.frame,
                  let image = CGWindowListCreateImage(frame, .optionIncludingWindow, windowInfo.id, [.boundsIgnoreFraming, .bestResolution]) else {
                throw NSError(domain: "com.dockdoor.error", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to capture window image"])
            }
            let cachedImage = CachedImage(image: image, timestamp: Date())
            imageCache[windowInfo.id] = cachedImage
            return image
        }
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
            var axTitle: CFTypeRef?
            AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &axTitle)
            let axTitleString = (axTitle as? String) ?? ""
            
            var axPosition: CFTypeRef?
            AXUIElementCopyAttributeValue(axWindow, kAXPositionAttribute as CFString, &axPosition)
            let axPositionValue = axPosition as? CGPoint
            
            var axSize: CFTypeRef?
            AXUIElementCopyAttributeValue(axWindow, kAXSizeAttribute as CFString, &axSize)
            let axSizeValue = axSize as? CGSize
            
            // Enhanced fuzzy title matching
            if let windowTitle = window.title {
                let axTitleWords = axTitleString.lowercased().split(separator: " ")
                let windowTitleWords = windowTitle.lowercased().split(separator: " ")
                
                let matchingWords = axTitleWords.filter { windowTitleWords.contains($0) }
                let matchPercentage = Double(matchingWords.count) / Double(windowTitleWords.count)
                
                if matchPercentage >= 0.90 || matchPercentage.isNaN {  // At least 90% of words match
                    return axWindow
                }
                
                // Additional check for suffixes/prefixes often added by browsers
                if axTitleString.lowercased().contains(windowTitle.lowercased()) {
                    return axWindow
                }
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
        return NSWorkspace.shared.runningApplications.first { $0.localizedName == applicationName }
    }
    
    // MARK: - Window Manipulation Functions
    
    /// Toggles the minimize state of a window.
    static func toggleMinimize(windowInfo: WindowInfo) {
        let minimizeResult: AXError = windowInfo.isMinimized ?
        AXUIElementSetAttributeValue(windowInfo.axElement, kAXMinimizedAttribute as CFString, kCFBooleanFalse) :
        AXUIElementSetAttributeValue(windowInfo.axElement, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
        
        if minimizeResult != .success {
            print("Error toggling minimized state of window: \(minimizeResult.rawValue)")
        }
    }
    
    /// Brings a window to the front and focuses it.
    static func bringWindowToFront(windowInfo: WindowInfo) {
        let raiseResult = AXUIElementPerformAction(windowInfo.axElement, kAXRaiseAction as CFString)
        let focusResult = AXUIElementSetAttributeValue(windowInfo.axElement, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(windowInfo.axElement, kAXFrontmostAttribute as CFString, kCFBooleanTrue) // set frontmost window
        let activateResult = NSRunningApplication(processIdentifier: windowInfo.window?.owningApplication?.processID ?? 0)?.activate()
        
        if activateResult != true || raiseResult != .success || focusResult != .success {
            let fallbackActivateResult = NSRunningApplication(processIdentifier: windowInfo.window?.owningApplication?.processID ?? 0)?.activate(options: [.activateAllWindows])
            let fallbackResult = AXUIElementSetAttributeValue(windowInfo.axElement, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
            
            if fallbackActivateResult != true || fallbackResult != .success {
                print("Failed to bring window to front with fallback attempts.")
            }
        }
    }
    
    /// Closes a window using its close button.
    static func closeWindow(closeButton: AXUIElement?) {
        guard let closeButton = closeButton else {
            print("Error: closeButton is nil.")
            return
        }
        
        let closeResult = AXUIElementPerformAction(closeButton, kAXPressAction as CFString)
        if closeResult != .success {
            print("Error closing window: \(closeResult.rawValue)")
            return
        }
    }
    
    // MARK: - Minimized Window Handling
    
    /// Retrieves minimized windows' information for a given process ID, bundle ID, and app name.
    static func getMinimizedWindows(pid: pid_t, bundleID: String, appName: String) -> [WindowInfo] {
        var minimizedWindowsInfo: [WindowInfo] = []
        let appElement = AXUIElementCreateApplication(pid)
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value)
        
        if result == .success, let windows = value as? [AXUIElement] {
            for (index, window) in windows.enumerated() {
                var minimizedValue: AnyObject?
                let minimizedResult = AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimizedValue)
                if minimizedResult == .success, let isMinimized = minimizedValue as? Bool, isMinimized {
                    let windowName: String? = getAXAttribute(element: window, attribute: kAXTitleAttribute as CFString)
                    let windowInfo = WindowInfo(id: UInt32(index), window: nil, appName: appName, bundleID: bundleID,
                                                windowName: windowName, image: nil, axElement: window,
                                                closeButton: nil, isMinimized: true)
                    minimizedWindowsInfo.append(windowInfo)
                }
            }
        }
        return minimizedWindowsInfo
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
                
                if applicationName.isEmpty || (app.applicationName == applicationName) || (nonLocalName == applicationName) {
                    await group.addTask {
                        return try await fetchWindowInfo(window: window, applicationName: applicationName)
                    }
                    foundApp = app
                }
            }
        }
        
        // If no exact match is found, use the best guess from potential matches
        if foundApp == nil, !applicationName.isEmpty, let bestGuessApp = potentialMatches.first {
            foundApp = bestGuessApp
            
            // Loop again to fetch window info for the best guess application
            for window in content.windows {
                if let app = window.owningApplication, app == bestGuessApp {
                    await group.addTask {
                        return try await fetchWindowInfo(window: window, applicationName: applicationName)
                    }
                }
            }
        }
        
        if let app = foundApp, !applicationName.isEmpty {
            let minimizedWindowsInfo = getMinimizedWindows(pid: app.processID, bundleID: app.bundleIdentifier, appName: applicationName)
            for windowInfo in minimizedWindowsInfo {
                await group.addTask { return windowInfo }
            }
        } else if !applicationName.isEmpty, let app = getRunningApplication(named: applicationName), let bundleID = app.bundleIdentifier {
            let minimizedWindowsInfo = getMinimizedWindows(pid: app.processIdentifier, bundleID: bundleID, appName: applicationName)
            for windowInfo in minimizedWindowsInfo {
                await group.addTask { return windowInfo }
            }
        }
        
        let results = try await group.waitForAll()
        return results.compactMap { $0 }.filter { !$0.appName.isEmpty && !$0.bundleID.isEmpty }
    }
    
    /// Fetches detailed information for a given SCWindow.
    private static func fetchWindowInfo(window: SCWindow, applicationName: String) async throws -> WindowInfo? {
        let windowID = window.windowID
        
        guard let windowInfoDict = CGWindowListCopyWindowInfo(.optionIncludingWindow, windowID) as? [[String: AnyObject]],
              let windowLayer = windowInfoDict.first?[kCGWindowLayer as String] as? Int,
              let windowAlpha = windowInfoDict.first?[kCGWindowAlpha as String] as? Double,
              let owningApplication = window.owningApplication else {
            return nil
        }
        
        if windowLayer > 1 || windowAlpha <= 0 {
            return nil
        }
        
        let pid = owningApplication.processID
        
        let appRef = createAXUIElement(for: pid)
        
        guard let axWindows = getAXWindows(for: appRef) else {
            return nil
        }
        
        if axWindows.isEmpty {
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
                                    windowName: window.title,
                                    image: nil,
                                    axElement: windowRef,
                                    closeButton: closeButton,
                                    isMinimized: false)
        
        do {
            windowInfo.image = try await captureWindowImage(windowInfo: windowInfo)
            return windowInfo
        } catch {
            return nil
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
