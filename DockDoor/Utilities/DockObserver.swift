//  DockObserver.swift
//  DockDoor
//
//  Created by Ethan Bills on 6/3/24.
//

import Cocoa
import ApplicationServices

class DockObserver {
    static let shared = DockObserver()
    
    private var lastAppName: String?
    private var lastMouseLocation = CGPoint.zero
    private let mouseUpdateThreshold: CGFloat = 5.0
    private var eventTap: CFMachPort?
    
    private init() {
        setupEventTap()
    }
    
    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
    }
    
    private func setupEventTap() {
        guard AXIsProcessTrusted() else {
            print("Debug: Accessibility permission not granted")
            MessageUtil.showMessage(title: "Permission error",
                                    message: "You need to give DockDoor access to the accessibility API in order for it to function.",
                                    completion: { _ in SystemPreferencesHelper.openAccessibilityPreferences() })
            return
        }
        
        func eventTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
            let observer = Unmanaged<DockObserver>.fromOpaque(refcon!).takeUnretainedValue()
            
            if type == .mouseMoved {
                let mouseLocation = event.unflippedLocation
                observer.handleMouseEvent(mouseLocation: mouseLocation)
            }
            
            return Unmanaged.passRetained(event)
        }
        
        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << CGEventType.mouseMoved.rawValue),
            callback: eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        
        if let eventTap = eventTap {
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, CFRunLoopMode.commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
        } else {
            print("Failed to create CGEvent tap.")
        }
    }
    
    @objc private func handleMouseEvent(mouseLocation: CGPoint) {
        // Ignore minor movements
        if abs(mouseLocation.x - lastMouseLocation.x) < mouseUpdateThreshold &&
            abs(mouseLocation.y - lastMouseLocation.y) < mouseUpdateThreshold {
            return
        }
        lastMouseLocation = mouseLocation
        
        if let hoveredOverAppName = getDockIconAtLocation(mouseLocation) {
            if hoveredOverAppName != lastAppName {
                lastAppName = hoveredOverAppName
                
                Task {
                    let activeWindows = await WindowUtil.activeWindows(for: hoveredOverAppName)
                    
                    if activeWindows.isEmpty { hideHoverWindow() } else {
                        DispatchQueue.main.async {
                            // Show HoverWindow (using shared instance)
                            HoverWindow.shared.showWindow(
                                appName: hoveredOverAppName,
                                windows: activeWindows,
                                mouseLocation: mouseLocation,
                                onWindowTap: { self.hideHoverWindow() }
                            )
                        }
                    }
                }
            }
        } else if !HoverWindow.shared.frame.contains(mouseLocation) {
            lastAppName = nil
            hideHoverWindow()
        }
    }
    
    private func hideHoverWindow() {
        HoverWindow.shared.hideWindow() // Hide the shared HoverWindow
    }
    
    private func getDockIconAtLocation(_ mouseLocation: CGPoint) -> String? {
        guard let dockApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.dock" }) else {
            print("Dock application not found.")
            return nil
        }

        let axDockApp = AXUIElementCreateApplication(dockApp.processIdentifier)
        
        var dockItems: CFTypeRef?
        let dockItemsResult = AXUIElementCopyAttributeValue(axDockApp, kAXChildrenAttribute as CFString, &dockItems)

        guard dockItemsResult == .success, let items = dockItems as? [AXUIElement] else {
            print("Failed to get dock items")
            return nil
        }
        
        // Directly access the dock list element (index 1)
        // Find the list element within the Dock items
        let axList = items.first { (element) -> Bool in
            var role: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
            return (role as? String) == kAXListRole
        }

        guard axList != nil else {
            print("Failed to find the Dock list")
            return nil
        }

        var axChildren: CFTypeRef?
        AXUIElementCopyAttributeValue(axList!, kAXChildrenAttribute as CFString, &axChildren)

        guard let children = axChildren as? [AXUIElement] else {
            print("Failed to get children")
            return nil
        }

        // Determine the screen that the mouse is currently on
        guard let screen = DockObserver.screenContainingPoint(mouseLocation) else {
            return nil
        }

        // Convert mouseLocation to flipped coordinates for the specific screen
        let screenFrame = screen.frame
        let flippedMouseLocation = CGPoint(x: mouseLocation.x, y: screenFrame.maxY - mouseLocation.y)
        
        for element in children {
            var positionValue: CFTypeRef?
            var sizeValue: CFTypeRef?
            let positionResult = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue)
            let sizeResult = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue)

            if positionResult == .success, sizeResult == .success {
                let position = positionValue as! AXValue
                let size = sizeValue as! AXValue
                var positionPoint = CGPoint.zero
                AXValueGetValue(position, .cgPoint, &positionPoint)
                var sizeCGSize = CGSize.zero
                AXValueGetValue(size, .cgSize, &sizeCGSize)

                let iconRect = CGRect(origin: positionPoint, size: sizeCGSize)
                if iconRect.contains(flippedMouseLocation) {
                    var value: CFTypeRef?
                    let titleResult = AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &value)
                    
                    if titleResult == .success, let title = value as? String {
                        // Check if the app is running before returning the title.
                        var isRunningValue: CFTypeRef?
                        AXUIElementCopyAttributeValue(element, kAXIsApplicationRunningAttribute as CFString, &isRunningValue)
                        if (isRunningValue as? Bool) == true {
                            return title
                        }
                    }
                }
            }
        }
        
        return nil
    }

    static func screenContainingPoint(_ point: CGPoint) -> NSScreen? {
        for screen in NSScreen.screens {
            let screenFrame = screen.frame
            if screenFrame.contains(point) {
                return screen
            }
        }
        return nil
    }
}

extension Sequence {
    func asyncMap<T>(_ transform: @escaping (Element) async throws -> T) async rethrows -> [T] {
        return try await withThrowingTaskGroup(of: T.self) { group in
            for element in self {
                group.addTask { try await transform(element) }
            }
            return try await group.reduce(into: []) { $0.append($1) }
        }
    }
}
