//
//  WindowManipulationObservers.swift
//  DockDoor
//
//  Created by Ethan Bills on 6/30/24.
//

import Cocoa
import ApplicationServices
import AppKit

class WindowManipulationObservers {
    static let shared = WindowManipulationObservers()
    private var observers: [pid_t: AXObserver] = [:]
    static var trackedElements: Set<AXUIElement> = []
    static var debounceWorkItem: DispatchWorkItem?
    
    private init() {
        setupObservers()
    }
    
    private func setupObservers() {
        let notificationCenter = NSWorkspace.shared.notificationCenter
        notificationCenter.addObserver(self, selector: #selector(appDidLaunch(_:)), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(appDidTerminate(_:)), name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(appDidActivate(_:)), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(appDidHide(_:)), name: NSApplication.didHideNotification, object: nil)
        
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
        Task.detached {
            _ = try await WindowUtil.activeWindows(for: "")
        }
        createObserverForApp(app)
        
    }
    
    @objc private func appDidTerminate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        WindowUtil.removeWindowFromDesktopSpaceCache(with: app.bundleIdentifier ?? "", removeAll: true)
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
        WindowUtil.addToBundleIDTracker(applicationName:app.localizedName ?? "", bundleID: app.bundleIdentifier ?? "")
        
        let appElement = AXUIElementCreateApplication(pid)
        AXObserverAddNotification(observer, appElement, kAXWindowCreatedNotification as CFString, UnsafeMutableRawPointer(bitPattern: Int(pid)))
        AXObserverAddNotification(observer, appElement, kAXUIElementDestroyedNotification as CFString, UnsafeMutableRawPointer(bitPattern: Int(pid)))
        AXObserverAddNotification(observer, appElement, kAXWindowMiniaturizedNotification as CFString, UnsafeMutableRawPointer(bitPattern: Int(pid)))
        AXObserverAddNotification(observer, appElement, kAXWindowDeminiaturizedNotification as CFString, UnsafeMutableRawPointer(bitPattern: Int(pid)))
        AXObserverAddNotification(observer, appElement, kAXApplicationHiddenNotification as CFString, UnsafeMutableRawPointer(bitPattern: Int(pid)))
        AXObserverAddNotification(observer, appElement, kAXApplicationShownNotification as CFString, UnsafeMutableRawPointer(bitPattern: Int(pid)))
        
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        
        observers[pid] = observer
    }
    
    @objc private func appDidHide(_ notification: Notification) {
        guard let app = notification.object as? NSRunningApplication else { return }
        let pid = app.processIdentifier
        let bundleID = app.bundleIdentifier ?? ""
        
        WindowUtil.updateStatusOfWindowCache(pid: pid, bundleID: bundleID, isParentAppHidden: true)
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
    let pid = pid_t(Int(bitPattern: userData))
    
    DispatchQueue.main.async {
        if let app = NSRunningApplication(processIdentifier: pid){
            switch notificationName as String {
            case kAXWindowCreatedNotification:
                print("Window created for app: \(app.localizedName ?? "Unknown")")
                Task {
                    if let appName = app.localizedName {
                        await WindowUtil.retryWindowCreation(for: appName, maxRetries: 5, delay: 0.2)
                    }
                }
                break
            case kAXUIElementDestroyedNotification:
                guard !WindowManipulationObservers.trackedElements.contains(element) else { return }
                WindowManipulationObservers.trackedElements.insert(element)
                WindowManipulationObservers.debounceWorkItem?.cancel()
                WindowManipulationObservers.debounceWorkItem = DispatchWorkItem {
                    WindowUtil.removeWindowFromDesktopSpaceCache(with: app.bundleIdentifier ?? "" , removeAll: false)
                    WindowManipulationObservers.trackedElements.remove(element)
                    print("Window minimized for app: \(app.localizedName ?? "Unknown")")

                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01, execute: WindowManipulationObservers.debounceWorkItem!)
                break
            case kAXWindowMiniaturizedNotification:
                print("Window minimized for app: \(app.localizedName ?? "Unknown")")
                WindowUtil.updateStatusOfWindowCache(pid: pid_t(pid), bundleID: app.bundleIdentifier ?? "", isParentAppHidden: false)
                break
            case kAXWindowDeminiaturizedNotification:
                print("Window restored for app: \(app.localizedName ?? "Unknown")")
            case kAXApplicationHiddenNotification:
                print("Application hidden: \(app.localizedName ?? "Unknown")")
                WindowUtil.updateStatusOfWindowCache(pid: pid_t(pid), bundleID: app.bundleIdentifier ?? "", isParentAppHidden: true)
                break
            case kAXApplicationShownNotification:
                print("Application shown: \(app.localizedName ?? "Unknown")")
                break
            default:
                break
            }
            
        }
    }
}

func printTitle(of element: AXUIElement) {
    var title: AnyObject?
    let result = AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title)
    
    if result == .success, let titleString = title as? String {
        print("Title: \(titleString)")
    } else {
        print("Unable to retrieve title")
    }
}

enum AxError: Error {
    case runtimeError
}

func axCallWhichCanThrow<T>(_ result: AXError, _ successValue: inout T) throws -> T? {
    switch result {
    case .success:
        print(successValue)
        return successValue
    case .cannotComplete:
        print("error")
        throw AxError.runtimeError
    default:
        return nil
    }
}

func cgWindowId(appElement: AXUIElement) throws -> CGWindowID? {
    var id : CGWindowID = 0
    let result = _AXUIElementGetWindow(appElement, &id)
    return try axCallWhichCanThrow(result, &id)
}


