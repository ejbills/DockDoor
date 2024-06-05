//  DockObserver.swift
//  DockDoor
//
//  Created by Ethan Bills on 6/3/24.
//

import Cocoa
import ApplicationServices

class DockObserver: NSView {
    private var dockIcons: [AXUIElement] = []
    private var iconFrames: [AXUIElement: CGRect] = [:]
    private var iconNames: [AXUIElement: String] = [:]
    private var dockTrackingMonitor: Any?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupDockObserver()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupDockObserver()
    }
    
    private func setupDockObserver() {
        // Initially fetch icons for active applications in the Dock
        refreshDockIcons()
        
        // Add global monitor for mouse movements
        dockTrackingMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .mouseEntered, .mouseExited]) { [weak self] event in
            self?.handleMouseEvent(event)
        }
        
        print("Global mouse event monitor set up")
        
        // Observe application notifications for add/remove
        let notificationCenter = NSWorkspace.shared.notificationCenter
        notificationCenter.addObserver(self, selector: #selector(applicationDidChange(_:)), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(applicationDidChange(_:)), name: NSWorkspace.didTerminateApplicationNotification, object: nil)
    }
    
    @objc private func applicationDidChange(_ notification: Notification) {
        // Refresh the dock icons when applications are launched or terminated
        refreshDockIcons()
    }
    
    private func refreshDockIcons() {
        dockIcons.removeAll()
        iconFrames.removeAll()
        iconNames.removeAll()

        guard let dockApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            print("Dock application not found.")
            return
        }

        let runningApps = Set(NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }.map { $0.processIdentifier })
        
        let dockAXUIElement = AXUIElementCreateApplication(dockApp.processIdentifier)
        
        // Determine Dock position
        let dockPosition = getDockPosition()

        // Fetch children (i.e., the icons in the Dock)
        var children: CFArray?
        if AXUIElementCopyAttributeValues(dockAXUIElement, kAXChildrenAttribute as CFString, 0, 999, &children) == .success,
           let dockElements = children as? [AXUIElement] {
            for element in dockElements {
                processDockElement(element, dockPosition: dockPosition, runningApps: runningApps)
            }
            print("Total number of dock icons: \(dockIcons.count)")
        } else {
            print("Failed to get dock icons")
        }
    }

    private func processDockElement(_ element: AXUIElement, dockPosition: DockPosition, runningApps: Set<pid_t>) {
        var children: CFArray?

        if AXUIElementCopyAttributeValues(element, kAXChildrenAttribute as CFString, 0, 999, &children) == .success,
           let childElements = children as? [AXUIElement] {
            print("Found child elements under current dock item: \(childElements.count)")
            for child in childElements {
                var roleValue: CFTypeRef?
                var subroleValue: CFTypeRef?

                let roleSuccess = AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleValue)
                let subroleSuccess = AXUIElementCopyAttributeValue(child, kAXSubroleAttribute as CFString, &subroleValue)

                if roleSuccess == .success, subroleSuccess == .success,
                   let role = roleValue as? String, role == kAXDockItemRole,
                   let subrole = subroleValue as? String, subrole == kAXApplicationDockItemSubrole {

                    var isRunningValue: CFTypeRef?
                    let isRunningSuccess = AXUIElementCopyAttributeValue(child, kAXIsApplicationRunningAttribute as CFString, &isRunningValue)
                    let isRunning = (isRunningValue as? Bool) == true

                    print("Child Element Role: \(role), Subrole: \(subrole), Is Running Retrieval Success: \(isRunningSuccess), Is Running: \(isRunning)")

                    if isRunningSuccess == .success, isRunning {
                        // Only process elements that are actually running applications
                        print("Processing child element as running application")
                        processDockIcon(child, dockPosition: dockPosition)
                    }
                } else {
                    print("Skipping child element with role: \(roleValue ?? "unknown role" as CFTypeRef), subrole: \(subroleValue ?? "unknown subrole" as CFTypeRef)")
                }
            }
        } else {
            var roleValue: CFTypeRef?
            var subroleValue: CFTypeRef?

            let roleSuccess = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue)
            let subroleSuccess = AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subroleValue)

            if roleSuccess == .success, subroleSuccess == .success,
               let role = roleValue as? String, role == kAXDockItemRole,
               let subrole = subroleValue as? String, subrole == kAXApplicationDockItemSubrole {

                var isRunningValue: CFTypeRef?
                let isRunningSuccess = AXUIElementCopyAttributeValue(element, kAXIsApplicationRunningAttribute as CFString, &isRunningValue)
                let isRunning = (isRunningValue as? Bool) == true

                print("Element Role: \(role), Subrole: \(subrole), Is Running Retrieval Success: \(isRunningSuccess), Is Running: \(isRunning)")

                if isRunningSuccess == .success, isRunning {
                    // Process the element as a running application icon
                    print("Processing element as running application")
                    processDockIcon(element, dockPosition: dockPosition)
                }
            } else {
                print("Skipping element with role: \(roleValue ?? "unknown role" as CFTypeRef), subrole: \(subroleValue ?? "unknown subrole" as CFTypeRef)")
            }
        }
    }

    private func processDockIcon(_ element: AXUIElement, dockPosition: DockPosition) {
        if let frame = getFrame(of: element) {
            let adjustedFrame = adjustFrame(frame, for: dockPosition)
            dockIcons.append(element)
            iconFrames[element] = adjustedFrame
            if let name = getAppName(of: element) {
                iconNames[element] = name
            }
        }
        print("Updated dock icons for active applications.")
    }
    
    private func getFrame(of element: AXUIElement) -> CGRect? {
        var position: CFTypeRef?
        var size: CFTypeRef?
        
        if AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position) == .success,
           AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size) == .success {
            
            var pos = CGPoint.zero
            var sizeValue = CGSize.zero
            
            if let posValue = position,
               let sizeValueCF = size {
                AXValueGetValue(posValue as! AXValue, .cgPoint, &pos)
                AXValueGetValue(sizeValueCF as! AXValue, .cgSize, &sizeValue)
                
                // Adjust position if negative (e.g., dock is hidden)
                if pos.x < 0 || pos.y < 0 {
                    pos.x = max(pos.x, 0)
                    pos.y = max(pos.y, 0)
                }
                
                // Debug Print for position and size
                print("Element Position: \(pos), Size: \(sizeValue)")
                
                return CGRect(origin: pos, size: sizeValue)
            }
        }
        return nil
    }
    
    private func adjustFrame(_ frame: CGRect, for dockPosition: DockPosition) -> CGRect {
        var adjustedFrame = frame
        
        if dockPosition == .bottom {
            if let mainScreen = NSScreen.screens.first {
                let screenY = mainScreen.frame.minY
                let screenHeight = mainScreen.frame.height
                adjustedFrame.origin.y = screenHeight + screenY - frame.maxY
            }
        } else if dockPosition == .left || dockPosition == .right {
            let mainScreenHeight = NSScreen.main?.frame.height ?? 0
            adjustedFrame.origin.y = mainScreenHeight - frame.origin.y - frame.height
        }
        
        return adjustedFrame
    }
    
    private func getDockPosition() -> DockPosition {
        let dockDefaults = UserDefaults(suiteName: "com.apple.dock")
        let orientation = dockDefaults?.string(forKey: "orientation") ?? "bottom"
        
        switch orientation {
        case "bottom":
            return .bottom
        case "left":
            return .left
        case "right":
            return .right
        default:
            return .unknown
        }
    }
    
    private func getAppName(of element: AXUIElement) -> String? {
        var appName: CFTypeRef?
        
        if AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &appName) == .success,
           let name = appName as? String {
            return name
        }
        return nil
    }
    
    // Handle mouse events to detect hover over dock icons
    private func handleMouseEvent(_ event: NSEvent) {
        let mouseLocation = NSEvent.mouseLocation
        
        var hoveredOverIcon = false
        for (appElement, frame) in iconFrames {
            if frame.contains(mouseLocation) {
                if let appName = iconNames[appElement] {
                    print("Hovered over: \(appName)")
                    hoveredOverIcon = true
                    break
                }
            }
        }
        
        if !hoveredOverIcon {
            print("Not hovering over any dock icon")
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        if let monitor = dockTrackingMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
