import AppKit
import ApplicationServices
import Cocoa

private var windowCreationWorkItem: DispatchWorkItem?
private let windowCreationDebounceInterval: TimeInterval = 0.5

private let windowProcessingDebounceInterval: TimeInterval = 0.3

class WindowManipulationObservers {
    static let shared = WindowManipulationObservers()
    private var observers: [pid_t: AXObserver] = [:]
    static var debounceWorkItem: DispatchWorkItem?

    private init() {
        setupObservers()
    }

    deinit {
        let notificationCenter = NSWorkspace.shared.notificationCenter
        notificationCenter.removeObserver(self)

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

        notificationCenter.addObserver(self, selector: #selector(activeSpaceDidChange(_:)), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)

        // Set up observers for already running applications
        for app in NSWorkspace.shared.runningApplications {
            if app.activationPolicy == .regular, app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
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
        handleNewWindow(for: app.processIdentifier)
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
    }

    @objc private func activeSpaceDidChange(_ notification: Notification) {
        Task(priority: .high) { [weak self] in
            guard self != nil else { return }
            await WindowUtil.updateAllWindowsInCurrentSpace()
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

    func handleNewWindow(for pid: pid_t) {
        windowCreationWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard self != nil else { return }
            Task {
                if let app = NSRunningApplication(processIdentifier: pid) {
                    await WindowUtil.updateNewWindowsForApp(app)
                }
            }
        }

        windowCreationWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + windowCreationDebounceInterval, execute: workItem)
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
            case kAXUIElementDestroyedNotification, kAXWindowResizedNotification, kAXWindowMovedNotification:
                handleWindowStateChange(element: element, app: app)
            case kAXWindowMiniaturizedNotification:
                WindowUtil.updateStatusOfWindowCache(pid: pid, isParentAppHidden: false)
            case kAXApplicationHiddenNotification:
                WindowUtil.updateStatusOfWindowCache(pid: pid, isParentAppHidden: true)
            case kAXApplicationShownNotification:
                WindowUtil.updateStatusOfWindowCache(pid: pid, isParentAppHidden: false)
            case kAXWindowCreatedNotification:
                WindowManipulationObservers.shared.handleNewWindow(for: pid)
            default:
                break
            }
        }
    }
}

private func handleWindowEvent(element: AXUIElement, app: NSRunningApplication, updateDateTime: Bool = false) {
    WindowManipulationObservers.debounceWorkItem?.cancel()

    let workItem = DispatchWorkItem {
        if updateDateTime {
            WindowUtil.updateWindowDateTime(for: app)
        }
        WindowUtil.updateWindowCache(for: app) { windowSet in
            windowSet = windowSet.filter { WindowUtil.isValidElement($0.axElement) }
        }
    }

    WindowManipulationObservers.debounceWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + windowProcessingDebounceInterval, execute: workItem)
}

private func handleFocusedUIElementChanged(element: AXUIElement, app: NSRunningApplication, pid: pid_t) {
    handleWindowEvent(element: element, app: app, updateDateTime: true)
}

private func handleWindowStateChange(element: AXUIElement, app: NSRunningApplication) {
    handleWindowEvent(element: element, app: app)
}
