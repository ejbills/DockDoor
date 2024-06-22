//
//  WindowManager.swift
//  DockDoor
//
//  Created by Ethan Bills on 6/3/24.
//

import Cocoa
import ApplicationServices
import ScreenCaptureKit

struct WindowInfo: Identifiable, Hashable {
    let id: CGWindowID
    let window: SCWindow
    let appName: String
    let bundleID: String
    let windowName: String?
    var image: CGImage?
}

// Cache item structure
struct CachedImage {
    let image: CGImage
    let timestamp: Date
}

struct CachedAppIcon {
    let icon: NSImage
    let timestamp: Date
}

struct WindowUtil {
        
    private static var imageCache: [CGWindowID: CachedImage] = [:]
    private static var iconCache: [String: CachedAppIcon] = [:]
    
    private static var cacheExpirySeconds: Double = 600 // 10 mins
        
    static func clearExpiredCache() {
        let now = Date()
        imageCache = imageCache.filter { now.timeIntervalSince($0.value.timestamp) <= cacheExpirySeconds }
        iconCache = iconCache.filter { now.timeIntervalSince($0.value.timestamp) <= cacheExpirySeconds }
    }
    
    // MARK: - Helper Functions
    
    static func captureWindowImage(windowInfo: WindowInfo) async throws -> CGImage {
        clearExpiredCache()
        
        if let cachedImage = imageCache[windowInfo.id],
           Date().timeIntervalSince(cachedImage.timestamp) <= cacheExpirySeconds {
            return cachedImage.image
        }
        
        guard CGPreflightScreenCaptureAccess() else {
            print("Debug: Screen recording permission not granted")
            MessageUtil.showMessage(title: "Permission error",
                                    message: "You need to give DockDoor access to Screen Recording in Security & Privacy for it to function.",
                                    completion: { _ in SystemPreferencesHelper.openScreenRecordingPreferences() })
            throw NSError(domain: "com.dockdoor.permission", code: 2, userInfo: [NSLocalizedDescriptionKey: "Screen recording permission not granted"])
        }
        
        let id = windowInfo.id
        let frame = windowInfo.window.frame

        guard let image = CGWindowListCreateImage(frame, .optionIncludingWindow, id, [.boundsIgnoreFraming, .bestResolution]) else {
            throw NSError(domain: "com.dockdoor.error", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to capture window image"])
        }
        
        let cachedImage = CachedImage(image: image, timestamp: Date())
        imageCache[windowInfo.id] = cachedImage
        
        return image
    }
    
    // MARK: - Window Manipulation Functions
    
    static func bringWindowToFront(windowInfo: WindowInfo) {
        guard let pid = windowInfo.window.owningApplication?.processID else {
            print("Debug: Failed to get PID from windowInfo")
            return
        }
        
        let appRef = AXUIElementCreateApplication(pid)
        
        var windowList: AnyObject?
        let result = AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowList)
        
        if result != .success {
            print("Error getting windows: \(result.rawValue)")
            return
        }
        
        var foundWindow: AXUIElement?
        if let windows = windowList as? [AXUIElement] {
            for windowRef in windows {
                var windowTitleValue: AnyObject?
                AXUIElementCopyAttributeValue(windowRef, kAXTitleAttribute as CFString, &windowTitleValue)
                if let windowTitle = windowTitleValue as? String, windowTitle == windowInfo.windowName {
                    foundWindow = windowRef
                    break
                }
            }
        }
        
        if let windowRef = foundWindow {
            let raiseResult = AXUIElementPerformAction(windowRef, kAXRaiseAction as CFString)
            let focusResult = AXUIElementSetAttributeValue(windowRef, kAXFocusedAttribute as CFString, kCFBooleanTrue)
            let frontmostResult = AXUIElementSetAttributeValue(appRef, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
            let activateResult = NSRunningApplication(processIdentifier: pid)?.activate()
            
            if raiseResult == .success && focusResult == .success && frontmostResult == .success && activateResult == true {
                print("Debug: Successfully raised, focused, and activated window")
            } else {
                print("Error bringing window to front. Raise result: \(raiseResult.rawValue), Focus result: \(focusResult.rawValue), Frontmost result: \(frontmostResult), Activate result: \(String(describing: activateResult))")
            }
        } else {
            print("Debug: No matching window found. Attempting closest match fallback.")
            AXUIElementSetAttributeValue(appRef, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
            NSRunningApplication(processIdentifier: pid)?.activate(options: [.activateAllWindows])
        }
    }
    
    static func resetCache() {
        imageCache.removeAll()
        iconCache.removeAll()
    }
    
    // Utility function to list active windows for a specific application
    static func activeWindows(for applicationName: String) async throws -> [WindowInfo] {
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        let group = LimitedTaskGroup<WindowInfo?>(maxConcurrentTasks: 4) // Adjust this number as needed

        for window in content.windows {
            if let app = window.owningApplication,
               applicationName.isEmpty || (app.applicationName.contains(applicationName) && !applicationName.isEmpty) {
                await group.addTask {
                    try await fetchWindowInfo(window: window, applicationName: applicationName)
                }
            }
        }

        let results = try await group.waitForAll()
        return results.compactMap { $0 }
    }

    private static func fetchWindowInfo(window: SCWindow, applicationName: String) async throws -> WindowInfo? {
        // Check if the window is in the default user space layer and is not fully transparent
        let windowID = window.windowID
        guard let windowInfoDict = CGWindowListCopyWindowInfo(.optionIncludingWindow, windowID) as? [[String: AnyObject]],
              let windowLayer = windowInfoDict.first?[kCGWindowLayer as String] as? Int,
              windowLayer == 0,
              let windowAlpha = windowInfoDict.first?[kCGWindowAlpha as String] as? Double,
              windowAlpha > 0,
              let owningApplication = window.owningApplication else {
            return nil
        }

        var windowInfo = WindowInfo(
            id: windowID,
            window: window,
            appName: owningApplication.applicationName,
            bundleID: owningApplication.bundleIdentifier,
            windowName: window.title,
            image: nil
        )

        do {
            windowInfo.image = try await captureWindowImage(windowInfo: windowInfo)
            return windowInfo
        } catch {
            print("Error capturing window image: \(error)")
            return nil
        }
    }
}

actor LimitedTaskGroup<T> {
    private var tasks: [Task<T, Error>] = []
    private let maxConcurrentTasks: Int
    private var runningTasks = 0
    
    init(maxConcurrentTasks: Int) {
        self.maxConcurrentTasks = maxConcurrentTasks
    }
    
    func addTask(_ operation: @escaping () async throws -> T) {
        let task = Task {
            while self.runningTasks >= self.maxConcurrentTasks {
                try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
            self.runningTasks += 1
            defer { self.runningTasks -= 1 }
            return try await operation()
        }
        tasks.append(task)
    }
    
    func waitForAll() async throws -> [T] {
        var results: [T] = []
        for task in tasks {
            do {
                let result = try await task.value
                results.append(result)
            } catch {
                print("Task failed with error: \(error)")
            }
        }
        tasks.removeAll()
        return results
    }
}
