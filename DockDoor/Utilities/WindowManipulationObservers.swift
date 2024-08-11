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

    private func setupObservers() {
        let notificationCenter = NSWorkspace.shared.notificationCenter
        notificationCenter.addObserver(self, selector: #selector(appDidLaunch(_:)), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(appDidTerminate(_:)), name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(appDidActivate(_:)), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(appDidHide(_:)), name: NSApplication.didHideNotification, object: nil)

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
        WindowUtil.clearWindowCache(for: app.bundleIdentifier ?? "")
        removeObserverForApp(app)
        SharedPreviewWindowCoordinator.shared.hideWindow()
    }

    @objc private func appDidActivate(_: Notification) {
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
        WindowUtil.addAppToBundleIDTracker(applicationName: app.localizedName ?? "", bundleID: app.bundleIdentifier ?? "")

        let appElement = AXUIElementCreateApplication(pid)
        AXObserverAddNotification(observer, appElement, kAXWindowCreatedNotification as CFString, UnsafeMutableRawPointer(bitPattern: Int(pid)))
        AXObserverAddNotification(observer, appElement, kAXUIElementDestroyedNotification as CFString, UnsafeMutableRawPointer(bitPattern: Int(pid)))
        AXObserverAddNotification(observer, appElement, kAXWindowMiniaturizedNotification as CFString, UnsafeMutableRawPointer(bitPattern: Int(pid)))
        AXObserverAddNotification(observer, appElement, kAXWindowDeminiaturizedNotification as CFString, UnsafeMutableRawPointer(bitPattern: Int(pid)))
        AXObserverAddNotification(observer, appElement, kAXApplicationHiddenNotification as CFString, UnsafeMutableRawPointer(bitPattern: Int(pid)))
        AXObserverAddNotification(observer, appElement, kAXApplicationShownNotification as CFString, UnsafeMutableRawPointer(bitPattern: Int(pid)))
        AXObserverAddNotification(observer, appElement, kAXFocusedUIElementChangedNotification as CFString, UnsafeMutableRawPointer(bitPattern: Int(pid)))

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
        AXObserverRemoveNotification(observer, appElement, kAXFocusedUIElementChangedNotification as CFString)

        observers.removeValue(forKey: pid)
    }

    deinit {
        for (pid, observer) in observers {
            let appElement = AXUIElementCreateApplication(pid)
            AXObserverRemoveNotification(observer, appElement, kAXWindowCreatedNotification as CFString)
            AXObserverRemoveNotification(observer, appElement, kAXUIElementDestroyedNotification as CFString)
            AXObserverRemoveNotification(observer, appElement, kAXWindowMiniaturizedNotification as CFString)
            AXObserverRemoveNotification(observer, appElement, kAXWindowDeminiaturizedNotification as CFString)
            AXObserverRemoveNotification(observer, appElement, kAXFocusedUIElementChangedNotification as CFString)
        }
        observers.removeAll()
    }
}

func axObserverCallback(observer _: AXObserver, element: AXUIElement, notificationName: CFString, userData: UnsafeMutableRawPointer?) {
    guard let userData else { return }
    let pid = pid_t(Int(bitPattern: userData))

    DispatchQueue.main.async {
        if let app = NSRunningApplication(processIdentifier: pid) {
            switch notificationName as String {
            case kAXFocusedUIElementChangedNotification:
                guard !WindowManipulationObservers.trackedElements.contains(element) else { return }
                WindowManipulationObservers.trackedElements.insert(element)
                WindowManipulationObservers.debounceWorkItem?.cancel()
                WindowManipulationObservers.debounceWorkItem = DispatchWorkItem {
                    WindowUtil.updateWindowDateTime(with: app.bundleIdentifier ?? "", pid: pid)
                    WindowManipulationObservers.trackedElements.remove(element)
                    print("Focused Window has changed: \(app.localizedName ?? "")")
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: WindowManipulationObservers.debounceWorkItem!)
            case kAXUIElementDestroyedNotification:
                guard !WindowManipulationObservers.trackedElements.contains(element) else { return }
                WindowManipulationObservers.trackedElements.insert(element)
                WindowManipulationObservers.debounceWorkItem?.cancel()
                WindowManipulationObservers.debounceWorkItem = DispatchWorkItem {
                    WindowUtil.updateWindowCache(for: app.bundleIdentifier ?? "") { windowSet in
                        windowSet = windowSet.filter { WindowUtil.isValidElement($0.axElement) }
                    }
                    WindowManipulationObservers.trackedElements.remove(element)
                    print("Window destroyed for app: \(app.localizedName ?? "Unknown")")
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01, execute: WindowManipulationObservers.debounceWorkItem!)
            case kAXWindowMiniaturizedNotification:
                print("Window minimized for app: \(app.localizedName ?? "Unknown")")
                WindowUtil.updateStatusOfWindowCache(pid: pid_t(pid), bundleID: app.bundleIdentifier ?? "", isParentAppHidden: false)
            case kAXWindowDeminiaturizedNotification:
                print("Window restored for app: \(app.localizedName ?? "Unknown")")
            case kAXApplicationHiddenNotification:
                print("Application hidden: \(app.localizedName ?? "Unknown")")
                WindowUtil.updateStatusOfWindowCache(pid: pid_t(pid), bundleID: app.bundleIdentifier ?? "", isParentAppHidden: true)
            case kAXApplicationShownNotification:
                print("Application shown: \(app.localizedName ?? "Unknown")")
            default:
                break
            }
        }
    }
}
