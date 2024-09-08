import AppKit
import ApplicationServices
import Cocoa

class WindowManipulationObservers {
    static let shared = WindowManipulationObservers()
    private var observers: [pid_t: AXObserver] = [:]
    static var trackedElements: Set<AXUIElement> = []
    static var debounceWorkItem: DispatchWorkItem?
    static var lastWindowCreationTime: [String: Date] = [:]
    static let windowCreationDebounceInterval: TimeInterval = 1.0 // 1 second debounce

    private init() {
        setupObservers()
    }

    deinit {
        for (pid, observer) in observers {
            let appElement = AXUIElementCreateApplication(pid)
            AXObserverRemoveNotification(observer, appElement, kAXWindowCreatedNotification as CFString)
            AXObserverRemoveNotification(observer, appElement, kAXUIElementDestroyedNotification as CFString)
            AXObserverRemoveNotification(observer, appElement, kAXMainWindowChangedNotification as CFString)
            AXObserverRemoveNotification(observer, appElement, kAXWindowMiniaturizedNotification as CFString)
            AXObserverRemoveNotification(observer, appElement, kAXApplicationHiddenNotification as CFString)
            AXObserverRemoveNotification(observer, appElement, kAXApplicationShownNotification as CFString)
            AXObserverRemoveNotification(observer, appElement, kAXFocusedUIElementChangedNotification as CFString)
            AXObserverRemoveNotification(observer, appElement, kAXFocusedWindowChangedNotification as CFString)
            AXObserverRemoveNotification(observer, appElement, kAXWindowResizedNotification as CFString)
            AXObserverRemoveNotification(observer, appElement, kAXWindowMovedNotification as CFString)
        }
        observers.removeAll()
    }

    private func setupObservers() {
        let notificationCenter = NSWorkspace.shared.notificationCenter
        notificationCenter.addObserver(self, selector: #selector(appDidLaunch(_:)), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(appDidTerminate(_:)), name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(appDidActivate(_:)), name: NSWorkspace.didActivateApplicationNotification, object: nil)

        // Set up observers for already running applications
        for app in NSWorkspace.shared.runningApplications {
            if app.activationPolicy == .regular {
                createObserverForApp(app)
            }
        }
    }

    @objc private func appDidLaunch(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.activationPolicy == .regular
        else {
            return
        }
        createObserverForApp(app)
    }

    @objc private func appDidTerminate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        WindowUtil.clearWindowCache(for: app)
        removeObserverForApp(app)
        SharedPreviewWindowCoordinator.shared.hideWindow()
    }

    @objc private func appDidActivate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }

        WindowUtil.updateWindowDateTime(for: app)

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
        guard result == .success, let observer else { return }

        let appElement = AXUIElementCreateApplication(pid)

        AXObserverAddNotification(observer, appElement, kAXWindowCreatedNotification as CFString, UnsafeMutableRawPointer(bitPattern: Int(pid)))
        AXObserverAddNotification(observer, appElement, kAXUIElementDestroyedNotification as CFString, UnsafeMutableRawPointer(bitPattern: Int(pid)))
        AXObserverAddNotification(observer, appElement, kAXWindowMiniaturizedNotification as CFString, UnsafeMutableRawPointer(bitPattern: Int(pid)))
        AXObserverAddNotification(observer, appElement, kAXApplicationHiddenNotification as CFString, UnsafeMutableRawPointer(bitPattern: Int(pid)))
        AXObserverAddNotification(observer, appElement, kAXApplicationShownNotification as CFString, UnsafeMutableRawPointer(bitPattern: Int(pid)))
        AXObserverAddNotification(observer, appElement, kAXWindowResizedNotification as CFString, UnsafeMutableRawPointer(bitPattern: Int(pid)))
        AXObserverAddNotification(observer, appElement, kAXWindowMovedNotification as CFString, UnsafeMutableRawPointer(bitPattern: Int(pid)))
        AXObserverAddNotification(observer, appElement, kAXFocusedUIElementChangedNotification as CFString, UnsafeMutableRawPointer(bitPattern: Int(pid)))
        AXObserverAddNotification(observer, appElement, kAXFocusedWindowChangedNotification as CFString, UnsafeMutableRawPointer(bitPattern: Int(pid)))

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
        AXObserverRemoveNotification(observer, appElement, kAXApplicationHiddenNotification as CFString)
        AXObserverRemoveNotification(observer, appElement, kAXApplicationShownNotification as CFString)
        AXObserverRemoveNotification(observer, appElement, kAXFocusedUIElementChangedNotification as CFString)
        AXObserverRemoveNotification(observer, appElement, kAXFocusedWindowChangedNotification as CFString)
        AXObserverRemoveNotification(observer, appElement, kAXWindowResizedNotification as CFString)
        AXObserverRemoveNotification(observer, appElement, kAXWindowMovedNotification as CFString)

        observers.removeValue(forKey: pid)
    }
}

func axObserverCallback(observer: AXObserver, element: AXUIElement, notificationName: CFString, userData: UnsafeMutableRawPointer?) {
    guard let userData else { return }
    let pid = pid_t(Int(bitPattern: userData))

    DispatchQueue.main.async {
        if let app = NSRunningApplication(processIdentifier: pid) {
            switch notificationName as String {
            case kAXFocusedUIElementChangedNotification, kAXFocusedWindowChangedNotification:
                handleFocusedUIElementChanged(element: element, app: app, pid: pid)
            case kAXUIElementDestroyedNotification:
                handleWindowStateChange(element: element, app: app)
            case kAXWindowMiniaturizedNotification:
                WindowUtil.updateStatusOfWindowCache(pid: pid_t(pid), isParentAppHidden: false)
            case kAXApplicationHiddenNotification:
                WindowUtil.updateStatusOfWindowCache(pid: pid_t(pid), isParentAppHidden: true)
            case kAXApplicationShownNotification:
                WindowUtil.updateStatusOfWindowCache(pid: pid_t(pid), isParentAppHidden: false)
            case kAXWindowResizedNotification, kAXWindowMovedNotification:
                handleWindowStateChange(element: element, app: app)
            default:
                break
            }
        }
    }
}

private func handleFocusedUIElementChanged(element: AXUIElement, app: NSRunningApplication, pid: pid_t) {
    guard !WindowManipulationObservers.trackedElements.contains(element) else { return }
    WindowManipulationObservers.trackedElements.insert(element)
    WindowManipulationObservers.debounceWorkItem?.cancel()
    WindowManipulationObservers.debounceWorkItem = DispatchWorkItem {
        WindowUtil.updateWindowDateTime(for: app)
        WindowManipulationObservers.trackedElements.remove(element)
        print("Focused Window has changed: \(app.localizedName ?? "")")
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: WindowManipulationObservers.debounceWorkItem!)
}

private func handleWindowStateChange(element: AXUIElement, app: NSRunningApplication) {
    guard !WindowManipulationObservers.trackedElements.contains(element) else { return }
    WindowManipulationObservers.trackedElements.insert(element)
    WindowManipulationObservers.debounceWorkItem?.cancel()
    WindowManipulationObservers.debounceWorkItem = DispatchWorkItem {
        WindowUtil.updateWindowCache(for: app) { windowSet in
            windowSet = windowSet.filter { WindowUtil.isValidElement($0.axElement) }
        }
        WindowManipulationObservers.trackedElements.remove(element)
        print("Window destroyed for app: \(app.localizedName ?? "Unknown")")
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01, execute: WindowManipulationObservers.debounceWorkItem!)
}
