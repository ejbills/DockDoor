//
//  WindowManipulationObservers.swift
//  DockDoor
//
//  Created by Ethan Bills on 6/30/24.
//

import Cocoa
import ApplicationServices

class WindowManipulationObservers {
    static let shared = WindowManipulationObservers()
    private var observers: [pid_t: AXObserver] = [:]
    
    private init() {
        setupObservers()
    }
    
    private func setupObservers() {
        let notificationCenter = NSWorkspace.shared.notificationCenter
        notificationCenter.addObserver(self, selector: #selector(appDidLaunch(_:)), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(appDidTerminate(_:)), name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(appDidActivate(_:)), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        
        // Set up observers for already running applications
        NSWorkspace.shared.runningApplications.forEach { app in
            if app.activationPolicy == .regular {
                createObserverForApp(app)
            }
        }
    }
    
    @objc private func appDidLaunch(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.activationPolicy == .regular else {
            return
        }
        createObserverForApp(app)
    }
    
    @objc private func appDidTerminate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        removeObserverForApp(app)
        SharedPreviewWindowCoordinator.shared.hideWindow()
    }
    
    @objc private func appDidActivate(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if SharedPreviewWindowCoordinator.shared.isVisible {
                SharedPreviewWindowCoordinator.shared.hideWindow()
            }
        }
    }
    
    private func createObserverForApp(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        
        var observer: AXObserver?
        let result = AXObserverCreate(pid, axObserverCallback, &observer)
        guard result == .success, let observer = observer else { return }
        
        let appElement = AXUIElementCreateApplication(pid)
        AXObserverAddNotification(observer, appElement, kAXWindowCreatedNotification as CFString, UnsafeMutableRawPointer(bitPattern: Int(pid)))
        AXObserverAddNotification(observer, appElement, kAXUIElementDestroyedNotification as CFString, UnsafeMutableRawPointer(bitPattern: Int(pid)))
        AXObserverAddNotification(observer, appElement, kAXWindowMiniaturizedNotification as CFString, UnsafeMutableRawPointer(bitPattern: Int(pid)))
        AXObserverAddNotification(observer, appElement, kAXWindowDeminiaturizedNotification as CFString, UnsafeMutableRawPointer(bitPattern: Int(pid)))
        
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        
        observers[pid] = observer
    }
    
    private func removeObserverForApp(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        guard let observer = observers[pid] else { return }
        
        let appElement = AXUIElementCreateApplication(pid)
        AXObserverRemoveNotification(observer, appElement, kAXWindowCreatedNotification as CFString)
        AXObserverRemoveNotification(observer, appElement, kAXUIElementDestroyedNotification as CFString)
        AXObserverRemoveNotification(observer, appElement, kAXWindowMiniaturizedNotification as CFString)
        AXObserverRemoveNotification(observer, appElement, kAXWindowDeminiaturizedNotification as CFString)
        
        observers.removeValue(forKey: pid)
    }
    
    deinit {
        observers.forEach { pid, observer in
            let appElement = AXUIElementCreateApplication(pid)
            AXObserverRemoveNotification(observer, appElement, kAXWindowCreatedNotification as CFString)
            AXObserverRemoveNotification(observer, appElement, kAXUIElementDestroyedNotification as CFString)
            AXObserverRemoveNotification(observer, appElement, kAXWindowMiniaturizedNotification as CFString)
            AXObserverRemoveNotification(observer, appElement, kAXWindowDeminiaturizedNotification as CFString)
        }
        observers.removeAll()
    }
}

func axObserverCallback(observer: AXObserver, element: AXUIElement, notificationName: CFString, userData: UnsafeMutableRawPointer?) -> Void {
    guard let userData = userData else { return }
    let pid = Int(bitPattern: userData)
    
    DispatchQueue.main.async {
        if let app = NSRunningApplication(processIdentifier: pid_t(pid)) {
            switch notificationName as String {
            case kAXWindowCreatedNotification:
                print("Window created for app: \(app.localizedName ?? "Unknown")")
            case kAXUIElementDestroyedNotification:
                print("Window closed for app: \(app.localizedName ?? "Unknown")")
            case kAXWindowMiniaturizedNotification:
                print("Window minimized for app: \(app.localizedName ?? "Unknown")")
            case kAXWindowDeminiaturizedNotification:
                print("Window restored for app: \(app.localizedName ?? "Unknown")")
            default:
                break
            }
            
            if var appName = app.localizedName {
                Task {
                    do {
                        _ = try await WindowUtil.activeWindows(for: appName)
                    } catch {
                        print("Error updating active windows: \(error)")
                    }
                }
            }
        }
    }
}
