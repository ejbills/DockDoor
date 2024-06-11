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

struct WindowUtil {

    private static var cachedShareableContent: SCShareableContent? = nil

    // MARK: - Window Listing Functions
    
    static func listDockApplicationWindows() async -> [String: [WindowInfo]] {
        var result = [String: [WindowInfo]]()
        
        // Fetch shareable content only once if it hasn't been cached
        if cachedShareableContent == nil {
            cachedShareableContent = try? await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: true
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
                windowName: window.title,
                image: nil // We'll capture the image later
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
        guard CGPreflightScreenCaptureAccess() else {
            print("Debug: Screen recording permission not granted")
            MessageUtil.showMessage(title: "Permission error",
                                    message: "You need to give DockDoor access to Screen Recording in Security & Privacy for it to function.",
                                    completion: { _ in SystemPreferencesHelper.openScreenRecordingPreferences() })
            throw NSError(domain: "com.dockdoor.permission", code: 2, userInfo: [NSLocalizedDescriptionKey: "Screen recording permission not granted"])
        }
        
        
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
    }
    
    // Utility function to list active windows for a specific application
    static func activeWindows(for applicationName: String) async -> [WindowInfo] {
        guard let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true) else {
            print("Debug: Failed to fetch shareable content")
            return []
        }
        
        var windowInfos: [WindowInfo] = []
        
        for window in content.windows {
            if let app = window.owningApplication, app.applicationName == applicationName {
                var windowInfo = WindowInfo(
                    id: window.windowID,
                    window: window,
                    appName: app.applicationName,
                    windowName: window.title,
                    image: nil
                )
                do {
                    windowInfo.image = try await WindowUtil().captureWindowImage(windowInfo: windowInfo)
                } catch {
                    print("Error capturing window image: \(error)")
                }
                windowInfos.append(windowInfo)
            }
        }
        
        return windowInfos
    }
}
