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

let filteredBundleIdentifiers: [String] = ["com.apple.notificationcenterui"]  // filters desktop widgets

struct WindowInfo: Identifiable, Hashable {
    let id: CGWindowID
    let window: SCWindow?
    let appName: String
    let bundleID: String
    let pid: pid_t
    var windowName: String?
    var image: CGImage?
    var axElement: AXUIElement
    var closeButton: AXUIElement?
    var isMinimized: Bool
    var isHidden: Bool
    var lastUsed: Date
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(bundleID)
    }
    
    static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        return lhs.id == rhs.id && lhs.bundleID == rhs.bundleID
    }
}

struct CachedImage {
    let image: CGImage
    let timestamp: Date
    let windowname: String?
}

struct CachedAppIcon {
    let icon: NSImage
    let timestamp: Date
}

final class WindowUtil {
    private static var imageCache: [CGWindowID: CachedImage] = [:]
    private static let cacheQueue = DispatchQueue(label: "com.dockdoor.cacheQueue", attributes: .concurrent)
    private static var cacheExpirySeconds: Double = Defaults[.screenCaptureCacheLifespan]
    
    private static let desktopSpaceWindowCacheManager = SpaceWindowCacheManager()
    
    private static var appNameBundleIdTracker: [String: String] = [:]
    
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
        config.width = Int(window.frame.width)
        config.height = Int(window.frame.height)
        config.showsCursor = false
        config.captureResolution = .best
        
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        
        let cachedImage = CachedImage(image: image, timestamp: Date(), windowname: window.title)
        imageCache[window.windowID] = cachedImage
        
        return image
    }
    
    private static func getCachedImage(window: SCWindow) -> CGImage? {
        if let cachedImage = imageCache[window.windowID], cachedImage.windowname == window.title, Date().timeIntervalSince(cachedImage.timestamp) <= cacheExpirySeconds {
            return cachedImage.image
        }
        return nil
    }
    
    static func createAXUIElement(for pid: pid_t) -> AXUIElement {
        return AXUIElementCreateApplication(pid)
    }
    
    static func getAXWindows(for appRef: AXUIElement) -> [AXUIElement]? {
        var windowList: AnyObject?
        let result = AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowList)
        return result == .success ? windowList as? [AXUIElement] : nil
    }
    
    static func isElementValid(_ element: AXUIElement) -> Bool {
        var role: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        return result == .success
    }
    
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
            
            if let windowTitle = window.title, isFuzzyMatch(windowTitle: windowTitle, axTitleString: axTitleString) {
                return axWindow
            }
            
            if let axPositionValue = axPositionValue,
               let axSizeValue = axSizeValue,
               axPositionValue != .zero,
               axSizeValue != .zero {
                
                let positionThreshold: CGFloat = 10
                let sizeThreshold: CGFloat = 10
                
                let positionMatch = abs(axPositionValue.x - window.frame.origin.x) <= positionThreshold &&
                abs(axPositionValue.y - window.frame.origin.y) <= positionThreshold
                
                let sizeMatch = abs(axSizeValue.width - window.frame.size.width) <= sizeThreshold &&
                abs(axSizeValue.height - window.frame.size.height) <= sizeThreshold
                
                if positionMatch && sizeMatch {
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
    
    static func getCloseButton(for windowRef: AXUIElement) -> AXUIElement? {
        var closeButton: AnyObject?
        let result = AXUIElementCopyAttributeValue(windowRef, kAXCloseButtonAttribute as CFString, &closeButton)
        
        guard result == .success, let closeButtonElement = closeButton else {
            return nil
        }
        
        return (closeButtonElement as! AXUIElement)
    }
    
    static func getRunningApplication(named applicationName: String) -> NSRunningApplication? {
        return NSWorkspace.shared.runningApplications.first {
            applicationName.contains($0.localizedName ?? "") || ($0.localizedName?.contains(applicationName) ?? false)
        }
    }
    
    // MARK: - Desktop Cache Retrievers
    static func addToBundleIDTracker(applicationName: String, bundleID: String ) {
        if !appNameBundleIdTracker.contains(where: {$0.key == applicationName}) {
            appNameBundleIdTracker[applicationName] = bundleID
        }
    }
    
    static func getAllWindowInfosAsList() -> [WindowInfo] {
        return desktopSpaceWindowCacheManager.getAllWindows()
    }
    
    // MARK: - Window Manipulation Functions
    
    static func toggleMinimize(windowInfo: WindowInfo) {
        if windowInfo.isMinimized {
            if let app = NSRunningApplication(processIdentifier: windowInfo.pid), app.isHidden {
                app.unhide()
            }
            
            let minimizeResult = AXUIElementSetAttributeValue(windowInfo.axElement, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            
            if minimizeResult != .success {
                print("Error un-minimizing window: \(minimizeResult.rawValue)")
            } else {
                NSRunningApplication(processIdentifier: windowInfo.pid)?.activate()
                focusOnSpecificWindow(windowInfo: windowInfo)
            }
        } else {
            let minimizeResult = AXUIElementSetAttributeValue(windowInfo.axElement, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
            
            if minimizeResult != .success {
                print("Error minimizing window: \(minimizeResult.rawValue)")
            }
        }
        updateWindowDateTime(windowInfo)
    }
    
    static func toggleHidden(windowInfo: WindowInfo) {
        let appElement = AXUIElementCreateApplication(windowInfo.pid)
        
        let newHiddenState = !windowInfo.isHidden
        
        let setResult = AXUIElementSetAttributeValue(appElement, kAXHiddenAttribute as CFString, newHiddenState as CFTypeRef)
        
        if setResult != .success {
            print("Error toggling hidden state of application: \(setResult.rawValue)")
            return
        }
        
        if !newHiddenState {
            NSRunningApplication(processIdentifier: windowInfo.pid)?.activate()
            focusOnSpecificWindow(windowInfo: windowInfo)
        }
        updateWindowDateTime(windowInfo)
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
    
    static func bringWindowToFront(windowInfo: WindowInfo) {
        let raiseResult = AXUIElementPerformAction(windowInfo.axElement, kAXRaiseAction as CFString)
        let focusResult = AXUIElementSetAttributeValue(windowInfo.axElement, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(windowInfo.axElement, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        let activateResult = NSRunningApplication(processIdentifier: windowInfo.pid)?.activate()
        updateWindowDateTime(windowInfo)
        
        if activateResult != true || raiseResult != .success || focusResult != .success {
            let fallbackActivateResult = NSRunningApplication(processIdentifier: windowInfo.pid)?.activate(options: [.activateAllWindows])
            let fallbackResult = AXUIElementSetAttributeValue(windowInfo.axElement, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
            
            if fallbackActivateResult != true || fallbackResult != .success {
                removeWindowFromDesktopSpaceCache(with: windowInfo.id, in: windowInfo.bundleID)
                print("Failed to bring window to front with fallback attempts.")
            }
        }
    }
    
    static func updateWindowDateTime(_ windowInfo: WindowInfo) {
        desktopSpaceWindowCacheManager.updateCache(bundleId: windowInfo.bundleID) { windowSet in
            if let index = windowSet.firstIndex(where: { $0.id == windowInfo.id }) {
                var updatedWindow = windowSet[index]
                updatedWindow.lastUsed = Date()
                windowSet.remove(at: index)
                windowSet.insert(updatedWindow)
            }
        }
    }
    
    static func updateWindowDateTime(with bundleID: String, pid: pid_t) {
        desktopSpaceWindowCacheManager.updateCache(bundleId: bundleID) {
            windowSet in
            if windowSet.isEmpty {
                return
            }
            let application = createAXUIElement(for: pid)
            var value: AnyObject?
            let result = AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &value)
            if result == .success, let windows = value as? [AXUIElement] {
                for window in windows {
                    var cgWindowId: CGWindowID = 0
                    let windowIDStatus = _AXUIElementGetWindow(window, &cgWindowId)
                    if windowIDStatus == .success, 
                        let index = windowSet.firstIndex(where: { $0.id == cgWindowId })
                    {
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
    
    static func quitApp(windowInfo: WindowInfo, force: Bool) {
        guard let app = NSRunningApplication(processIdentifier: windowInfo.pid) else {
            print("No running application associated with PID \(windowInfo.pid)")
            NSSound.beep()
            return
        }
        
        removeWindowFromDesktopSpaceCache(with: windowInfo.bundleID, removeAll: true)
        if force {
            app.forceTerminate()
        } else {
            app.terminate()
        }
    }
    
    static func getAXAttribute<T>(element: AXUIElement, attribute: CFString) -> T? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        return result == .success ? value as? T : nil
    }
    
    // MARK: - Active Window Handling
    
    static func activeWindows(for applicationName: String) async throws -> [WindowInfo] {
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        
        let group = LimitedTaskGroup<WindowInfo?>(maxConcurrentTasks: 4)
        var foundApp: SCRunningApplication?
        var nonLocalName: String?
        var potentialMatches: [SCRunningApplication] = []
        
        for window in content.windows {
            if let app = window.owningApplication,
               let tempNonLocalName = getNonLocalizedAppName(forBundleIdentifier: app.bundleIdentifier) {
                
                updateAppNameBundleIdTracker(app: app, nonLocalName: tempNonLocalName)
                
                if applicationName.contains(app.applicationName) || app.applicationName.contains(applicationName) {
                    potentialMatches.append(app)
                }
                
                if applicationName.isEmpty || (app.applicationName == applicationName) || (tempNonLocalName == applicationName) {
                    await group.addTask {
                        return try await fetchWindowInfo(window: window, applicationName: applicationName)
                    }
                    foundApp = app
                    nonLocalName = tempNonLocalName
                }
            }
        }
        
        if foundApp == nil, let bestGuessApp = potentialMatches.first {
            foundApp = bestGuessApp
            
            if let bundleId = foundApp?.bundleIdentifier,
               let tempNonLocalName = getNonLocalizedAppName(forBundleIdentifier: bundleId) {
                updateAppNameBundleIdTracker(app: bestGuessApp, nonLocalName: tempNonLocalName)
                nonLocalName = tempNonLocalName
            }
            
            for window in content.windows {
                if let app = window.owningApplication, app == bestGuessApp {
                    await group.addTask {
                        return try await fetchWindowInfo(window: window, applicationName: applicationName)
                    }
                }
            }
        }
        
        if let app = foundApp, let isAppHidden = NSRunningApplication(processIdentifier: app.processID)?.isHidden {
            updateStatusOfWindowCache(pid: app.processID, bundleID: app.bundleIdentifier, isParentAppHidden: isAppHidden)
        }
        
        let results = try await group.waitForAll()
        let activeWindows = results.compactMap { $0 }.filter { !$0.appName.isEmpty && !$0.bundleID.isEmpty }
        
        if applicationName.isEmpty {
            let storedWindows = desktopSpaceWindowCacheManager.getAllWindows()
            return storedWindows
        }
        
        if let nonLocalName {
            let bundleId = appNameBundleIdTracker[nonLocalName] ?? foundApp?.bundleIdentifier
            if let bundleId {
                let storedWindows = desktopSpaceWindowCacheManager.readCache(bundleId: bundleId)
                return Array(Set(activeWindows).union(storedWindows))
            }
        }
        
        // Fallback to findAllWindowsInDesktopCacheForApplication if no SCRunningApplication is found and applicationName isn't empty
        if foundApp == nil && !applicationName.isEmpty {
            if let cachedWindows = findAllWindowsInDesktopCacheForApplication(for: applicationName) {
                return cachedWindows
            }
        }
        
        return activeWindows
    }
    
    static func retryWindowCreation(for appName: String, maxRetries: Int, delay: TimeInterval) async {
        let initialCount = findAllWindowsInDesktopCacheForApplication(for: appName)?.count ?? 0
        
        for attempt in 1...maxRetries {
            do {
                let refreshedWindowCount = try await WindowUtil.activeWindows(for: appName).count
                
                if refreshedWindowCount > initialCount {
                    return
                }
            } catch {
                print("Error retrieving windows for \(appName) on attempt \(attempt): \(error)")
            }
            
            if attempt < maxRetries {
                print("No new windows detected for \(appName) on attempt \(attempt). Retrying...")
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        print("Failed to detect new window for \(appName) after \(maxRetries) attempts")
    }
    
    
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
        desktopSpaceWindowCacheManager.updateCache(bundleId: windowInfo.bundleID) { windowSet in
            if let matchingWindow = windowSet.first(where: { $0.id == windowInfo.id && $0.windowName != windowInfo.windowName }) {
                var matchingWindowCopy = matchingWindow
                matchingWindowCopy.windowName = windowInfo.windowName
                matchingWindowCopy.image = windowInfo.image
                windowSet.remove(matchingWindow)
                windowSet.insert(matchingWindowCopy)
            }
            else {
                windowSet.insert(windowInfo)
            }
        }
    }
    
    static func findWindowInDesktopSpaceCache(for windowID: CGWindowID, in bundleID: String) -> WindowInfo? {
        return desktopSpaceWindowCacheManager.readCache(bundleId: bundleID).first { $0.id == windowID }
    }
    
    static func removeWindowFromDesktopSpaceCache(with id: CGWindowID, in bundleID: String) {
        desktopSpaceWindowCacheManager.removeFromCache(bundleId: bundleID, windowId: id)
    }
    
    static func removeWindowFromDesktopSpaceCache(with bundleID: String, removeAll: Bool) {
        if removeAll {
            desktopSpaceWindowCacheManager.writeCache(bundleId: bundleID, windowSet: [])
        } else {
            Task {
                let existingWindowsSet = desktopSpaceWindowCacheManager.readCache(bundleId: bundleID)
                if existingWindowsSet.isEmpty {
                    return
                }
                for window in existingWindowsSet {
                    if !isElementValid(window.axElement) {
                        desktopSpaceWindowCacheManager.removeFromCache(bundleId: window.bundleID, windowId: window.id)
                        return
                    }
                }
            }
        }
    }
    
    static func updateStatusOfWindowCache(pid: pid_t, bundleID: String, isParentAppHidden: Bool) {
        let appElement = AXUIElementCreateApplication(pid)
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value)
        
        if result == .success, let windows = value as? [AXUIElement] {
            desktopSpaceWindowCacheManager.updateCache(bundleId: bundleID) { cachedWindows in
                for window in windows {
                    let isMinimized: Bool = getAXAttribute(element: window, attribute: kAXMinimizedAttribute as CFString) ?? false
                    let windowName: String? = getAXAttribute(element: window, attribute: kAXTitleAttribute as CFString)
                    
                    if isMinimized || isParentAppHidden, let windowName = windowName {
                        cachedWindows = Set(cachedWindows.map { windowInfo in
                            var updatedWindow = windowInfo
                            if windowInfo.windowName == windowName {
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
    
    private static func getNonLocalizedAppName(forBundleIdentifier bundleIdentifier: String) -> String? {
        guard let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return nil
        }
        
        let bundle = Bundle(url: bundleURL)
        return bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
    }
    
    private static func updateAppNameBundleIdTracker(app: SCRunningApplication, nonLocalName: String) {
        appNameBundleIdTracker[app.applicationName] = app.bundleIdentifier
        appNameBundleIdTracker[nonLocalName] = app.bundleIdentifier
    }
    
    static func findAllWindowsInDesktopCacheForApplication(for applicationName: String) -> [WindowInfo]? {
        let bundleID = findBundleID(for: applicationName)
        
        if let bundleID = bundleID {
            let windowSet = desktopSpaceWindowCacheManager.readCache(bundleId: bundleID)
            return windowSet.isEmpty ? nil : Array(windowSet).sorted(by: { $0.lastUsed > $1.lastUsed })
        }
        
        return nil
    }
    
    private static func findBundleID(for applicationName: String) -> String? {
        // First, try to get the bundle ID directly from the tracker
        if let bundleID = appNameBundleIdTracker[applicationName] {
            return bundleID
        }
        
        // If not found, try to find a matching application
        for (appName, bundleId) in appNameBundleIdTracker {
            if applicationName.contains(appName) || appName.contains(applicationName) {
                return bundleId
            }
            
            // Check non-localized name
            if let nonLocalizedName = getNonLocalizedAppName(forBundleIdentifier: bundleId),
               applicationName.contains(nonLocalizedName) || nonLocalizedName.contains(applicationName) {
                return bundleId
            }
        }
        
        return nil
    }
}
