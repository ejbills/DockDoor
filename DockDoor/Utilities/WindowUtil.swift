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
    
    private static var cachedShareableContent: SCShareableContent? = nil
    
    private static var imageCache: [CGWindowID: CachedImage] = [:]
    private static var iconCache: [String: CachedAppIcon] = [:]
    
    private static var cacheExpirySeconds: Double = 600 // 10 mins
    
    static func clearExpiredCache() {
        let now = Date()
        imageCache = imageCache.filter { now.timeIntervalSince($0.value.timestamp) <= cacheExpirySeconds }
        iconCache = iconCache.filter { now.timeIntervalSince($0.value.timestamp) <= cacheExpirySeconds }
    }
    
    // MARK: - Helper Functions
        
    func captureWindowImage(windowInfo: WindowInfo, completion: @escaping (Result<CGImage, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                WindowUtil.clearExpiredCache()
                
                if let cachedImage = WindowUtil.imageCache[windowInfo.id],
                   Date().timeIntervalSince(cachedImage.timestamp) <= WindowUtil.cacheExpirySeconds {
                    DispatchQueue.main.async {
                        completion(.success(cachedImage.image))
                    }
                    return
                }
                
                guard CGPreflightScreenCaptureAccess() else {
                    DispatchQueue.main.async {
                        print("Debug: Screen recording permission not granted")
                        MessageUtil.showMessage(title: "Permission error",
                                                message: "You need to give DockDoor access to Screen Recording in Security & Privacy for it to function.",
                                                completion: { _ in SystemPreferencesHelper.openScreenRecordingPreferences() })
                        completion(.failure(NSError(domain: "com.dockdoor.permission", code: 2, userInfo: [NSLocalizedDescriptionKey: "Screen recording permission not granted"])))
                    }
                    return
                }
                
                let id = windowInfo.id
                let frame = windowInfo.windowBounds
                
                guard let image = CGWindowListCreateImage(frame, .optionIncludingWindow, id, [.boundsIgnoreFraming, .bestResolution]) else {
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "com.dockdoor.error", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to capture window image"])))
                    }
                    return
                }
                
                let cachedImage = CachedImage(image: image, timestamp: Date())
                WindowUtil.imageCache[windowInfo.id] = cachedImage
                
                DispatchQueue.main.async {
                    completion(.success(image))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
        
    func captureWindowImage(windowInfo: WindowInfo) throws -> CGImage {
        WindowUtil.clearExpiredCache()
        
        if let cachedImage = WindowUtil.imageCache[windowInfo.id],
           Date().timeIntervalSince(cachedImage.timestamp) <= WindowUtil.cacheExpirySeconds {
            return cachedImage.image
        }
        
        guard CGPreflightScreenCaptureAccess() else {
            print("Debug: Screen recording permission not granted")
            MessageUtil.showMessage(title: "Permission error",
                                    message: "You need to give DockDoor access to Screen Recording in Security & Privacy for it to function.",
                                    completion: { _ in SystemPreferencesHelper.openScreenRecordingPreferences() })
            throw NSError(domain: "com.dockdoor.permission", code: 2, userInfo: [NSLocalizedDescriptionKey: "Screen recording permission not granted"])
        }
        
        let id = windowInfo.window.windowID
        let frame = windowInfo.window.frame
        
        guard let image = CGWindowListCreateImage(frame, .optionIncludingWindow, id, [.boundsIgnoreFraming, .nominalResolution]) else {
            throw NSError(domain: "com.dockdoor.error", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to capture window image"])
        }
        
        let cachedImage = CachedImage(image: image, timestamp: Date())
        WindowUtil.imageCache[windowInfo.id] = cachedImage
        
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
        cachedShareableContent = nil
        imageCache.removeAll()
        iconCache.removeAll()
    }
    
    // Utility function to list active windows for a specific application
    static func activeWindows(for applicationName: String) async -> [WindowInfo] {
        guard let content = try? await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true) else {
            print("Debug: Failed to fetch shareable content")
            return []
    static func activeWindows(for applicationName: String, completion: @escaping ([WindowInfo]) -> Void) {
        // Use CGWindowListCopyWindowInfo to get windows across all spaces
        let options: CGWindowListOption = [.optionAll, .excludeDesktopElements]
        guard let windowListInfo = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as NSArray? as? [[String: AnyObject]] else {
            print("Debug: Failed to fetch window list info")
            completion([])
            return
        }
        
        var windowInfos: [WindowInfo] = []
        let group = DispatchGroup()
        
        for window in content.windows {
            // Check if the app name matches OR if applicationName is empty (which is used to get all active windows on device)
            if let app = window.owningApplication,
               applicationName.isEmpty || (app.applicationName.contains(applicationName) && !applicationName.isEmpty),
               self.isDockApplication(pid: app.processID) {
                var windowInfo = WindowInfo(
                    id: window.windowID,
                    window: window,
                    appName: app.applicationName,
                    windowName: window.title,
                    image: nil
                )
                
                do {
                    windowInfo.image = try WindowUtil().captureWindowImage(windowInfo: windowInfo)
                } catch {
                    print("Error capturing window image: \(error)")
                group.enter()
                WindowUtil().captureWindowImage(windowInfo: windowInfo) { result in
                    switch result {
                    case .success(let image):
                        windowInfo.image = image
                        windowInfos.append(windowInfo)
                    case .failure(let error):
                        print("Error capturing window image: \(error)")
                        windowBlacklist.insert(windowID)
                    }
                    group.leave()
                }
                windowInfos.append(windowInfo)
            }
        }
        
        group.notify(queue: .main) {
            completion(windowInfos)
        }
    }
    
    private static func filterValidWindows(_ windowListInfo: [[String: AnyObject]]) -> [[String: AnyObject]] {
        return windowListInfo.filter { windowInfo in
            guard let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID,
                  let windowLayer = windowInfo[kCGWindowLayer as String] as? Int else {
                return false
            }
            
            // Additional filtering criteria
            let isBlacklisted = windowBlacklist.contains(windowID)
            let isUserSpace = windowLayer == 0
                        
            return !isBlacklisted && isUserSpace
        }
    }
}
