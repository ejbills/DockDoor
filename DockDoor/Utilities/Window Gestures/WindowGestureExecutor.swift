import AppKit
import ApplicationServices
import Carbon.HIToolbox.Events

final class WindowGestureExecutor {
    private let queue = DispatchQueue(label: "com.ethanbills.DockDoor.windowGestures.actions", qos: .userInteractive)
    private let registry = WindowSnapRegistry.shared
    private static let fullScreenTransitionDelay: TimeInterval = 0.8

    func perform(_ command: WindowGestureCommand, zone: WindowGestureZone, cursor: CGPoint) {
        queue.async { [self] in
            run(command, zone: zone, cursor: cursor)
        }
    }

    private func run(_ command: WindowGestureCommand, zone: WindowGestureZone, cursor: CGPoint) {
        switch command {
        case let .window(action):
            guard let window = zone.window else { return }
            perform(action, on: window)
        case .closeTab:
            closeTab(in: zone)
        case .minimizeFrontWindow:
            guard let app = zone.app, let window = frontWindow(of: app) else { return }
            minimize(window)
        case .restoreLastMinimized:
            guard let app = zone.app else { return }
            restoreLastMinimized(of: app)
        case .quitApp:
            zone.app?.terminate()
        case let .switchApp(forward):
            switchApp(forward: forward)
        case .openSwitcher:
            break
        case .minimizeAllOnDisplay:
            minimizeAll(on: NSScreen.screenFromQuartzPoint(cursor))
        case .restoreAllOnDisplay:
            restoreAll(on: NSScreen.screenFromQuartzPoint(cursor))
        }
    }

    // MARK: - Windows

    private func perform(_ action: WindowAction, on window: WindowInfo) {
        if action == .center {
            window.positionWindow(.center, size: registry.remove(window.id)?.restoreFrame.size)
            return
        }
        guard action.positionRect != nil, let current = window.currentWindowFrame() else {
            _ = action.perform(on: window)
            return
        }
        let restoreFrame = registry.liveRecord(for: window)?.restoreFrame ?? current
        registry.remove(window.id)
        _ = action.perform(on: window)
        registry.snapped(window, restoreFrame: restoreFrame)
    }

    private func minimize(_ window: WindowInfo) {
        var target = window
        guard (try? window.axElement.isFullscreen()) == true else {
            target.toggleMinimize()
            return
        }
        target.toggleFullScreen()
        queue.asyncAfter(deadline: .now() + Self.fullScreenTransitionDelay) {
            var target = window
            target.toggleMinimize()
        }
    }

    private func frontWindow(of app: NSRunningApplication) -> WindowInfo? {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        guard let element = ((try? appElement.focusedWindow()) ?? nil)
            ?? ((try? appElement.attribute(kAXMainWindowAttribute, AXUIElement.self)) ?? nil)
        else { return nil }
        return WindowUtil.windowInfo(for: element, app: app)
    }

    private func restoreLastMinimized(of app: NSRunningApplication) {
        let minimized = WindowUtil.readCachedWindows(for: app.processIdentifier)
            .filter { $0.isMinimized && !$0.isWindowlessApp }
            .max { $0.lastAccessedTime < $1.lastAccessedTime }
        guard var window = minimized else {
            bringForward(app)
            return
        }
        window.toggleMinimize()
    }

    private func minimizeAll(on screen: NSScreen) {
        let screenIdentifier = screen.uniqueIdentifier()
        let windows = WindowUtil.filterWindowsByCurrentSpace(WindowUtil.getAllWindowsIgnoringSwitcherFilters())
            .filter { !$0.isHidden && !$0.isWindowlessApp && $0.screenIdentifier == screenIdentifier }
        WindowUtil.minimizeWindowsAsync(windows)
    }

    private func restoreAll(on screen: NSScreen) {
        let screenIdentifier = screen.uniqueIdentifier()
        let windows = WindowUtil.getAllWindowsIgnoringSwitcherFilters()
            .filter { $0.isMinimized && !$0.isWindowlessApp && $0.screenIdentifier == screenIdentifier }
        for window in windows {
            if window.app.isHidden {
                window.app.unhide()
            }
            try? window.axElement.setAttribute(kAXMinimizedAttribute, false)
            WindowUtil.updateCachedWindowState(window, isMinimized: false)
        }
        windows.max { $0.lastAccessedTime < $1.lastAccessedTime }?.bringToFront()
    }

    // MARK: - Tabs

    private func closeTab(in zone: WindowGestureZone) {
        guard case let .tab(window, tab, _, _) = zone else { return }
        if let closeButton = Self.closeButton(in: tab) {
            try? closeButton.performAction(kAXPressAction)
            return
        }
        guard select(tab, in: window) else { return }
        WindowUtil.postCommandShortcut(CGKeyCode(kVK_ANSI_W), to: window.ownerApp.processIdentifier)
    }

    private func select(_ tab: AXUIElement, in window: WindowInfo) -> Bool {
        window.bringToFront()
        try? tab.performAction(kAXPressAction)
        for _ in 0 ..< 15 {
            let focused = (try? window.appAxElement.focusedWindow()) ?? nil
            if Self.isSelected(tab), let focused, CFEqual(focused, window.axElement) {
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
}
