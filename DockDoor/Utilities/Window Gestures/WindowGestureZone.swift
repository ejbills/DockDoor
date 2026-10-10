import AppKit
import ApplicationServices

struct GestureWindowTarget {
    let element: AXUIElement
    let app: NSRunningApplication
    let windowID: CGWindowID?
}

enum WindowGestureZone {
    case window(GestureWindowTarget, isFullscreen: Bool)
    case tab(GestureWindowTarget, tab: AXUIElement, isFullscreen: Bool, scrollable: Bool)
    case app(NSRunningApplication)
    case menuBar(screenFrame: CGRect)

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

    var window: GestureWindowTarget? {
        switch self {
        case let .window(target, _), let .tab(target, _, _, _): target
        case .app, .menuBar: nil
        }
    }

    var app: NSRunningApplication? {
        switch self {
        case let .window(target, _), let .tab(target, _, _, _): target.app
        case let .app(app): app
        case .menuBar: nil
        }
    }
}

enum WindowGestureZoneResolver {
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

    static func resolve(at point: CGPoint, anywhere: Bool, isIgnored: (NSRunningApplication) -> Bool) -> WindowGestureZone? {
        guard !isScreenLocked else { return nil }
        let screen = NSScreen.screenFromQuartzPoint(point)
        let windows = onScreenWindows()

        switch menuBarZone(at: point, screen: screen, windows: windows, isIgnored: isIgnored) {
        case let .zone(zone): return zone
        case .blocked: return nil
        case .notHere: break
        }

        switch dockZone(at: point, screen: screen, isIgnored: isIgnored) {
        case let .zone(zone): return zone
        case .blocked: return nil
        case .notHere: break
        }

        if case let .zone(zone) = windowZone(at: point, windows: windows, anywhere: anywhere, isIgnored: isIgnored) {
            return zone
        }
        return nil
    }

    // MARK: - Menu Bar

    private static func menuBarZone(at point: CGPoint, screen: NSScreen, windows: [[String: AnyObject]], isIgnored: (NSRunningApplication) -> Bool) -> Outcome {
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
            return .zone(.menuBar(screenFrame: screen.frame))
        }

        let appElement = AXUIElementCreateApplication(frontmost.processIdentifier)
        guard let hit = element(in: appElement, at: point),
              let node = node(for: hit),
              node.role == kAXMenuBarItemRole as String
        else {
            return .zone(.menuBar(screenFrame: screen.frame))
        }

        guard let menuBar = node.parent,
              let items = try? menuBar.children(),
              items.count > 1, CFEqual(items[1], hit),
              !isIgnored(frontmost)
        else {
            return .blocked
        }
        return .zone(.app(frontmost))
    }

    // MARK: - Dock

    private static func dockZone(at point: CGPoint, screen: NSScreen, isIgnored: (NSRunningApplication) -> Bool) -> Outcome {
        guard isWithinDockBand(point, screen: screen), let dockObserver = DockObserver.activeInstance else { return .notHere }
        let hovered = dockObserver.getDockItemAppStatusUnderMouse()
        guard hovered.dockItemElement != nil else { return .notHere }
        guard case let .success(app) = hovered.status,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              !isIgnored(app)
        else {
            return .blocked
        }
        return .zone(.app(app))
    }

    private static func isWithinDockBand(_ point: CGPoint, screen: NSScreen) -> Bool {
        let frame = screen.cgFrame
        let thickness = dockBandThickness(on: screen)
        switch DockUtils.getDockPosition() {
        case .bottom: return frame.maxY - point.y <= thickness
        case .left: return point.x - frame.minX <= thickness
        case .right: return frame.maxX - point.x <= thickness
        case .top: return point.y - frame.minY <= thickness
        case .cmdTab, .cli, .unknown: return false
        }
    }

    private static func dockBandThickness(on screen: NSScreen) -> CGFloat {
        let reserved = DockUtils.getDockSize(on: screen)
        if reserved > 0 {
            return reserved + 8
        }
        let preferences = UserDefaults(suiteName: "com.apple.dock")
        let tileSize = preferences?.double(forKey: "tilesize") ?? 0
        let largeSize = preferences?.bool(forKey: "magnification") == true ? (preferences?.double(forKey: "largesize") ?? 0) : 0
        return max(tileSize > 0 ? tileSize : 64, largeSize) + 24
    }

    // MARK: - Windows

    private static func windowZone(at point: CGPoint, windows: [[String: AnyObject]], anywhere: Bool, isIgnored: (NSRunningApplication) -> Bool) -> Outcome {
        guard let hit = topWindow(at: point, in: windows) else {
            return .notHere
        }

        guard let pid = (hit[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
              pid != ProcessInfo.processInfo.processIdentifier,
              (hit[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
              let windowBounds = bounds(of: hit),
              let app = NSRunningApplication(processIdentifier: pid),
              app.activationPolicy != .prohibited,
              !isIgnored(app)
        else {
            return .blocked
        }

        let offsetFromTop = point.y - windowBounds.minY
        if !anywhere, offsetFromTop > maximumToolbarHeight {
            return .notHere
        }

        let deadline = CFAbsoluteTimeGetCurrent() + resolutionBudget
        let appElement = AXUIElementCreateApplication(pid)
        guard let hitElement = element(in: appElement, at: point), let hitNode = node(for: hitElement) else { return .notHere }

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
              let windowElement,
              let windowNode = node(for: windowElement),
              acceptedWindowSubroles.contains(windowNode.subrole ?? "")
        else { return .notHere }

        let windowID = (hit[kCGWindowNumber as String] as? NSNumber).map { CGWindowID($0.uint32Value) }
        let target = GestureWindowTarget(element: windowElement, app: app, windowID: windowID)
        let isFullscreen = (try? windowElement.isFullscreen()) == true

        if anywhere {
            return .zone(.window(target, isFullscreen: isFullscreen))
        }

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
        if offsetFromTop <= titleBandHeight, !isFullscreen, !roles.contains(where: scrollingRoles.contains) {
            return .zone(.window(target, isFullscreen: isFullscreen))
        }
        return .notHere
    }

    private static func isTab(_ node: AXNode, in chain: [AXNode]) -> Bool {
        guard node.role == kAXRadioButtonRole as String else { return false }
        if node.subrole == "AXTabButton" { return true }
        guard let index = chain.firstIndex(where: { CFEqual($0.element, node.element) }), index + 1 < chain.count else { return false }
        return chain[index + 1].role == kAXTabGroupRole as String
    }

    // MARK: - Helpers

    static func topWindow(at point: CGPoint, in windows: [[String: AnyObject]], tolerance: CGFloat = 0) -> [String: AnyObject]? {
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
                  frame.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
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

    static func onScreenWindows() -> [[String: AnyObject]] {
        (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: AnyObject]]) ?? []
    }

    static func bounds(of window: [String: AnyObject]) -> CGRect? {
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
