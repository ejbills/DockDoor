//  DockObserver.swift
//  DockDoor
//
//  Created by Ethan Bills on 6/3/24.
//

import Cocoa
import ApplicationServices

final class DockObserver {
    static let shared = DockObserver()
    
    private var lastAppUnderMouse: NSRunningApplication?
    private var lastMouseLocation: CGPoint?
    private let mouseUpdateThreshold: CGFloat = 5.0
    private var eventTap: CFMachPort?
    
    private var hoverProcessingTask: Task<Void, Error>?
    private var isProcessing: Bool = false
    
    private var dockAppProcessIdentifier: pid_t? = nil
    
    private init() {
        setupEventTap()
    }
    
    deinit {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0), CFRunLoopMode.commonModes)
        }
    }
    
    private func setupEventTap() {
        guard AXIsProcessTrusted() else {
            print("Debug: Accessibility permission not granted")
            MessageUtil.showMessage(title: String(localized: "Permission error"),
                                    message: String(localized: "You need to give DockDoor access to the accessibility API in order for it to function."),
                                    completion: { _ in SystemPreferencesHelper.openAccessibilityPreferences() })
            return
        }
        
        func eventTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
            let observer = Unmanaged<DockObserver>.fromOpaque(refcon!).takeUnretainedValue()
            
            if type == .mouseMoved {
                let mouseLocation = event.location
                observer.handleMouseEvent(mouseLocation: mouseLocation)
            } else if type == .rightMouseDown || type == .leftMouseDown || type == .otherMouseDown {
                if observer.getCurrentAppUnderMouse() != nil { // Required to allow clicking the traffic light buttons in the preview
                    SharedPreviewWindowCoordinator.shared.hidePreviewWindow()
                }
            }
            
            return Unmanaged.passUnretained(event)
        }
        
        let eventTypes: [CGEventType] = [.mouseMoved, .rightMouseDown, .leftMouseDown, .otherMouseDown, .leftMouseUp]
        let eventsOfInterest: CGEventMask = eventTypes
            .reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        
        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventsOfInterest,
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
    
    private func handleMouseEvent(mouseLocation: CGPoint) {
        hoverProcessingTask?.cancel()
        
        hoverProcessingTask = Task { [weak self] in
            guard let self = self else { return }
            try Task.checkCancellation()
            self.processMouseEvent(mouseLocation: mouseLocation)
        }
    }
    
    private func processMouseEvent(mouseLocation: CGPoint) {
        guard !isProcessing, !ScreenCenteredFloatingWindow.shared.windowSwitcherActive else { return }
        isProcessing = true
        
        defer {
            isProcessing = false
        }
        
        guard let lastMouseLocation = lastMouseLocation else {
            self.lastMouseLocation = mouseLocation
            return
        }
        
        // Ignore minor movements
        if abs(mouseLocation.x - lastMouseLocation.x) < mouseUpdateThreshold &&
            abs(mouseLocation.y - lastMouseLocation.y) < mouseUpdateThreshold {
            return
        }
        self.lastMouseLocation = mouseLocation
        
        // Capture the current mouseLocation
        let currentMouseLocation = mouseLocation
        
        if let currentAppUnderMouse = getCurrentAppUnderMouse() {
            if currentAppUnderMouse != lastAppUnderMouse {
                lastAppUnderMouse = currentAppUnderMouse
                
                Task { [weak self] in
                    guard let self = self else { return }
                    do {
                        let appWindows = try WindowsUtil.getRunningAppWindows(for: currentAppUnderMouse)
                        await MainActor.run {
                            if appWindows.isEmpty {
                                SharedPreviewWindowCoordinator.shared.hidePreviewWindow()
                            } else {
                                let mouseScreen = DockObserver.screenContainingPoint(currentMouseLocation) ?? NSScreen.main!
                                let convertedMouseLocation = DockObserver.nsPointFromCGPoint(currentMouseLocation, forScreen: mouseScreen)
                                // Show HoverWindow (using shared instance)
                                SharedPreviewWindowCoordinator.shared.showPreviewWindow(
                                    appName: currentAppUnderMouse.localizedName!,
                                    windows: appWindows,
                                    mouseLocation: convertedMouseLocation,
                                    mouseScreen: mouseScreen,
                                    onWindowTap: { [weak self] in
                                        SharedPreviewWindowCoordinator.shared.hidePreviewWindow()
                                        self?.lastAppUnderMouse = nil
                                    }
                                )
                            }
                        }
                    } catch {
                        await MainActor.run {
                            print("Error fetching active windows: \(error)")
                        }
                    }
                }
            }
        } else {
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let mouseScreen = DockObserver.screenContainingPoint(currentMouseLocation) ?? NSScreen.main!
                let convertedMouseLocation = DockObserver.nsPointFromCGPoint(currentMouseLocation, forScreen: mouseScreen)
                if !SharedPreviewWindowCoordinator.shared.frame.contains(convertedMouseLocation) {
                    self.lastAppUnderMouse = nil
                    SharedPreviewWindowCoordinator.shared.hidePreviewWindow()
                }
            }
        }
    }
    
    func getDockIconFrameAtLocation(_ mouseLocation: CGPoint) -> CGRect? {
        guard let hoveredDockItem = gethoveredDockItem() else {
            print("No selected dock item found")
            return nil
        }
        
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        let positionResult = AXUIElementCopyAttributeValue(hoveredDockItem, kAXPositionAttribute as CFString, &positionValue)
        let sizeResult = AXUIElementCopyAttributeValue(hoveredDockItem, kAXSizeAttribute as CFString, &sizeValue)
        
        guard positionResult == .success, sizeResult == .success else {
            print("Failed to get position or size for selected dock item")
            return nil
        }
        
        let position = positionValue as! AXValue
        let size = sizeValue as! AXValue
        var positionPoint = CGPoint.zero
        var sizeCGSize = CGSize.zero
        AXValueGetValue(position, .cgPoint, &positionPoint)
        AXValueGetValue(size, .cgSize, &sizeCGSize)
        
        let iconRect = CGRect(origin: positionPoint, size: sizeCGSize)
        
        // Adjust mouse location to match the coordinate system of the dock icons
        let adjustedMouseLocation = CGPoint(
            x: mouseLocation.x,
            y: (DockObserver.screenContainingPoint(mouseLocation)?.frame.height ?? NSScreen.main!.frame.height) - mouseLocation.y
        )
        
        print("Checking icon rect: \(iconRect) with adjusted mouse location: \(adjustedMouseLocation)")
        
        if iconRect.contains(adjustedMouseLocation) {
            print("Matched icon rect: \(iconRect)")
            return iconRect
        }
        
        print("No matching icon rect found")
        return nil
    }
    
    //                          var role: CFTypeRef?
    //                        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
    //                        return role as? String ?? ""
    //                       let dockListRole = getRole(element: dockItems.first!)
    
    private func gethoveredDockItem() -> AXUIElement? {
        guard let dockAppPID = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.processIdentifier else {
            print("Dock does found in running applications")
            return nil
        }
        
        let dockAppElement = AXUIElementCreateApplication(dockAppPID)
        
        var dockItems: CFTypeRef?
        guard AXUIElementCopyAttributeValue(dockAppElement, kAXChildrenAttribute as CFString, &dockItems) == .success , let dockItems = dockItems as? [AXUIElement], !dockItems.isEmpty else {
            print("Failed to get dock items or no dock items found")
            return nil
        }
        
        var hoveredDockItem: CFTypeRef?
        guard AXUIElementCopyAttributeValue(dockItems.first!, kAXSelectedChildrenAttribute as CFString, &hoveredDockItem) == .success, !dockItems.isEmpty, let hoveredDockItem = (hoveredDockItem as! [AXUIElement]).first else {
            // no app under nouse
            return nil
        }
        
        return hoveredDockItem
    }
    
    func getCurrentAppUnderMouse() -> NSRunningApplication? {
        guard let hoveredDockItem = gethoveredDockItem() else {
            return nil
        }
        
        var appURL: CFTypeRef?
        guard AXUIElementCopyAttributeValue(hoveredDockItem, kAXURLAttribute as CFString, &appURL) == .success, let appURL = appURL as? NSURL as? URL else {
            print("Failed to get app URL or convert NSURL to URL")
            return nil
        }
        
        let budle = Bundle(url: appURL)
        guard let bundleIdentifier = budle?.bundleIdentifier else {
            print("App has no valid bundle. app url: \(appURL)") // For example: scrcpy, Android studio emulator
            
            var dockItemTitle: CFTypeRef?
            guard AXUIElementCopyAttributeValue(hoveredDockItem, kAXTitleAttribute as CFString, &dockItemTitle) == .success, let dockItemTitle = dockItemTitle as? String else {
                print("Failed to get dock item title")
                return nil
            }
            
            if let app = WindowsUtil.findRunningApplicationByName(named: dockItemTitle) {
                return app
            } else {
                return nil
            }
        }
        
        guard let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first else {
            print("Current App is not running (\(bundleIdentifier))")
            return nil
        }
        
        print("Current App is running (\(runningApp))")
        return runningApp
    }
    
    static func screenContainingPoint(_ point: CGPoint) -> NSScreen? {
        let screens = NSScreen.screens
        guard let primaryScreen = screens.first else { return nil }
        
        for screen in screens {
            let (offsetLeft, offsetTop) = computeOffsets(for: screen, primaryScreen: primaryScreen)
            
            if point.x >= offsetLeft && point.x <= offsetLeft + screen.frame.size.width &&
                point.y >= offsetTop && point.y <= offsetTop + screen.frame.size.height {
                return screen
            }
        }
        
        return primaryScreen
    }
    
    static func nsPointFromCGPoint(_ point: CGPoint, forScreen: NSScreen?) -> NSPoint {
        guard let screen = forScreen,
              let primaryScreen = NSScreen.screens.first else {
            return NSPoint(x: point.x, y: point.y)
        }
        
        let (_, offsetTop) = computeOffsets(for: screen, primaryScreen: primaryScreen)
        
        let y: CGFloat
        if screen == primaryScreen {
            y = screen.frame.size.height - point.y
        } else {
            let screenBottomOffset = primaryScreen.frame.size.height - (screen.frame.size.height + offsetTop)
            y = screen.frame.size.height + screenBottomOffset - (point.y - offsetTop)
        }
        
        return NSPoint(x: point.x, y: y)
    }
    
    static func cgPointFromNSPoint(_ point: CGPoint, forScreen: NSScreen?) -> CGPoint {
        guard let screen = forScreen,
              let primaryScreen = NSScreen.screens.first else {
            return CGPoint(x: point.x, y: point.y)
        }
        
        let (_, offsetTop) = computeOffsets(for: screen, primaryScreen: primaryScreen)
        let menuScreenHeight = screen.frame.maxY
        
        return CGPoint(x: point.x, y: menuScreenHeight - point.y + offsetTop)
    }
    
    private static func computeOffsets(for screen: NSScreen, primaryScreen: NSScreen) -> (CGFloat, CGFloat) {
        var offsetLeft = screen.frame.origin.x
        var offsetTop = primaryScreen.frame.size.height - (screen.frame.origin.y + screen.frame.size.height)
        
        if screen == primaryScreen {
            offsetTop = 0
            offsetLeft = 0
        }
        
        return (offsetLeft, offsetTop)
    }
}
