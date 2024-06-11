//  DockObserver.swift
//  DockDoor
//
//  Created by Ethan Bills on 6/3/24.
//

import Cocoa
import ApplicationServices

class DockObserver {
    private var dockIcons: [AXUIElement] = []
    private var iconFrames: [AXUIElement: CGRect] = [:]
    private var iconNames: [AXUIElement: String] = [:]
    private var hoverWindow: HoverWindow?
    private var lastAppName: String?
    private var lastMouseLocation: CGPoint = .zero
    private let mouseMoveThreshold: CGFloat = 1.0
    private var timer: Timer?
    private var eventTap: CFMachPort?
    private var activeAppMonitor: Any?
    private var refreshInterval: TimeInterval = 3
    
    init() {
        setupEventTap()
        monitorActiveApp()
        setupDockRefreshTimer()
        refreshDockIcons()
    }
    
    private func setupEventTap() {
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
            eventsOfInterest: CGEventMask((1 << CGEventType.mouseMoved.rawValue)),
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
    
    private func monitorActiveApp() {
        activeAppMonitor = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            if NSRunningApplication.current.bundleIdentifier == Bundle.main.bundleIdentifier {
                self?.handleAppActivated()
            }
        }
    }
    
    private func handleAppActivated() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }
    }
    
    @objc private func handleMouseEvent(mouseLocation: CGPoint) {
        let magnificationEnabled = DockUtils.shared.isMagnificationEnabled()
        var hoveredOverIcon = false

        for (appElement, frame) in iconFrames {
            let adjustedFrame = adjustFrame(frame, magnificationEnabled: magnificationEnabled)
            
            if adjustedFrame.contains(mouseLocation) {
                if let appName = iconNames[appElement], appName != lastAppName {
                    lastAppName = appName
                    hoveredOverIcon = true
                    
                    Task {
                        let activeWindows = await WindowUtil.activeWindows(for: appName)
                        DispatchQueue.main.async {
                            self.showHoverWindow(for: appName, windows: activeWindows, mouseLocation: mouseLocation)
                        }
                    }
                } else if let appName = iconNames[appElement], appName == lastAppName {
                    hoveredOverIcon = true
                }
                
                break
            }
        }
        
        if !hoveredOverIcon, let hoverWindow = hoverWindow, !hoverWindow.frame.contains(mouseLocation) {
            lastAppName = nil
            hideHoverWindow()
        }
    }
    
    private func adjustFrame(_ frame: CGRect, magnificationEnabled: Bool) -> CGRect {
        var adjustedFrame = frame
        let expansionFactor: CGFloat = magnificationEnabled ? 1.5 : 1.0 // Adjust this factor as needed
        adjustedFrame = adjustedFrame.insetBy(dx: -frame.width * (expansionFactor - 1.0) / 2, dy: -frame.height * (expansionFactor - 1.0) / 2)
        return adjustedFrame
    }

    private func showHoverWindow(for appName: String, windows: [WindowInfo], mouseLocation: CGPoint) {
        if hoverWindow == nil || hoverWindow?.appName != appName {
            hideHoverWindow()
            hoverWindow = HoverWindow(appName: appName, windows: windows, onWindowTap: { self.hideHoverWindow() })
            
            guard let hoverWindow = hoverWindow else { return }
            guard let screen = NSScreen.main else { return }
            
            let screenFrame = screen.frame
            let hoverWindowSize = hoverWindow.frame.size
            hoverWindow.level = .floating
            
            let dockPosition = DockUtils.shared.getDockPosition()
            var newOrigin: CGPoint = mouseLocation
            let dockHeight = DockUtils.shared.calculateDockHeight()
            
            switch dockPosition {
            case .bottom:
                newOrigin.x = mouseLocation.x - hoverWindowSize.width / 2
                newOrigin.y = dockHeight * 2
                hoverWindow.setFrameOrigin(newOrigin)
            case .left:
                newOrigin.x = dockHeight / 2
                newOrigin.y = mouseLocation.y - hoverWindowSize.height / 2
                hoverWindow.setFrameOrigin(newOrigin)
            case .right:
                newOrigin.x = screenFrame.maxX - roughWidthCap - (dockHeight / 1.5)
                newOrigin.y = mouseLocation.y - hoverWindowSize.height / 2
                hoverWindow.setFrameOrigin(newOrigin)
            case .unknown:
                newOrigin = mouseLocation
                hoverWindow.setFrameOrigin(newOrigin)
            }
            
            hoverWindow.setFrameOrigin(newOrigin)
            hoverWindow.makeKeyAndOrderFront(nil)
        }
    }
    
    private func hideHoverWindow() {
        hoverWindow?.orderOut(nil)
        hoverWindow = nil
    }

    private func setupDockRefreshTimer() {
        self.timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true, block: { _ in
            self.refreshDockIcons()
        })
    }
    
    @objc private func applicationDidChange(_ notification: Notification) {
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
        
        let dockAXUIElement = AXUIElementCreateApplication(dockApp.processIdentifier)
        let dockPosition = DockUtils.shared.getDockPosition()
        
        var children: CFArray?
        if AXUIElementCopyAttributeValues(dockAXUIElement, kAXChildrenAttribute as CFString, 0, 999, &children) == .success,
           let dockElements = children as? [AXUIElement] {
            
            Task {
                await withTaskGroup(of: Void.self) { group in
                    for element in dockElements {
                        group.addTask {
                            await self.processDockElement(element, dockPosition: dockPosition)
                        }
                    }
                }
            }
            
            print("processed dock icons")
        } else {
            print("Failed to get dock icons")
        }
    }
    
    private func processDockElement(_ element: AXUIElement, dockPosition: DockPosition) async {
        var children: CFArray?
        if AXUIElementCopyAttributeValues(element, kAXChildrenAttribute as CFString, 0, 999, &children) == .success,
           let childElements = children as? [AXUIElement] {
            await withTaskGroup(of: Void.self) { group in
                for child in childElements {
                    group.addTask {
                        await self.processChildElement(child, dockPosition: dockPosition)
                    }
                }
            }
        }
    }
    
    private func processChildElement(_ child: AXUIElement, dockPosition: DockPosition) async {
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
            
            if isRunningSuccess == .success, isRunning {
                await self.processDockIcon(child, dockPosition: dockPosition)
            }
        }
    }
    
    private func processDockIcon(_ element: AXUIElement, dockPosition: DockPosition) async {
        if let frame = getFrame(of: element) {
            let adjustedFrame = adjustFrame(frame, dockPosition: dockPosition)
            DispatchQueue.main.async {
                self.dockIcons.append(element)
                self.iconFrames[element] = adjustedFrame
                if let name = self.getAppName(of: element) {
                    self.iconNames[element] = name
                }
            }
        }
    }
    
    private func adjustFrame(_ frame: CGRect, dockPosition: DockPosition) -> CGRect {
        var adjustedFrame = frame
        
        if dockPosition == .bottom {
            if let mainScreen = NSScreen.screens.first {
                adjustedFrame.origin.y = mainScreen.frame.height - frame.maxY
            }
        } else if dockPosition == .left || dockPosition == .right {
            if let mainScreen = NSScreen.main {
                adjustedFrame.origin.y = mainScreen.frame.height - frame.origin.y - frame.height
            }
        }
        
        return adjustedFrame
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
                
                if pos.x < 0 || pos.y < 0 {
                    pos.x = max(pos.x, 0)
                    pos.y = max(pos.y, 0)
                }
                
                return CGRect(origin: pos, size: sizeValue)
            }
        }
        return nil
    }
    
    private func getAppName(of element: AXUIElement) -> String? {
        var appName: CFTypeRef?
        
        if AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &appName) == .success,
           let name = appName as? String {
            return name
        }
        return nil
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        timer?.invalidate()
    }
}
