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
    var appAxElement: AXUIElement
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
    
    static func clearWindowCache(for bundleId: String) {
        desktopSpaceWindowCacheManager.writeCache(bundleId: bundleId, windowSet: [])
    }

    static func addAppToBundleIDTracker(applicationName: String, bundleID: String) {
        desktopSpaceWindowCacheManager.addToBundleIDTracker(applicationName: applicationName, bundleID: bundleID)
    }

    static func updateWindowCache(for bundleId: String, update: @escaping (inout Set<WindowInfo>) -> Void) {
        desktopSpaceWindowCacheManager.updateCache(bundleId: bundleId, update: update)
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
        return await MainActor.run {
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
    
    static func getRunningApplication(named applicationName: String) -> NSRunningApplication? {
        return NSWorkspace.shared.runningApplications.first {
            applicationName.contains($0.localizedName ?? "") || ($0.localizedName?.contains(applicationName) ?? false)
        }
    }
    
    // MARK: - Desktop Cache Retrievers
    static func getAllWindowInfosAsList() -> [WindowInfo] {
        return desktopSpaceWindowCacheManager.getAllWindows()
    }
    
    // MARK: - Window Manipulation Functions
    
    static func toggleMinimize(windowInfo: WindowInfo) {
        if windowInfo.isMinimized {
            if let app = NSRunningApplication(processIdentifier: windowInfo.pid), app.isHidden {
                app.unhide()
            }
            
            do {
                try windowInfo.axElement.setAttribute(kAXMinimizedAttribute, false)
                NSRunningApplication(processIdentifier: windowInfo.pid)?.activate()
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
            NSRunningApplication(processIdentifier: windowInfo.pid)?.activate()
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
                print("Fialed to toggle full screen")
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
            if let application = NSRunningApplication(processIdentifier: windowInfo.pid) {
                if !application.activate() {
                    throw NSError(domain: "FailedToActivate", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to activate application with PID \(windowInfo.pid)"])
                }
            } else {
                throw NSError(domain: "ApplicationNotFound", code: 2, userInfo: [NSLocalizedDescriptionKey: "No running application found with PID \(windowInfo.pid)"])
            }
            
            updateWindowDateTime(windowInfo)
        } catch {
            if NSRunningApplication(processIdentifier: windowInfo.pid)?.activate(options: [.activateAllWindows]) != true || (try? windowInfo.axElement.setAttribute(kAXFrontmostAttribute, true)) == nil {
                print("Failed to bring window to front with fallback attempts.")
                removeWindowFromDesktopSpaceCache(with: windowInfo.id, in: windowInfo.bundleID)
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
            let appElement = AXUIElementCreateApplication(pid)
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
    
    static func closeWindow(windowInfo: WindowInfo) {
        guard windowInfo.closeButton != nil else {
            print("Error: closeButton is nil.")
            return
        }
        
        do {
            try windowInfo.closeButton?.performAction(kAXPressAction)
            removeWindowFromDesktopSpaceCache(with: windowInfo.id, in: windowInfo.bundleID)
        } catch {
            print("Error closing window")
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
                
                desktopSpaceWindowCacheManager.updateAppNameBundleIdTracker(app: app, nonLocalName: tempNonLocalName)
                
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
                desktopSpaceWindowCacheManager.updateAppNameBundleIdTracker(app: bestGuessApp, nonLocalName: tempNonLocalName)
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
        
        let results = try await group.waitForAll()
        let activeWindows = results.compactMap { $0 }.filter { !$0.appName.isEmpty && !$0.bundleID.isEmpty }
        
        if applicationName.isEmpty {
            return desktopSpaceWindowCacheManager.getAllWindows()
        }
        
        if let nonLocalName {
            let bundleId = desktopSpaceWindowCacheManager.findBundleID(for: nonLocalName) ?? foundApp?.bundleIdentifier
            if let bundleId {
                return Array(desktopSpaceWindowCacheManager.readCache(bundleId: bundleId))
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
        
    private static func fetchWindowInfo(window: SCWindow, applicationName: String) async throws -> WindowInfo? {
        let windowID = window.windowID
        
        guard let owningApplication = window.owningApplication,
              window.isOnScreen,
              window.windowLayer == 0,
              window.frame.size.width >= 0,
              window.frame.size.height >= 0,
              !filteredBundleIdentifiers.contains(owningApplication.bundleIdentifier),
              !(window.frame.size.width < 100 || window.frame.size.height < 100) || window.title?.isEmpty == false else {
            return nil
        }
        
        let pid = owningApplication.processID
        let appElement = AXUIElementCreateApplication(pid)
        
        guard let axWindows = try? appElement.windows(), !axWindows.isEmpty else {
            return nil
        }
        
        guard let windowRef = findWindow(matchingWindow: window, in: axWindows) else {
            return nil
        }
        
        let closeButton = try? windowRef.closeButton()
        
        var windowInfo = WindowInfo(id: windowID,
                                    window: window,
                                    appName: owningApplication.applicationName,
                                    bundleID: owningApplication.bundleIdentifier,
                                    pid: pid,
                                    windowName: window.title,
                                    image: nil,
                                    axElement: windowRef,
                                    appAxElement: AXUIElementCreateApplication(pid),
                                    closeButton: closeButton,
                                    isMinimized: false,
                                    isHidden: false,
                                    lastUsed: Date()
        )
        
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
            if let matchingWindow = windowSet.first(where: { $0.id == windowInfo.id }) {
                var matchingWindowCopy = matchingWindow
                matchingWindowCopy.windowName = windowInfo.windowName
                matchingWindowCopy.image = windowInfo.image
                matchingWindowCopy.isHidden = windowInfo.isHidden
                matchingWindowCopy.isMinimized = windowInfo.isMinimized
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
                    if !isValidElement(window.axElement) {
                        desktopSpaceWindowCacheManager.removeFromCache(bundleId: window.bundleID, windowId: window.id)
                        return
                    }
                }
            }
        }
    }
    
    static func updateStatusOfWindowCache(pid: pid_t, bundleID: String, isParentAppHidden: Bool) {
        let appElement = AXUIElementCreateApplication(pid)
        if let windows = try? appElement.windows() {
            desktopSpaceWindowCacheManager.updateCache(bundleId: bundleID) { cachedWindows in
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
    
    private static func getNonLocalizedAppName(forBundleIdentifier bundleIdentifier: String) -> String? {
        guard let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return nil
        }
        
        let bundle = Bundle(url: bundleURL)
        return bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
    }
    
    static func findAllWindowsInDesktopCacheForApplication(for applicationName: String) -> [WindowInfo]? {
        let bundleID = desktopSpaceWindowCacheManager.findBundleID(for: applicationName)
        
        if let bundleID = bundleID {
            let windowSet = desktopSpaceWindowCacheManager.readCache(bundleId: bundleID)
            return windowSet.isEmpty ? nil : Array(windowSet).sorted(by: { $0.lastUsed > $1.lastUsed })
        }
        
        return nil
    }
}
