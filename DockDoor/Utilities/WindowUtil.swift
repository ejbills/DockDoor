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
}

struct WindowUtil {
    
    private static var cachedShareableContent: SCShareableContent? = nil
    
    // MARK: - Window Listing Functions
    
    static func listDockApplicationWindows() async -> [String: [WindowInfo]] {
        var result = [String: [WindowInfo]]()
        
        // Fetch shareable content only once if it hasn't been cached
        if cachedShareableContent == nil {
            cachedShareableContent = try? await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
        }
        
        guard let content = cachedShareableContent else { return result } // Return empty result if no content
        
        let windows = content.windows.filter { window in
            if let pid = window.owningApplication?.processID {
                return isDockApplication(pid: pid)
            }
            return false
        }
        
        for window in windows {
            guard let app = window.owningApplication else { continue }
            let info = WindowInfo(
                id: window.windowID,
                window: window,
                appName: app.applicationName,
                windowName: window.title
            )
            result[app.applicationName, default: []].append(info)
        }
        return result
    }
    
    // MARK: - Helper Functions
    
    private static func isDockApplication(pid: Int32) -> Bool {
        return NSWorkspace.shared.runningApplications.contains {
            $0.processIdentifier == pid && $0.activationPolicy == .regular
        }
    }
    
    func captureWindowImage(windowInfo: WindowInfo) async throws -> CGImage {
        let filter = SCContentFilter(desktopIndependentWindow: windowInfo.window)
        let config = SCStreamConfiguration()
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }
    
    // MARK: - Window Manipulation Functions
    
    static func bringWindowToFront(windowInfo: WindowInfo) {
        guard let pid = windowInfo.window.owningApplication?.processID else {
            print("Debug: Failed to get PID from windowInfo")
            return
        }
        
        guard AXIsProcessTrusted() else {
            print("Debug: Accessibility permission not granted")
            MessageUtil.showMessage(title: "Permission error",
                                    message: "You need to give DockDoor access to the accessibility API in order for it to function.",
                                    completion: { _ in SystemPreferencesHelper.openAccessibilityPreferences() })
            return
        }
        
        print("Debug: Trying to bring window with ID \(windowInfo.id) to front for PID \(pid)")
        
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
            
            if raiseResult == .success && focusResult == .success {
                print("Debug: Successfully raised and focused window")
            } else {
                print("Error raising window: \(raiseResult.rawValue) or focusing window: \(focusResult.rawValue)")
            }
        } else {
            print("Debug: No matching window found. Attempting closest match fallback.")
            AXUIElementSetAttributeValue(appRef, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        }
    }
    
    static func resetCache() {
        cachedShareableContent = nil
    }
}
