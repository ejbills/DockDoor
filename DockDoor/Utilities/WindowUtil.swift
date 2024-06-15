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
    var appIcon: NSImage?
}

// Cache item structure
struct CachedImage {
    let image: CGImage
    let timestamp: Date
}

struct WindowUtil {
    
    private static var cachedShareableContent: SCShareableContent? = nil
    
    private static var imageCache: [CGWindowID: CachedImage] = [:]
    
    static func clearExpiredCache() {
        let now = Date()
        imageCache = imageCache.filter { now.timeIntervalSince($0.value.timestamp) <= 60 }
    }
    
    // MARK: - Helper Functions
    
    private static func isDockApplication(pid: Int32) -> Bool {
        return NSWorkspace.shared.runningApplications.contains {
            $0.processIdentifier == pid && $0.activationPolicy == .regular
        }
    }
    
    func captureWindowImage(windowInfo: WindowInfo) throws -> CGImage {
        WindowUtil.clearExpiredCache()
        
        if let cachedImage = WindowUtil.imageCache[windowInfo.id],
           Date().timeIntervalSince(cachedImage.timestamp) <= 60 {
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
    }
    
    // Utility function to list active windows for a specific application
    static func activeWindows(for applicationName: String) async -> [WindowInfo] {
        guard let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true) else {
            print("Debug: Failed to fetch shareable content")
            return []
        }
        
        var windowInfos: [WindowInfo] = []
        
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
                    image: nil,
                    appIcon: DockUtils.shared.getAppIcon(byName: app.applicationName)
                )
                do {
                    windowInfo.image = try WindowUtil().captureWindowImage(windowInfo: windowInfo)
                } catch {
                    print("Error capturing window image: \(error)")
                }
                windowInfos.append(windowInfo)
            }
        }
        
        return windowInfos
    }
}
