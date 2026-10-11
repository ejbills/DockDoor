import AppKit
import ApplicationServices

enum WindowGestureZone {
    case window(WindowInfo, isFullscreen: Bool)
    case tab(WindowInfo, tab: AXUIElement, isFullscreen: Bool, scrollable: Bool)
    case app(NSRunningApplication)
    case menuBar

    var kind: WindowGestureZoneKind {
        switch self {
        case let .window(_, isFullscreen): .window(isFullscreen: isFullscreen)
        case let .tab(_, _, isFullscreen, _): .tab(isFullscreen: isFullscreen)
        case .app: .app
        case .menuBar: .menuBar
        }
    }

    var consumesScroll: Bool {
        if case let .tab(_, _, _, scrollable) = self {
            return !scrollable
        }
        return true
    }

    var window: WindowInfo? {
        switch self {
        case let .window(window, _), let .tab(window, _, _, _): window
        case .app, .menuBar: nil
        }
    }

    var app: NSRunningApplication? {
        switch self {
        case let .window(window, _), let .tab(window, _, _, _): window.app
        case let .app(app): app
        case .menuBar: nil
        }
    }
}

enum WindowGestureZoneResolver {
    static let titleBarHeight: CGFloat = 28
    static let titleBandHeight: CGFloat = 36
    static let maximumToolbarHeight: CGFloat = 96
    private static let messagingTimeout: Float = 0.15
    private static let classificationDepth = 8
    private static let resolutionBudget: CFAbsoluteTime = 0.2

    private static let acceptedWindowSubroles: Set<String> = [kAXStandardWindowSubrole as String, kAXDialogSubrole as String]
    private static let interactiveRoles: Set<String> = [
        kAXTextFieldRole as String, kAXTextAreaRole as String, kAXSliderRole as String, kAXScrollBarRole as String,
        kAXComboBoxRole as String, kAXIncrementorRole as String, kAXValueIndicatorRole as String,
    ]
    private static let scrollingRoles: Set<String> = [
        kAXScrollAreaRole as String, kAXTableRole as String, kAXOutlineRole as String, kAXListRole as String,
        kAXBrowserRole as String, kAXGridRole as String, kAXLayoutAreaRole as String, kAXTextAreaRole as String,
    ]
    private static let contentRoles = scrollingRoles.union(["AXWebArea"])

    private struct AXNode {
        let element: AXUIElement
        let role: String?
        let subrole: String?
        let parent: AXUIElement?
    }

    private enum Outcome {
        case zone(WindowGestureZone)
        case blocked
        case notHere
    }

    static func resolve(at point: CGPoint) -> WindowGestureZone? {
        guard !isScreenLocked else { return nil }
        let screen = NSScreen.screenFromQuartzPoint(point)
        let windows = onScreenWindows()

        switch menuBarZone(at: point, screen: screen, windows: windows) {
        case let .zone(zone): return zone
        case .blocked: return nil
        case .notHere: break
        }

        switch dockZone(at: point) {
        case let .zone(zone): return zone
        case .blocked: return nil
        case .notHere: break
        }

        if case let .zone(zone) = windowZone(at: point, windows: windows) {
            return zone
        }
        return nil
    }

    // MARK: - Menu Bar

    private static func menuBarZone(at point: CGPoint, screen: NSScreen, windows: [[String: AnyObject]]) -> Outcome {
        let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
        let screenTop = screen.cgFrame.minY
        guard menuBarHeight > 0, point.y >= screenTop, point.y < screenTop + menuBarHeight else { return .notHere }

        let statusLevel = Int(CGWindowLevelForKey(.statusWindow))
        let coversStatusItem = windows.contains { window in
            guard let layer = (window[kCGWindowLayer as String] as? NSNumber)?.intValue, layer == statusLevel else { return false }
            return bounds(of: window)?.contains(point) == true
        }
        if coversStatusItem { return .blocked }

        guard let frontmost = NSWorkspace.shared.frontmostApplication,
              frontmost.processIdentifier != ProcessInfo.processInfo.processIdentifier
        else {
            return .zone(.menuBar)
        }

        let appElement = AXUIElementCreateApplication(frontmost.processIdentifier)
        guard let hit = element(in: appElement, at: point),
              let node = node(for: hit),
              node.role == kAXMenuBarItemRole as String
        else {
            return .zone(.menuBar)
        }

        guard let menuBar = node.parent,
              let items = try? menuBar.children(),
              items.count > 1, CFEqual(items[1], hit)
        else {
            return .blocked
        }
        return .zone(.app(frontmost))
    }

    // MARK: - Dock

    private static func dockZone(at point: CGPoint) -> Outcome {
        guard let dockObserver = DockObserver.activeInstance, dockObserver.isPointNearDock(point) else { return .notHere }
        let hovered = dockObserver.getDockItemAppStatusUnderMouse()
        guard hovered.dockItemElement != nil else { return .notHere }
        guard case let .success(app) = hovered.status,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier
        else {
            return .blocked
        }
        return .zone(.app(app))
    }

    // MARK: - Windows

    private static func windowZone(at point: CGPoint, windows: [[String: AnyObject]]) -> Outcome {
        guard let hit = topWindow(at: point, in: windows) else {
            return .notHere
        }

        guard let pid = (hit[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
              pid != ProcessInfo.processInfo.processIdentifier,
              (hit[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
              let windowBounds = bounds(of: hit),
              let app = NSRunningApplication(processIdentifier: pid),
              app.activationPolicy != .prohibited
        else {
            return .blocked
        }

        let offsetFromTop = point.y - windowBounds.minY
        if offsetFromTop > maximumToolbarHeight {
            return .notHere
        }

        let windowID = (hit[kCGWindowNumber as String] as? NSNumber).map { CGWindowID($0.uint32Value) }
        let deadline = CFAbsoluteTimeGetCurrent() + resolutionBudget
        let appElement = AXUIElementCreateApplication(pid)
        guard let hitElement = element(in: appElement, at: point), let hitNode = node(for: hitElement) else {
            return cachedTitleBarZone(windowID: windowID, bounds: windowBounds, offsetFromTop: offsetFromTop, app: app)
        }

        var chain: [AXNode] = []
        var windowElement: AXUIElement?
        if hitNode.role == kAXWindowRole as String {
            windowElement = hitElement
        } else {
            chain.append(hitNode)
            windowElement = windowAttribute(of: hitElement)
            var parent = hitNode.parent
            while let element = parent, chain.count < classificationDepth, CFAbsoluteTimeGetCurrent() < deadline {
                guard let node = node(for: element) else { break }
                if node.role == kAXWindowRole as String {
                    windowElement = windowElement ?? node.element
                    break
                }
                chain.append(node)
                parent = node.parent
            }
        }

        guard CFAbsoluteTimeGetCurrent() < deadline,
              let windowElement = windowElement ?? cachedWindow(windowID, pid: pid)?.axElement
        else {
            return cachedTitleBarZone(windowID: windowID, bounds: windowBounds, offsetFromTop: offsetFromTop, app: app)
        }
        guard let windowNode = node(for: windowElement), acceptedWindowSubroles.contains(windowNode.subrole ?? "") else {
            DebugLogger.log("WindowGestures", details: "unsupported window in \(app.localizedName ?? "-") chain=\(describe(chain))")
            return .notHere
        }
        guard let target = WindowUtil.windowInfo(for: windowElement, app: app, windowID: windowID) else { return .notHere }

        let isFullscreen = (try? windowElement.isFullscreen()) == true

        if let tabIndex = chain.prefix(4).firstIndex(where: { isTab($0, in: chain) }) {
            let scrollable = chain.suffix(from: tabIndex + 1).prefix(4).contains { $0.role == kAXScrollAreaRole as String }
            return .zone(.tab(target, tab: chain[tabIndex].element, isFullscreen: isFullscreen, scrollable: scrollable))
        }

        if let role = chain.first?.role, interactiveRoles.contains(role) {
            return .notHere
        }

        let roles = chain.compactMap(\.role)
        let inToolbar = roles.contains(kAXToolbarRole as String) || roles.contains(kAXTabGroupRole as String)
        if inToolbar, !roles.contains(where: contentRoles.contains) {
            return .zone(.window(target, isFullscreen: isFullscreen))
        }
        if !isFullscreen, offsetFromTop <= titleBarHeight || (offsetFromTop <= titleBandHeight && !roles.contains(where: scrollingRoles.contains)) {
            return .zone(.window(target, isFullscreen: isFullscreen))
        }
        DebugLogger.log("WindowGestures", details: "not a title bar in \(app.localizedName ?? "-") offset=\(offsetFromTop) chain=\(describe(chain))")
        return .notHere
    }

    private static func cachedWindow(_ windowID: CGWindowID?, pid: pid_t) -> WindowInfo? {
        guard let windowID else { return nil }
        return WindowUtil.readCachedWindows(for: pid).first { $0.id == windowID && !$0.isMinimized }
    }

    private static func cachedTitleBarZone(windowID: CGWindowID?, bounds: CGRect, offsetFromTop: CGFloat, app: NSRunningApplication) -> Outcome {
        guard offsetFromTop <= titleBarHeight, let cached = cachedWindow(windowID, pid: app.processIdentifier) else {
            DebugLogger.log("WindowGestures", details: "hit test failed in \(app.localizedName ?? "-") offset=\(offsetFromTop)")
            return .notHere
        }
        let isFullscreen = NSScreen.screens.contains { $0.cgFrame == bounds }
        return .zone(.window(cached, isFullscreen: isFullscreen))
    }

    private static func describe(_ chain: [AXNode]) -> String {
        chain.map { node in [node.role, node.subrole].compactMap { $0 }.joined(separator: "/") }.joined(separator: ">")
    }

    private static func isTab(_ node: AXNode, in chain: [AXNode]) -> Bool {
        guard node.role == kAXRadioButtonRole as String else { return false }
        if node.subrole == "AXTabButton" { return true }
        guard let index = chain.firstIndex(where: { CFEqual($0.element, node.element) }), index + 1 < chain.count else { return false }
        return chain[index + 1].role == kAXTabGroupRole as String
    }

    // MARK: - Helpers

    private static func topWindow(at point: CGPoint, in windows: [[String: AnyObject]]) -> [String: AnyObject]? {
        let dockPID = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.processIdentifier
        let cursorLevel = Int(CGWindowLevelForKey(.cursorWindow))
        let screenFrames = NSScreen.screens.map(\.cgFrame)
        return windows.first { window in
            guard let pid = (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                  pid != dockPID,
                  !WindowGestureOverlays.contains((window[kCGWindowNumber as String] as? NSNumber)?.intValue ?? 0),
                  (window[kCGWindowOwnerName as String] as? String) != "Window Server",
                  ((window[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1) > 0.01,
                  let frame = bounds(of: window), frame.width > 40, frame.height > 40,
                  frame.contains(point)
            else { return false }
            let layer = (window[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0
            guard layer < cursorLevel else { return false }
            return layer == 0 || !screenFrames.contains(frame)
        }
    }

    private static var isScreenLocked: Bool {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        return (session["CGSSessionScreenIsLocked"] as? Bool) == true
    }

    private static func onScreenWindows() -> [[String: AnyObject]] {
        (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: AnyObject]]) ?? []
    }

    private static func bounds(of window: [String: AnyObject]) -> CGRect? {
        guard let dictionary = window[kCGWindowBounds as String] as? NSDictionary else { return nil }
        return CGRect(dictionaryRepresentation: dictionary)
    }

    private static func element(in container: AXUIElement, at point: CGPoint) -> AXUIElement? {
        AXUIElementSetMessagingTimeout(container, messagingTimeout)
        var element: AXUIElement?
        let start = CFAbsoluteTimeGetCurrent()
        let result = AXUIElementCopyElementAtPosition(container, Float(point.x), Float(point.y), &element)
        if result == .cannotComplete {
            noteSlowCall(container, elapsed: CFAbsoluteTimeGetCurrent() - start)
        }
        return result == .success ? element : nil
    }

    private static func windowAttribute(of element: AXUIElement) -> AXUIElement? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXWindowAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        let window = value as! AXUIElement
        AXUIElementSetMessagingTimeout(window, messagingTimeout)
        return window
    }

    private static func node(for element: AXUIElement) -> AXNode? {
        AXUIElementSetMessagingTimeout(element, messagingTimeout)
        let attributes = [kAXRoleAttribute, kAXSubroleAttribute, kAXParentAttribute] as CFArray
        var values: CFArray?
        let start = CFAbsoluteTimeGetCurrent()
        let result = AXUIElementCopyMultipleAttributeValues(element, attributes, AXCopyMultipleAttributeOptions(rawValue: 0), &values)
        guard result == .success, let array = values as? [AnyObject], array.count == 3 else {
            if result == .cannotComplete {
                noteSlowCall(element, elapsed: CFAbsoluteTimeGetCurrent() - start)
            }
            return nil
        }
        let parent: AXUIElement? = if CFGetTypeID(array[2]) == AXUIElementGetTypeID() {
            (array[2] as! AXUIElement)
        } else {
            nil
        }
        return AXNode(element: element, role: array[0] as? String, subrole: array[1] as? String, parent: parent)
    }

    private static func noteSlowCall(_ element: AXUIElement, elapsed: TimeInterval) {
        guard elapsed >= Double(messagingTimeout) * 0.9 else { return }
        var pid = pid_t(0)
        if AXUIElementGetPid(element, &pid) == .success {
            AXResponsiveness.markUnresponsive(pid)
        }
    }
}
