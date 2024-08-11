//  DockObserver.swift
//  DockDoor
//
//  Created by Ethan Bills on 6/3/24.
//

import ApplicationServices
import Cocoa

final class DockObserver {
    static let shared = DockObserver()

    private var lastAppName: String?
    private var lastMouseLocation: CGPoint?
    private let mouseUpdateThreshold: CGFloat = 5.0
    private var eventTap: CFMachPort?

    private var hoverProcessingTask: Task<Void, Error>?
    private var isProcessing: Bool = false

    private var dockAppProcessIdentifier: pid_t?

    private init() {
        setupEventTap()
        setupDockApp()
    }

    deinit {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0), CFRunLoopMode.commonModes)
        }
    }

    private func setupDockApp() {
        if let dockAppPid = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.dock" })?.processIdentifier {
            dockAppProcessIdentifier = dockAppPid
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

        func eventTapCallback(proxy _: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
            let observer = Unmanaged<DockObserver>.fromOpaque(refcon!).takeUnretainedValue()

            if type == .mouseMoved {
                let mouseLocation = event.location
                observer.handleMouseEvent(mouseLocation: mouseLocation)
            } else if type == .rightMouseDown || type == .leftMouseDown || type == .otherMouseDown {
                let mouseLocation = event.location
                if observer.isMouseWithinDock(mouseLocation) { // Required to allow clicking the traffic light buttons in the preview
                    SharedPreviewWindowCoordinator.shared.hideWindow()
                }
            }

            return Unmanaged.passUnretained(event)
        }

        let eventsOfInterest: CGEventMask = (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.otherMouseDown.rawValue)

        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventsOfInterest,
            callback: eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        if let eventTap {
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
            guard let self else { return }
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

        guard let lastMouseLocation else {
            self.lastMouseLocation = mouseLocation
            return
        }

        // Ignore minor movements
        if abs(mouseLocation.x - lastMouseLocation.x) < mouseUpdateThreshold,
           abs(mouseLocation.y - lastMouseLocation.y) < mouseUpdateThreshold
        {
            return
        }
        self.lastMouseLocation = mouseLocation

        // Capture the current mouseLocation
        let currentMouseLocation = mouseLocation

        if let dockIconAppName = getDockIconAtLocation(currentMouseLocation) {
            if dockIconAppName != lastAppName {
                lastAppName = dockIconAppName

                Task { [weak self] in
                    guard let self else { return }
                    do {
                        let activeWindows = try await WindowUtil.activeWindows(for: dockIconAppName)

                        await MainActor.run {
                            if activeWindows.isEmpty {
                                SharedPreviewWindowCoordinator.shared.hideWindow()
                            } else {
                                let mouseScreen = DockObserver.screenContainingPoint(currentMouseLocation) ?? NSScreen.main!
                                let convertedMouseLocation = DockObserver.nsPointFromCGPoint(currentMouseLocation, forScreen: mouseScreen)
                                // Show HoverWindow (using shared instance)
                                SharedPreviewWindowCoordinator.shared.showWindow(
                                    appName: dockIconAppName,
                                    windows: activeWindows,
                                    mouseLocation: convertedMouseLocation,
                                    mouseScreen: mouseScreen,
                                    onWindowTap: { [weak self] in
                                        SharedPreviewWindowCoordinator.shared.hideWindow()
                                        self?.lastAppName = nil
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
                guard let self else { return }
                let mouseScreen = DockObserver.screenContainingPoint(currentMouseLocation) ?? NSScreen.main!
                let convertedMouseLocation = DockObserver.nsPointFromCGPoint(currentMouseLocation, forScreen: mouseScreen)
                if !SharedPreviewWindowCoordinator.shared.frame.contains(convertedMouseLocation) {
                    self.lastAppName = nil
                    SharedPreviewWindowCoordinator.shared.hideWindow()
                }
            }
        }
    }

    func getDockIconFrameAtLocation(_ mouseLocation: CGPoint) -> CGRect? {
        guard let dockAppProcessIdentifier else {
            return nil
        }

        let axDockApp = AXUIElementCreateApplication(dockAppProcessIdentifier)

        var dockItems: CFTypeRef?
        let dockItemsResult = AXUIElementCopyAttributeValue(axDockApp, kAXChildrenAttribute as CFString, &dockItems)

        guard dockItemsResult == .success, let items = dockItems as? [AXUIElement] else {
            return nil
        }

        let axList = items.first { element in
            var role: CFTypeRef?
            let roleResult = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
            return roleResult == .success && (role as? String) == kAXListRole
        }

        guard let list = axList else {
            return nil
        }

        var axChildren: CFTypeRef?
        let childrenResult = AXUIElementCopyAttributeValue(list, kAXChildrenAttribute as CFString, &axChildren)

        guard childrenResult == .success, let children = axChildren as? [AXUIElement] else {
            return nil
        }

        // Adjust mouse location to match the coordinate system of the dock icons
        let adjustedMouseLocation = CGPoint(
            x: mouseLocation.x,
            y: (DockObserver.screenContainingPoint(mouseLocation)?.frame.height ?? NSScreen.main!.frame.height) - mouseLocation.y
        )

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

                if iconRect.contains(adjustedMouseLocation) {
                    return iconRect
                }
            }
        }

        return nil
    }

    func getDockIconAtLocation(_ mouseLocation: CGPoint) -> String? {
        guard let dockAppProcessIdentifier else { return nil }

        let axDockApp = AXUIElementCreateApplication(dockAppProcessIdentifier)

        var dockItems: CFTypeRef?
        let dockItemsResult = AXUIElementCopyAttributeValue(axDockApp, kAXChildrenAttribute as CFString, &dockItems)

        guard dockItemsResult == .success, let items = dockItems as? [AXUIElement] else {
            return nil
        }

        let axList = items.first { element in
            var role: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
            return (role as? String) == kAXListRole
        }

        guard axList != nil else {
            return nil
        }

        var axChildren: CFTypeRef?
        AXUIElementCopyAttributeValue(axList!, kAXChildrenAttribute as CFString, &axChildren)

        guard let children = axChildren as? [AXUIElement] else {
            return nil
        }

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
                if iconRect.contains(mouseLocation) {
                    var value: CFTypeRef?
                    let titleResult = AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &value)
                    if titleResult == .success, let title = value as? String {
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

    func isMouseWithinDock(_ mouseLocation: CGPoint) -> Bool {
        getDockIconAtLocation(mouseLocation) != nil
    }

    static func screenContainingPoint(_ point: CGPoint) -> NSScreen? {
        let screens = NSScreen.screens
        guard let primaryScreen = screens.first else { return nil }

        for screen in screens {
            let (offsetLeft, offsetTop) = computeOffsets(for: screen, primaryScreen: primaryScreen)

            if point.x >= offsetLeft, point.x <= offsetLeft + screen.frame.size.width,
               point.y >= offsetTop, point.y <= offsetTop + screen.frame.size.height
            {
                return screen
            }
        }

        return primaryScreen
    }

    static func nsPointFromCGPoint(_ point: CGPoint, forScreen: NSScreen?) -> NSPoint {
        guard let screen = forScreen,
              let primaryScreen = NSScreen.screens.first
        else {
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
              let primaryScreen = NSScreen.screens.first
        else {
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
