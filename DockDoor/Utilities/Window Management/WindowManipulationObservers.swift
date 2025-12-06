import AppKit
import ApplicationServices
import Cocoa
import Defaults
import Foundation

private var windowCreationWorkItem: DispatchWorkItem?
private let windowCreationDebounceInterval: TimeInterval = 1

private let windowProcessingDebounceInterval: TimeInterval = Defaults[.windowProcessingDebounceInterval]

private weak var activeWindowManipulationObserversInstance: WindowManipulationObservers?

class WindowManipulationObservers {
    private let previewCoordinator: SharedPreviewWindowCoordinator

    private var observers: [pid_t: AXObserver] = [:]
    var cacheUpdateWorkItem: (workItem: DispatchWorkItem, hasStateAdjustment: Bool)?
    var updateDateTimeWorkItem: DispatchWorkItem?

    init(previewCoordinator: SharedPreviewWindowCoordinator) {
        self.previewCoordinator = previewCoordinator
        activeWindowManipulationObserversInstance = self
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
            AXObserverRemoveNotification(observer, appElement, kAXWindowDeminiaturizedNotification as CFString)
            AXObserverRemoveNotification(observer, appElement, kAXApplicationHiddenNotification as CFString)
            AXObserverRemoveNotification(observer, appElement, kAXApplicationShownNotification as CFString)
            AXObserverRemoveNotification(observer, appElement, kAXFocusedUIElementChangedNotification as CFString)
            AXObserverRemoveNotification(observer, appElement, kAXFocusedWindowChangedNotification as CFString)
            AXObserverRemoveNotification(observer, appElement, kAXWindowResizedNotification as CFString)
            AXObserverRemoveNotification(observer, appElement, kAXWindowMovedNotification as CFString)
        }
        observers.removeAll()
        if activeWindowManipulationObserversInstance === self {
            activeWindowManipulationObserversInstance = nil
        }
    }

    private func setupObservers() {
        DebugLogger.measure("setupObservers") {
            let notificationCenter = NSWorkspace.shared.notificationCenter
            notificationCenter.addObserver(self, selector: #selector(appDidLaunch(_:)), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
            notificationCenter.addObserver(self, selector: #selector(appDidTerminate(_:)), name: NSWorkspace.didTerminateApplicationNotification, object: nil)

            notificationCenter.addObserver(self, selector: #selector(activeSpaceDidChange(_:)), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
            notificationCenter.addObserver(self, selector: #selector(appDidActivate(_:)), name: NSWorkspace.didActivateApplicationNotification, object: nil)

            let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
            DebugLogger.log("setupObservers", details: "Setting up observers for \(apps.count) running apps")

            for app in apps {
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
        DebugLogger.log("appDidLaunch", details: "App: \(app.localizedName ?? "Unknown") (PID: \(app.processIdentifier))")
        createObserverForApp(app)
        handleNewWindow(for: app.processIdentifier)

        // Notify active app indicator of dock shift
        ActiveAppIndicatorCoordinator.shared?.notifyDockItemsChanged()
    }

    @MainActor
    @objc private func appDidTerminate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        DebugLogger.log("appDidTerminate", details: "App: \(app.localizedName ?? "Unknown") (PID: \(app.processIdentifier))")
        WindowUtil.purgeAppCache(with: app.processIdentifier)
        removeObserver(for: app.processIdentifier)

        if !Defaults[.keepPreviewOnAppTerminate] {
            previewCoordinator.hideWindow()
        }

        // Notify active app indicator of dock shift
        ActiveAppIndicatorCoordinator.shared?.notifyDockItemsChanged()
    }

    @objc private func activeSpaceDidChange(_ notification: Notification) {
        DebugLogger.log("activeSpaceDidChange")
        Task(priority: .high) { [weak self] in
            guard self != nil else { return }
            await DebugLogger.measureAsync("updateAllWindowsInCurrentSpace") {
                await WindowUtil.updateAllWindowsInCurrentSpace()
            }
        }
    }

    @objc private func appDidActivate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        else {
            return
        }

        previewCoordinator.hideWindow()

        if let dockObserver = DockObserver.activeInstance,
           let currentClickedPID = dockObserver.currentClickedAppPID,
           currentClickedPID != app.processIdentifier
        {
            dockObserver.currentClickedAppPID = nil
        }

        // Get the focused window when app becomes active (this is the window user clicked on)
        let appAX = AXUIElementCreateApplication(app.processIdentifier)
        doAfter(0.3) { // wait for space switching animation to complete
            if let focusedWindow = try? appAX.focusedWindow() {
                WindowUtil.updateWindowDateTime(element: focusedWindow, app: app)
            }
        }
    }

    private func createObserverForApp(_ app: NSRunningApplication) {
        let pid = app.processIdentifier

        DebugLogger.measure("createObserverForApp", details: "App: \(app.localizedName ?? "Unknown") (PID: \(pid))") {
            var observer: AXObserver?
            let result = AXObserverCreate(pid, axObserverCallback, &observer)
            guard result == .success, let observer else { return }

            let appElement = AXUIElementCreateApplication(pid)

            AXObserverAddNotification(observer, appElement, kAXWindowCreatedNotification as CFString, UnsafeMutableRawPointer(bitPattern: Int(pid)))
            AXObserverAddNotification(observer, appElement, kAXUIElementDestroyedNotification as CFString, UnsafeMutableRawPointer(bitPattern: Int(pid)))
            AXObserverAddNotification(observer, appElement, kAXWindowMiniaturizedNotification as CFString, UnsafeMutableRawPointer(bitPattern: Int(pid)))
            AXObserverAddNotification(observer, appElement, kAXWindowDeminiaturizedNotification as CFString, UnsafeMutableRawPointer(bitPattern: Int(pid)))
            AXObserverAddNotification(observer, appElement, kAXApplicationHiddenNotification as CFString, UnsafeMutableRawPointer(bitPattern: Int(pid)))
            AXObserverAddNotification(observer, appElement, kAXApplicationShownNotification as CFString, UnsafeMutableRawPointer(bitPattern: Int(pid)))
            AXObserverAddNotification(observer, appElement, kAXWindowResizedNotification as CFString, UnsafeMutableRawPointer(bitPattern: Int(pid)))
            AXObserverAddNotification(observer, appElement, kAXWindowMovedNotification as CFString, UnsafeMutableRawPointer(bitPattern: Int(pid)))
            AXObserverAddNotification(observer, appElement, kAXMainWindowChangedNotification as CFString, UnsafeMutableRawPointer(bitPattern: Int(pid)))
            AXObserverAddNotification(observer, appElement, kAXFocusedUIElementChangedNotification as CFString, UnsafeMutableRawPointer(bitPattern: Int(pid)))
            AXObserverAddNotification(observer, appElement, kAXFocusedWindowChangedNotification as CFString, UnsafeMutableRawPointer(bitPattern: Int(pid)))

            CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)

            observers[pid] = observer
        }
    }

    private func removeObserverForApp(_ app: NSRunningApplication) {
        removeObserver(for: app.processIdentifier)
    }

    func removeObserver(for pid: pid_t) {
        guard let observer = observers[pid] else { return }

        let appElement = AXUIElementCreateApplication(pid)

        AXObserverRemoveNotification(observer, appElement, kAXWindowCreatedNotification as CFString)
        AXObserverRemoveNotification(observer, appElement, kAXUIElementDestroyedNotification as CFString)
        AXObserverRemoveNotification(observer, appElement, kAXWindowMiniaturizedNotification as CFString)
        AXObserverRemoveNotification(observer, appElement, kAXWindowDeminiaturizedNotification as CFString)
        AXObserverRemoveNotification(observer, appElement, kAXApplicationHiddenNotification as CFString)
        AXObserverRemoveNotification(observer, appElement, kAXApplicationShownNotification as CFString)
        AXObserverRemoveNotification(observer, appElement, kAXMainWindowChangedNotification as CFString)
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
                    DebugLogger.log("handleNewWindow", details: "App: \(app.localizedName ?? "Unknown") (PID: \(pid))")
                    await DebugLogger.measureAsync("updateNewWindowsForApp", details: "PID: \(pid)") {
                        await WindowUtil.updateNewWindowsForApp(app)
                    }
                }
            }
        }

        windowCreationWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + windowCreationDebounceInterval, execute: workItem)
    }

    func processAXNotification(element: AXUIElement, notificationName: String, app: NSRunningApplication, pid: pid_t) {
        DebugLogger.log("processAXNotification", details: "Notification: \(notificationName), App: \(app.localizedName ?? "Unknown") (PID: \(pid))")

        switch notificationName {
        case kAXFocusedUIElementChangedNotification, kAXFocusedWindowChangedNotification, kAXMainWindowChangedNotification:
            updateTimestampIfAppActive(element: element, app: app)
            handleWindowEvent(element: element, app: app, notification: notificationName, validate: false)
        case kAXUIElementDestroyedNotification:
            handleWindowEvent(element: element, app: app, notification: notificationName, validate: true)
            // Notify active app indicator of potential dock shift (when window is closed)
            ActiveAppIndicatorCoordinator.shared?.notifyDockItemsChanged()
        case kAXWindowResizedNotification, kAXWindowMovedNotification:
            handleWindowEvent(element: element, app: app, notification: notificationName, validate: false)
        case kAXWindowMiniaturizedNotification, kAXWindowDeminiaturizedNotification:
            let windowID = try? element.cgWindowId()
            let minimizedState = try? element.isMinimized()
            handleWindowEvent(element: element, app: app, notification: notificationName, validate: true) { [weak self] windowSet in
                guard let self else { return }
                update(windowSet: &windowSet, matching: windowID, element: element) { window in
                    window.isMinimized = minimizedState ?? false
                }
            }
            ActiveAppIndicatorCoordinator.shared?.notifyDockItemsChanged()
        case kAXApplicationHiddenNotification:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self else { return }
                if NSRunningApplication(processIdentifier: pid) == nil {
                    WindowUtil.purgeAppCache(with: pid)
                    removeObserver(for: pid)
                } else {
                    handleWindowEvent(element: element, app: app, notification: notificationName, validate: true) { windowSet in
                        windowSet = Set(windowSet.map { window in
                            var updated = window
                            updated.isHidden = true
                            return updated
                        })
                    }
                }
            }
        case kAXApplicationShownNotification:
            handleWindowEvent(element: element, app: app, notification: notificationName, validate: true) { windowSet in
                windowSet = Set(windowSet.map { window in
                    var updated = window
                    updated.isHidden = false
                    return updated
                })
            }
        case kAXWindowCreatedNotification:
            handleNewWindow(for: pid)
        default:
            break
        }
    }

    private func updateTimestampIfAppActive(element: AXUIElement, app: NSRunningApplication) {
        updateDateTimeWorkItem?.cancel()

        let workItem = DispatchWorkItem {
            if app.isActive {
                let appAX = AXUIElementCreateApplication(app.processIdentifier)
                if let focusedWindow = try? appAX.focusedWindow() {
                    WindowUtil.updateWindowDateTime(element: focusedWindow, app: app)
                }
            }
        }
        updateDateTimeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + windowProcessingDebounceInterval, execute: workItem)
    }

    private func handleWindowEvent(element: AXUIElement,
                                   app: NSRunningApplication,
                                   notification: String,
                                   validate: Bool = false,
                                   stateAdjustment: ((inout Set<WindowInfo>) -> Void)? = nil)
    {
        // Don't cancel if the pending work item has a state adjustment (prioritize state writes)
        if cacheUpdateWorkItem?.hasStateAdjustment != true {
            cacheUpdateWorkItem?.workItem.cancel()
        }

        let hasStateAdjustment = stateAdjustment != nil
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            DebugLogger.measure("updateWindowCache", details: "App: \(app.localizedName ?? "Unknown"), Notification: \(notification), Validate: \(validate)") {
                WindowUtil.updateWindowCache(for: app) { windowSet in
                    if validate {
                        windowSet = windowSet.filter { WindowUtil.isValidElement($0.axElement) }
                    }
                    stateAdjustment?(&windowSet)
                }
            }
            // Clear when work item completes
            cacheUpdateWorkItem = nil
        }
        cacheUpdateWorkItem = (workItem, hasStateAdjustment)
        DispatchQueue.main.asyncAfter(deadline: .now() + windowProcessingDebounceInterval, execute: workItem)
    }

    private func update(windowSet: inout Set<WindowInfo>,
                        matching windowID: CGWindowID?,
                        element: AXUIElement,
                        updateBlock: (inout WindowInfo) -> Void)
    {
        if let windowID,
           let existing = windowSet.first(where: { $0.id == windowID })
        {
            var updated = existing
            updateBlock(&updated)
            windowSet.remove(existing)
            windowSet.insert(updated)
            return
        }

        if let existing = windowSet.first(where: { $0.axElement == element }) {
            var updated = existing
            updateBlock(&updated)
            windowSet.remove(existing)
            windowSet.insert(updated)
        }
    }
}

func axObserverCallback(observer: AXObserver, element: AXUIElement, notificationName: CFString, userData: UnsafeMutableRawPointer?) {
    guard let userData else { return }
    let pid = pid_t(Int(bitPattern: userData))

    DispatchQueue.main.async {
        if let app = NSRunningApplication(processIdentifier: pid),
           let observerInstance = activeWindowManipulationObserversInstance
        {
            observerInstance.processAXNotification(element: element, notificationName: notificationName as String, app: app, pid: pid)
        }
    }
}
