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
    private var refreshTimer: Timer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupDockObserver()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupDockObserver()
    }

    private func setupDockObserver() {
        // Access the Dock application and fetch icons
        refreshDockIcons()

        // Add global monitor for mouse movements
        dockTrackingMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .mouseEntered, .mouseExited]) { [weak self] event in
            self?.handleMouseEvent(event)
        }
        
        print("Global mouse event monitor set up")
        
        // Set up the timer to refresh icon frames
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshDockIcons()
        }
    }

    private func refreshDockIcons() {
        dockIcons.removeAll()
        iconFrames.removeAll()
        iconNames.removeAll()
        
        guard let dockApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            print("Dock application not found.")
            return
        }

        let dockAXUIElement = AXUIElementCreateApplication(dockApp.processIdentifier)
        
        // Determine Dock position
        let dockPosition = getDockPosition()

        // Fetch children (i.e., the icons in the Dock)
        var children: CFArray?
        if AXUIElementCopyAttributeValues(dockAXUIElement, kAXChildrenAttribute as CFString, 0, 999, &children) == .success,
           let dockElements = children as? [AXUIElement] {
            for element in dockElements {
                processDockElement(element, dockPosition: dockPosition)
            }
            print("Total number of dock icons: \(dockIcons.count)")
        } else {
            print("Failed to get dock icons")
        }
    }

    private func processDockElement(_ element: AXUIElement, dockPosition: DockPosition) {
        var children: CFArray?

        if AXUIElementCopyAttributeValues(element, kAXChildrenAttribute as CFString, 0, 999, &children) == .success,
           let childElements = children as? [AXUIElement] {
            for child in childElements {
                processDockIcon(child, dockPosition: dockPosition)
            }
        } else {
            processDockIcon(element, dockPosition: dockPosition)
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

    // Handle the global mouse event
    private func handleMouseEvent(_ event: NSEvent) {
        let mouseLocation = convert(NSEvent.mouseLocation, from: nil)

        // Debug print - mouse location
        print("Raw Mouse Location: \(mouseLocation)")

        var hoveredOverIcon = false

        for icon in dockIcons {
            if let frame = iconFrames[icon] {
                if frame.contains(mouseLocation) {
                    if let appName = iconNames[icon] {
                        print("Hovered over: \(appName)")
                    } else {
                        print("Hovered over unknown element at frame: \(frame)")
                    }
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
        if let monitor = dockTrackingMonitor {
            NSEvent.removeMonitor(monitor)
        }
        refreshTimer?.invalidate()
    }
}
