import AppKit
import ApplicationServices
import Carbon.HIToolbox.Events

final class WindowGestureExecutor {
    private let queue = DispatchQueue(label: "com.ethanbills.DockDoor.windowGestures.actions", qos: .userInteractive)
    private let registry = WindowSnapRegistry.shared
    private let minimizeHistory = WindowMinimizeHistory.shared
    private static let fullScreenTransitionDelay: TimeInterval = 0.8

    func perform(_ command: WindowGestureCommand, zone: WindowGestureZone, cursor: CGPoint) {
        queue.async { [self] in
            run(command, zone: zone, cursor: cursor)
        }
    }

    private func run(_ command: WindowGestureCommand, zone: WindowGestureZone, cursor: CGPoint) {
        let window = zone.window
        let app = zone.app
        switch command {
        case let .snap(region):
            guard let window else { return }
            snap(window, to: region)
        case .center:
            guard let window else { return }
            center(window)
        case .minimize:
            guard let window else { return }
            minimize(window)
        case .close:
            window?.close()
        case .closeTab:
            closeTab(in: zone)
        case .toggleFullScreen:
            guard let window else { return }
            window.focus()
            window.setFullScreen(!window.isFullscreen)
        case .minimizeFrontWindow:
            guard let app, let front = frontWindow(of: app) else { return }
            minimize(front)
        case .restoreLastMinimized:
            guard let app else { return }
            restoreLastMinimized(of: app)
        case .quitApp:
            app?.terminate()
        case let .switchApp(forward):
            switchApp(forward: forward)
        case .openSwitcher:
            break
        case .minimizeAllOnDisplay:
            guard let screen = WindowGestureScreens.screen(atQuartzPoint: cursor) else { return }
            minimizeAll(onScreenWindows(screen: screen))
        case .restoreAllOnDisplay:
            guard let screen = WindowGestureScreens.screen(atQuartzPoint: cursor) else { return }
            restoreAll(screen: screen)
        }
    }

    // MARK: - Snapping

    private func snap(_ window: GestureWindowTarget, to region: SnapRegion) {
        guard let current = window.frame, let screen = WindowGestureScreens.screen(containing: current) else { return }
        let target = WindowGestureScreens.frame(for: region, on: screen)
        let restoreFrame = registry.liveRecord(for: window.windowID)?.restoreFrame ?? current

        window.setFrame(target)
        if let windowID = window.windowID {
            registry.set(.init(
                windowID: windowID,
                target: window,
                region: region,
                snappedFrame: window.frame ?? target,
                restoreFrame: restoreFrame,
                screenIdentifier: screen.uniqueIdentifier()
            ))
        }
        window.focus()
    }

    private func center(_ window: GestureWindowTarget) {
        guard let current = window.frame, let screen = WindowGestureScreens.screen(containing: current) else { return }
        let usable = WindowGestureScreens.usableFrame(for: screen)
        let record = registry.remove(window.windowID)

        window.setFrame(WindowGestureScreens.centered(record?.restoreFrame.size ?? current.size, in: usable))
        window.focus()
    }

    // MARK: - Minimizing

    private func minimize(_ window: GestureWindowTarget) {
        let screenIdentifier = window.frame.flatMap(WindowGestureScreens.screen(containing:))?.uniqueIdentifier()
        minimizeHistory.push([.init(target: window, screenIdentifier: screenIdentifier)])
        guard window.isFullscreen else {
            window.minimize()
            return
        }
        window.setFullScreen(false)
        queue.asyncAfter(deadline: .now() + Self.fullScreenTransitionDelay) {
            window.minimize()
        }
    }

    private func minimizeAll(_ windows: [GestureWindowTarget]) {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let targets = windows.filter { $0.pid != ownPID }
        minimizeHistory.push(targets.map { window in
            .init(target: window, screenIdentifier: window.frame.flatMap(WindowGestureScreens.screen(containing:))?.uniqueIdentifier())
        })
        for window in targets {
            window.minimize()
        }
    }

    private func restoreLastMinimized(of app: NSRunningApplication) {
        let fromHistory = minimizeHistory.popLatest(pid: app.processIdentifier)
        let window = fromHistory ?? minimizedWindows(of: app).first
        DebugLogger.log("WindowGestures", details: "restore last minimized: \(fromHistory != nil ? "history" : window != nil ? "cache" : "none") window=\(window?.windowID.map(String.init) ?? "-")")
        guard let window else {
            bringForward(app)
            return
        }
        window.restore()
    }

    private func restore(_ windows: [GestureWindowTarget]) {
        guard !windows.isEmpty else { return }
        for window in windows {
            if window.app.isHidden {
                window.app.unhide()
            }
            try? window.element.setAttribute(kAXMinimizedAttribute, false)
            if let cached = window.cachedWindow {
                WindowUtil.updateCachedWindowState(cached, isMinimized: false)
            }
        }
        windows.last?.focus()
    }

    private func restoreAll(screen: NSScreen) {
        let screenIdentifier = screen.uniqueIdentifier()
        var targets = minimizeHistory.take(screenIdentifier: screenIdentifier)
        let known = Set(targets.compactMap(\.windowID))
        let cached = WindowUtil.getAllWindowsIgnoringSwitcherFilters().filter { window in
            window.isMinimized && !window.isWindowlessApp && !known.contains(window.id) && window.screenIdentifier == screenIdentifier
        }
        targets.append(contentsOf: cached.map(GestureWindowTarget.init(window:)))
        restore(targets)
    }

    // MARK: - Tabs

    private func closeTab(in zone: WindowGestureZone) {
        guard case let .tab(target, tab, _, _) = zone else { return }
        if let closeButton = Self.closeButton(in: tab) {
            try? closeButton.performAction(kAXPressAction)
            return
        }
        guard select(tab, in: target) else { return }
        Self.postShortcut(keyCode: CGKeyCode(kVK_ANSI_W), to: target.pid)
    }

    private func select(_ tab: AXUIElement, in target: GestureWindowTarget) -> Bool {
        target.focus()
        try? tab.performAction(kAXPressAction)
        let appElement = AXUIElementCreateApplication(target.pid)
        for _ in 0 ..< 15 {
            let focused = (try? appElement.focusedWindow()) ?? nil
            if Self.isSelected(tab), let focused, CFEqual(focused, target.element) {
                return true
            }
            Thread.sleep(forTimeInterval: 0.03)
        }
        return false
    }

    private static func isSelected(_ tab: AXUIElement) -> Bool {
        if let value = (try? tab.attribute(kAXValueAttribute, NSNumber.self)) ?? nil {
            return value.intValue == 1
        }
        return ((try? tab.attribute(kAXSelectedAttribute, Bool.self)) ?? nil) == true
    }

    private static func closeButton(in tab: AXUIElement) -> AXUIElement? {
        var queue: [(AXUIElement, Int)] = [(tab, 0)]
        var fallback: AXUIElement?
        while !queue.isEmpty {
            let (element, depth) = queue.removeFirst()
            guard depth < 3, let children = try? element.children() else { continue }
            for child in children {
                guard (try? child.role()) == kAXButtonRole as String else {
                    queue.append((child, depth + 1))
                    continue
                }
                if (try? child.subrole()) == kAXCloseButtonSubrole as String {
                    return child
                }
                let description = (try? child.attribute(kAXDescriptionAttribute, String.self)) ?? nil
                if fallback == nil, description?.localizedCaseInsensitiveContains("close") == true {
                    fallback = child
                }
            }
        }
        return fallback
    }

    // MARK: - Apps

    private func appWindows(of app: NSRunningApplication) -> [GestureWindowTarget] {
        let cached = WindowUtil.readCachedWindows(for: app.processIdentifier).filter { !$0.isWindowlessApp }
        if !cached.isEmpty {
            return WindowUtil.filterWindowsByCurrentSpace(cached)
                .sorted { ($0.creationTime, $0.id) < ($1.creationTime, $1.id) }
                .map(GestureWindowTarget.init(window:))
        }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        return ((try? appElement.windows()) ?? [])
            .filter { (try? $0.subrole()) == kAXStandardWindowSubrole as String }
            .map { GestureWindowTarget(element: $0, app: app) }
    }

    private func minimizedWindows(of app: NSRunningApplication) -> [GestureWindowTarget] {
        let cached = WindowUtil.readCachedWindows(for: app.processIdentifier)
            .filter { $0.isMinimized && !$0.isWindowlessApp }
            .sorted { $0.lastAccessedTime > $1.lastAccessedTime }
            .map(GestureWindowTarget.init(window:))
        let fromHistory = minimizeHistory.take(pid: app.processIdentifier)
        let historyIDs = Set(fromHistory.compactMap(\.windowID))
        let combined = Array(fromHistory.reversed()) + cached.filter { !($0.windowID.map(historyIDs.contains) ?? false) }
        if !combined.isEmpty {
            return combined.filter(\.isMinimized)
        }
        return appWindows(of: app).filter(\.isMinimized)
    }

    private func frontWindow(of app: NSRunningApplication) -> GestureWindowTarget? {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        let element = ((try? appElement.focusedWindow()) ?? nil)
            ?? ((try? appElement.attribute(kAXMainWindowAttribute, AXUIElement.self)) ?? nil)
        return element.map { GestureWindowTarget(element: $0, app: app) }
    }

    private func switchApp(forward: Bool) {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let ordered = DockObserver.activeInstance?.runningApplicationsInDockOrder() ?? []
        let apps = (ordered.isEmpty ? NSWorkspace.shared.runningApplications : ordered)
            .filter { $0.activationPolicy == .regular && $0.processIdentifier != ownPID && !$0.isTerminated }
        guard !apps.isEmpty else { return }

        let current = NSWorkspace.shared.frontmostApplication
        let next: NSRunningApplication = if let index = apps.firstIndex(where: { $0.processIdentifier == current?.processIdentifier }) {
            apps[(index + (forward ? 1 : -1) + apps.count) % apps.count]
        } else {
            forward ? apps[0] : apps[apps.count - 1]
        }
        bringForward(next)
    }

    private func bringForward(_ app: NSRunningApplication) {
        if app.isHidden {
            app.unhide()
        }
        let windows = WindowUtil.readCachedWindows(for: app.processIdentifier).filter { !$0.isMinimized && !$0.isWindowlessApp }
        if let window = windows.max(by: { $0.lastAccessedTime < $1.lastAccessedTime }) {
            window.bringToFront()
        } else {
            WindowInfo.windowlessEntry(for: app).bringToFront()
        }
    }

    private func onScreenWindows(screen: NSScreen) -> [GestureWindowTarget] {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let screenFrame = screen.cgFrame
        var idsByPID: [pid_t: Set<CGWindowID>] = [:]
        for window in WindowGestureZoneResolver.onScreenWindows() {
            guard (window[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                  let pid = (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value, pid != ownPID,
                  let id = (window[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                  let bounds = WindowGestureZoneResolver.bounds(of: window), bounds.width > 40, bounds.height > 40
            else { continue }
            if !screenFrame.contains(CGPoint(x: bounds.midX, y: bounds.midY)) {
                continue
            }
            idsByPID[pid, default: []].insert(CGWindowID(id))
        }

        return idsByPID.flatMap { pid, ids -> [GestureWindowTarget] in
            guard let app = NSRunningApplication(processIdentifier: pid), !AXResponsiveness.isUnresponsive(pid) else { return [] }
            let cached = WindowUtil.readCachedWindows(for: pid).filter { ids.contains($0.id) && !$0.isMinimized }
            if cached.count == ids.count {
                return cached.map(GestureWindowTarget.init(window:))
            }
            let appElement = AXUIElementCreateApplication(pid)
            return ((try? appElement.windows()) ?? [])
                .map { GestureWindowTarget(element: $0, app: app) }
                .filter { target in target.windowID.map(ids.contains) ?? false }
        }
    }

    // MARK: - Menus & Keys

    private static func postShortcut(keyCode: CGKeyCode, to pid: pid_t) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.postToPid(pid)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.postToPid(pid)
    }
}
