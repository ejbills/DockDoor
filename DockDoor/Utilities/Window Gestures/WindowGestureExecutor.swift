import AppKit
import ApplicationServices
import Carbon.HIToolbox.Events
import Defaults

final class WindowGestureChain: @unchecked Sendable {
    private let lock = NSLock()
    private var storedWindow: GestureWindowTarget?

    var window: GestureWindowTarget? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storedWindow
        }
        set {
            lock.lock()
            storedWindow = newValue
            lock.unlock()
        }
    }
}

final class WindowGestureExecutor {
    private let queue = DispatchQueue(label: "com.ethanbills.DockDoor.windowGestures.actions", qos: .userInteractive)
    private let registry = WindowSnapRegistry.shared
    private let minimizeHistory = WindowMinimizeHistory.shared
    private static let fullScreenTransitionDelay: TimeInterval = 0.8

    private static let moveTabMenuTitles: Set<String> = {
        let key = "Move Tab to New Window"
        let appKitTitle = Bundle(for: NSWindow.self).localizedString(forKey: key, value: key, table: "MenuCommands")
        return [key, appKitTitle]
    }()

    func perform(_ command: WindowGestureCommand, zone: WindowGestureZone, chain: WindowGestureChain, cursor: CGPoint) {
        queue.async { [self] in
            let chained = chain.window
            let result = run(command, zone: zone, window: chained ?? zone.window, app: chained?.app ?? zone.app, cursor: cursor)
            if command.chainsWindow, let result {
                chain.window = result
            }
        }
    }

    private func run(_ command: WindowGestureCommand, zone: WindowGestureZone, window: GestureWindowTarget?, app: NSRunningApplication?, cursor: CGPoint) -> GestureWindowTarget? {
        switch command {
        case let .snap(region):
            guard let window else { return nil }
            snap(window, to: region)
            return window
        case .center:
            guard let window else { return nil }
            center(window)
            return window
        case .minimize:
            guard let window else { return nil }
            minimize(window)
        case .close:
            window?.close()
        case .quitApp:
            app?.terminate()
        case .toggleFullScreen:
            guard let window else { return nil }
            window.focus()
            window.setFullScreen(!window.isFullscreen)
        case .fullScreenOnOtherDisplay:
            guard let window else { return nil }
            fullScreenOnOtherDisplay(window)
        case .hideApp:
            app?.hide()
        case .hideOtherApps:
            guard let app else { return nil }
            hideOtherApps(except: app)
        case let .moveToSpace(offset):
            guard let window else { return nil }
            moveToSpace(window, offset: offset)
        case let .moveToDisplay(direction):
            guard let window else { return nil }
            moveToDisplay(window, toward: direction, cursor: cursor)
            return window
        case .closeTab:
            closeTab(in: zone)
        case .detachTab:
            return detachTab(in: zone)
        case let .cycleWindows(forward):
            guard let app else { return nil }
            return cycleWindows(of: app, forward: forward)
        case .restoreLastMinimized:
            guard let app else { return nil }
            return restoreLastMinimized(of: app)
        case .restoreAllMinimized:
            guard let app else { return nil }
            restore(minimizedWindows(of: app))
        case .minimizeFrontWindow:
            guard let app, let front = frontWindow(of: app) else { return nil }
            minimize(front)
        case .minimizeAllWindows:
            guard let app else { return nil }
            minimizeAll(visibleWindows(of: app))
        case .newTabOrWindow:
            guard let app else { return nil }
            openNewTabOrWindow(in: app)
        case .toggleHidden:
            guard let app else { return nil }
            if app.isHidden {
                bringForward(app)
            } else {
                app.hide()
            }
        case .pickUpFrontWindow:
            guard let app else { return nil }
            return pickUpFrontWindow(of: app)
        case let .switchApp(forward):
            switchApp(forward: forward)
        case .openSwitcher:
            return nil
        case let .minimizeAllOnDisplay(allDisplays):
            guard let screen = WindowGestureScreens.screen(atQuartzPoint: cursor) else { return nil }
            minimizeAll(onScreenWindows(screen: allDisplays ? nil : screen))
        case let .restoreAllOnDisplay(allDisplays):
            guard let screen = WindowGestureScreens.screen(atQuartzPoint: cursor) else { return nil }
            restoreAll(screen: allDisplays ? nil : screen)
        case let .unsnapAll(allDisplays):
            guard let screen = WindowGestureScreens.screen(atQuartzPoint: cursor) else { return nil }
            for record in registry.liveRecords(screenIdentifier: allDisplays ? nil : screen.uniqueIdentifier()) {
                record.target.setFrame(record.restoreFrame)
                registry.remove(record.windowID)
            }
        case let .moveSnappedWindows(direction):
            guard let screen = WindowGestureScreens.screen(atQuartzPoint: cursor) else { return nil }
            moveSnappedWindows(from: screen, toward: direction)
        }
        return nil
    }

    // MARK: - Snapping

    private func snap(_ window: GestureWindowTarget, to region: SnapRegion) {
        guard let current = window.frame, let screen = WindowGestureScreens.screen(containing: current) else { return }
        let target = WindowGestureScreens.geometry(for: screen).frame(for: region)
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
        if Defaults[.windowGestureActivateAfterSnap] {
            window.focus()
        }
    }

    private func center(_ window: GestureWindowTarget) {
        guard let current = window.frame, let screen = WindowGestureScreens.screen(containing: current) else { return }
        let usable = WindowGestureScreens.usableFrame(for: screen)
        let record = registry.remove(window.windowID)

        let frame: CGRect = switch Defaults[.windowGestureCenterAction] {
        case .centerAndRestore:
            WindowGestureScreens.centered(record?.restoreFrame.size ?? current.size, in: usable)
        case .restore:
            record?.restoreFrame ?? WindowGestureScreens.centered(current.size, in: usable)
        case .center:
            WindowGestureScreens.centered(current.size, in: usable)
        }
        window.setFrame(frame)
        if Defaults[.windowGestureActivateAfterSnap] {
            window.focus()
        }
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

    private func restoreLastMinimized(of app: NSRunningApplication) -> GestureWindowTarget? {
        let fromHistory = minimizeHistory.popLatest(pid: app.processIdentifier)
        let window = fromHistory ?? minimizedWindows(of: app).first
        DebugLogger.log("WindowGestures", details: "restore last minimized: \(fromHistory != nil ? "history" : window != nil ? "cache" : "none") window=\(window?.windowID.map(String.init) ?? "-")")
        guard let window else { return pickUpFrontWindow(of: app) }
        window.restore()
        return window
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

    private func restoreAll(screen: NSScreen?) {
        let screenIdentifier = screen?.uniqueIdentifier()
        var targets = minimizeHistory.take(screenIdentifier: screenIdentifier)
        let known = Set(targets.compactMap(\.windowID))
        let cached = WindowUtil.getAllWindowsIgnoringSwitcherFilters().filter { window in
            window.isMinimized && !window.isWindowlessApp && !known.contains(window.id)
                && (screenIdentifier == nil || window.screenIdentifier == screenIdentifier)
        }
        targets.append(contentsOf: cached.map(GestureWindowTarget.init(window:)))
        restore(targets)
    }

    // MARK: - Fullscreen & Displays

    private func fullScreenOnOtherDisplay(_ window: GestureWindowTarget) {
        if window.isFullscreen {
            window.setFullScreen(false)
            Thread.sleep(forTimeInterval: Self.fullScreenTransitionDelay)
        }
        guard let current = window.frame,
              let source = WindowGestureScreens.screen(containing: current),
              let destination = WindowGestureScreens.otherScreen(than: source)
        else { return }

        window.setFrame(WindowGestureScreens.map(current, from: source.visibleFrame, to: destination.visibleFrame))
        registry.remove(window.windowID)
        window.focus()
        queue.asyncAfter(deadline: .now() + 0.25) {
            window.setFullScreen(true)
        }
    }

    private func moveToDisplay(_ window: GestureWindowTarget, toward direction: GestureDirection, cursor: CGPoint) {
        guard !window.isFullscreen,
              let current = window.frame,
              let source = WindowGestureScreens.screen(containing: current),
              let destination = WindowGestureScreens.screen(from: source, toward: direction)
        else { return }

        let sourceFrame = WindowGestureScreens.usableFrame(for: source)
        let destinationFrame = WindowGestureScreens.usableFrame(for: destination)
        if var record = registry.liveRecord(for: window.windowID) {
            let target = WindowGestureScreens.geometry(for: destination).frame(for: record.region)
            window.setFrame(target)
            record.snappedFrame = window.frame ?? target
            record.restoreFrame = WindowGestureScreens.map(record.restoreFrame, from: sourceFrame, to: destinationFrame)
            record.screenIdentifier = destination.uniqueIdentifier()
            registry.set(record)
        } else {
            window.setFrame(WindowGestureScreens.map(current, from: sourceFrame, to: destinationFrame))
        }

        if Defaults[.windowGestureMoveCursorWithWindow], let moved = window.frame {
            warpCursor(cursor, from: current, to: moved)
        }
        window.focus()
    }

    private func moveSnappedWindows(from source: NSScreen, toward direction: GestureDirection) {
        guard let destination = WindowGestureScreens.screen(from: source, toward: direction) else { return }
        let geometry = WindowGestureScreens.geometry(for: destination)
        let sourceFrame = WindowGestureScreens.usableFrame(for: source)
        let destinationFrame = WindowGestureScreens.usableFrame(for: destination)
        for var record in registry.liveRecords(screenIdentifier: source.uniqueIdentifier()) {
            let target = geometry.frame(for: record.region)
            record.target.setFrame(target)
            record.snappedFrame = record.target.frame ?? target
            record.restoreFrame = WindowGestureScreens.map(record.restoreFrame, from: sourceFrame, to: destinationFrame)
            record.screenIdentifier = destination.uniqueIdentifier()
            registry.set(record)
        }
    }

    private func warpCursor(_ cursor: CGPoint, from oldFrame: CGRect, to newFrame: CGRect) {
        guard oldFrame.width > 0, oldFrame.height > 0, let primaryMaxY = NSScreen.screens.first?.frame.maxY else { return }
        let appKitCursor = CGPoint(x: cursor.x, y: primaryMaxY - cursor.y)
        let relativeX = min(max((appKitCursor.x - oldFrame.minX) / oldFrame.width, 0), 1)
        let relativeY = min(max((appKitCursor.y - oldFrame.minY) / oldFrame.height, 0), 1)
        let destination = CGPoint(
            x: newFrame.minX + relativeX * newFrame.width,
            y: primaryMaxY - (newFrame.minY + relativeY * newFrame.height)
        )
        CGWarpMouseCursorPosition(destination)
        CGAssociateMouseAndMouseCursorPosition(1)
    }

    // MARK: - Spaces

    private func moveToSpace(_ window: GestureWindowTarget, offset: Int) {
        guard offset != 0, !window.isFullscreen,
              let windowID = window.windowID,
              let currentSpace = windowID.cgsSpaces().first,
              let list = WindowSpaces.spaceList(containing: currentSpace),
              let currentIndex = list.spaces.firstIndex(of: currentSpace)
        else { return }

        let step = offset < 0 ? -1 : 1
        var remaining = abs(offset)
        var index = currentIndex
        var targetIndex: Int?
        while remaining > 0 {
            index += step
            guard list.spaces.indices.contains(index) else { break }
            if list.desktopSpaces.contains(list.spaces[index]) {
                targetIndex = index
                remaining -= 1
            }
        }

        guard let targetIndex, WindowSpaces.move(windowID: windowID, toManagedSpace: list.spaces[targetIndex]) else { return }
        if let cached = window.cachedWindow {
            WindowUtil.updateCachedWindowState(cached, spaceID: .some(Int(list.spaces[targetIndex])))
        }

        guard DockObserver.canPostEvents else { return }
        let keyCode = CGKeyCode(step < 0 ? kVK_LeftArrow : kVK_RightArrow)
        for _ in 0 ..< abs(targetIndex - currentIndex) {
            DockObserver.postControlArrowKey(keyCode)
            Thread.sleep(forTimeInterval: 0.05)
        }
        queue.asyncAfter(deadline: .now() + 0.5) {
            window.focus()
        }
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

    private func detachTab(in zone: WindowGestureZone) -> GestureWindowTarget? {
        guard case let .tab(target, tab, _, _) = zone, select(tab, in: target) else { return nil }
        guard let item = Self.menuItem(in: target.pid, where: { item in
            (try? item.title()).map(Self.moveTabMenuTitles.contains) ?? false
        }) else { return nil }

        try? item.performAction(kAXPressAction)
        Thread.sleep(forTimeInterval: 0.35)
        let appElement = AXUIElementCreateApplication(target.pid)
        guard let detached = (try? appElement.focusedWindow()) ?? nil else { return nil }
        return GestureWindowTarget(element: detached, app: target.app)
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

    private func visibleWindows(of app: NSRunningApplication) -> [GestureWindowTarget] {
        appWindows(of: app).filter { !$0.isMinimized }
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

    private func cycleWindows(of app: NSRunningApplication, forward: Bool) -> GestureWindowTarget? {
        let windows = visibleWindows(of: app)
        guard !windows.isEmpty else { return restoreLastMinimized(of: app) }

        let focusedID = app.isActive ? frontWindow(of: app)?.windowID : nil
        let next: GestureWindowTarget
        if let focusedID, let index = windows.firstIndex(where: { $0.windowID == focusedID }) {
            next = windows[(index + (forward ? 1 : -1) + windows.count) % windows.count]
        } else {
            let mostRecent = windows.max { ($0.cachedWindow?.lastAccessedTime ?? .distantPast) < ($1.cachedWindow?.lastAccessedTime ?? .distantPast) }
            next = mostRecent ?? windows[0]
        }
        next.focus()
        return next
    }

    private func pickUpFrontWindow(of app: NSRunningApplication) -> GestureWindowTarget? {
        if app.isHidden {
            app.unhide()
        }
        guard let front = frontWindow(of: app), !front.isMinimized else {
            bringForward(app)
            return nil
        }
        front.focus()
        return front
    }

    private func hideOtherApps(except app: NSRunningApplication) {
        bringForward(app)
        let ownPID = ProcessInfo.processInfo.processIdentifier
        for other in NSWorkspace.shared.runningApplications
            where other.activationPolicy == .regular && other.processIdentifier != app.processIdentifier && other.processIdentifier != ownPID
        {
            other.hide()
        }
    }

    private func openNewTabOrWindow(in app: NSRunningApplication) {
        if app.isHidden {
            app.unhide()
        }
        let item = Self.menuItem(in: app.processIdentifier, menus: 2 ..< 5) { Self.isCommandShortcut($0, character: "T") }
            ?? Self.menuItem(in: app.processIdentifier, menus: 2 ..< 5) { Self.isCommandShortcut($0, character: "N") }
        if let item {
            try? item.performAction(kAXPressAction)
            bringForward(app)
        } else {
            WindowUtil.activateAndOpenNewWindow(app: app)
        }
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

    private func onScreenWindows(screen: NSScreen?) -> [GestureWindowTarget] {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let screenFrame = screen?.cgFrame
        var idsByPID: [pid_t: Set<CGWindowID>] = [:]
        for window in WindowGestureZoneResolver.onScreenWindows() {
            guard (window[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                  let pid = (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value, pid != ownPID,
                  let id = (window[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                  let bounds = WindowGestureZoneResolver.bounds(of: window), bounds.width > 40, bounds.height > 40
            else { continue }
            if let screenFrame, !screenFrame.contains(CGPoint(x: bounds.midX, y: bounds.midY)) {
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

    private static func isCommandShortcut(_ item: AXUIElement, character: String) -> Bool {
        guard (try? item.attribute(kAXEnabledAttribute, Bool.self)) == true,
              let commandCharacter = (try? item.attribute(kAXMenuItemCmdCharAttribute, String.self)) ?? nil,
              commandCharacter.caseInsensitiveCompare(character) == .orderedSame
        else { return false }
        let modifiers = (try? item.attribute(kAXMenuItemCmdModifiersAttribute, Int.self)) ?? nil
        return (modifiers ?? 0) == 0
    }

    private static func menuItem(in pid: pid_t, menus range: Range<Int>? = nil, where matches: (AXUIElement) -> Bool) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(pid)
        guard let menuBar = (try? appElement.attribute(kAXMenuBarAttribute, AXUIElement.self)) ?? nil,
              let barItems = try? menuBar.children()
        else { return nil }

        let candidates: [AXUIElement] = if let range {
            Array(barItems[min(range.lowerBound, barItems.count) ..< min(range.upperBound, barItems.count)])
        } else {
            barItems.reversed()
        }

        for barItem in candidates {
            guard let menu = (try? barItem.children())?.first, let items = try? menu.children() else { continue }
            if let match = items.first(where: matches) {
                return match
            }
        }
        return nil
    }

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
