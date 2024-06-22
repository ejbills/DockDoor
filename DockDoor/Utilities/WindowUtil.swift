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
                let frame = windowInfo.window.frame

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
            }
        }
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
        }

        var windowInfos: [WindowInfo] = []

        await withTaskGroup(of: WindowInfo?.self) { group in
            for window in content.windows {
                if let app = window.owningApplication,
                   applicationName.isEmpty || (app.applicationName.contains(applicationName) && !applicationName.isEmpty) {
                    group.addTask {
                        // Check if the window is in the default user space layer and is not fully transparent
                        let windowID = window.windowID
                        guard let windowInfoDict = CGWindowListCopyWindowInfo(.optionIncludingWindow, windowID) as? [[String: AnyObject]],
                              let windowLayer = windowInfoDict.first?[kCGWindowLayer as String] as? Int,
                              windowLayer == 0,
                              let windowAlpha = windowInfoDict.first?[kCGWindowAlpha as String] as? Double,
                              windowAlpha > 0 else {
                            return nil
                        }

                        var windowInfo = WindowInfo(
                            id: windowID,
                            window: window,
                            appName: app.applicationName,
                            windowName: window.title,
                            image: nil
                        )

                        let result = await WindowUtil().captureWindowImageAsync(windowInfo: windowInfo)
                        switch result {
                        case .success(let image):
                            windowInfo.image = image
                            return windowInfo
                        case .failure(let error):
                            print("Error capturing window image: \(error)")
                            return nil
                        }
                    }
                }
            }

            for await result in group {
                if let windowInfo = result {
                    windowInfos.append(windowInfo)
                }
            }
        }

        return windowInfos
    }
}

extension WindowUtil {
    func captureWindowImageAsync(windowInfo: WindowInfo) async -> Result<CGImage, Error> {
        await withCheckedContinuation { continuation in
            self.captureWindowImage(windowInfo: windowInfo) { result in
                continuation.resume(returning: result)
            }
        }
    }
}
