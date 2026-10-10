import AppKit
import ApplicationServices
import Defaults

extension GestureWindowTarget {
    init(window: WindowInfo) {
        self.init(element: window.axElement, app: window.app, windowID: window.id)
    }

    init(element: AXUIElement, app: NSRunningApplication) {
        let windowID = try? element.cgWindowId()
        self.init(element: element, app: app, windowID: windowID ?? nil)
    }

    var pid: pid_t { app.processIdentifier }

    var frame: CGRect? {
        WindowInfo.currentWindowFrame(for: element)
    }

    var cachedWindow: WindowInfo? {
        guard let windowID else { return nil }
        return WindowUtil.readCachedWindows(for: pid).first { $0.id == windowID }
    }

    var isMinimized: Bool {
        (try? element.isMinimized()) == true
    }

    var isFullscreen: Bool {
        (try? element.isFullscreen()) == true
    }

    func setFrame(_ frame: CGRect) {
        let primaryMaxY = NSScreen.screens.first?.frame.maxY ?? frame.maxY
        guard let position = AXValue.from(point: CGPoint(x: frame.minX, y: primaryMaxY - frame.maxY)),
              let size = AXValue.from(size: frame.size)
        else { return }

        let appElement = AXUIElementCreateApplication(pid)
        let enhancedInterface = (try? appElement.attribute("AXEnhancedUserInterface", Bool.self)) == true
        if enhancedInterface {
            try? appElement.setAttribute("AXEnhancedUserInterface", false)
        }
        try? element.setAttribute(kAXSizeAttribute, size)
        try? element.setAttribute(kAXPositionAttribute, position)
        try? element.setAttribute(kAXSizeAttribute, size)
        if enhancedInterface {
            try? appElement.setAttribute("AXEnhancedUserInterface", true)
        }
    }

    func focus() {
        if app.isHidden {
            app.unhide()
        }
        if let cachedWindow {
            cachedWindow.bringToFront()
            return
        }
        WindowInfo.windowlessEntry(for: app).bringToFront()
        try? element.performAction(kAXRaiseAction)
        try? element.setAttribute(kAXMainAttribute, true)
    }

    func minimize() {
        try? element.setAttribute(kAXMinimizedAttribute, true)
        if let cachedWindow {
            WindowUtil.updateCachedWindowState(cachedWindow, isMinimized: true)
        }
    }

    func restore() {
        if app.isHidden {
            app.unhide()
        }
        let result = AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        if result != .success {
            DebugLogger.log("WindowGestures", details: "unminimize failed for window \(windowID.map(String.init) ?? "-"): AXError \(result.rawValue)")
        }
        if let cachedWindow {
            WindowUtil.updateCachedWindowState(cachedWindow, isMinimized: false)
        }
        focus()
    }

    func close() {
        if let cachedWindow, cachedWindow.closeButton != nil {
            cachedWindow.close()
            return
        }
        guard let closeButton = try? element.closeButton() else { return }
        try? closeButton.performAction(kAXPressAction)
        if let windowID {
            WindowUtil.removeWindowFromDesktopSpaceCache(with: windowID, in: pid)
        }
    }

    func setFullScreen(_ fullScreen: Bool) {
        try? element.setAttribute(kAXFullscreenAttribute, fullScreen)
    }
}

enum WindowGestureScreens {
    static func screen(containing frame: CGRect) -> NSScreen? {
        let screens = NSScreen.screens
        let best = screens.max { overlap($0.frame, frame) < overlap($1.frame, frame) }
        if let best, overlap(best.frame, frame) > 0 {
            return best
        }
        return screens.first { $0.frame.contains(CGPoint(x: frame.midX, y: frame.midY)) } ?? NSScreen.main
    }

    static func screen(atQuartzPoint point: CGPoint) -> NSScreen? {
        NSScreen.screens.isEmpty ? nil : NSScreen.screenFromQuartzPoint(point)
    }

    static func geometry(for screen: NSScreen) -> SnapScreenGeometry {
        SnapScreenGeometry(
            visibleFrame: usableFrame(for: screen),
            spacing: Defaults[.windowGestureGridSpacing],
            includeEdges: Defaults[.windowGestureSpacingIncludesEdges]
        )
    }

    static func usableFrame(for screen: NSScreen) -> CGRect {
        let offset = isStageManagerEnabled ? Defaults[.windowGestureStageManagerOffset] : 0
        return SnapScreenGeometry.usableFrame(
            visibleFrame: screen.visibleFrame,
            stageManagerOffset: offset,
            stageManagerOnLeft: DockUtils.getDockPosition() != .left
        )
    }

    static var isStageManagerEnabled: Bool {
        UserDefaults(suiteName: "com.apple.WindowManager")?.bool(forKey: "GloballyEnabled") == true
    }

    static func screen(from source: NSScreen, toward direction: GestureDirection) -> NSScreen? {
        let others = NSScreen.screens.filter { $0 != source }
        guard let index = neighborIndex(of: others.map(\.frame), from: source.frame, toward: direction) else { return nil }
        return others[index]
    }

    static func otherScreen(than source: NSScreen) -> NSScreen? {
        let screens = NSScreen.screens
        guard screens.count > 1, let index = screens.firstIndex(of: source) else { return nil }
        return screens[(index + 1) % screens.count]
    }

    static func neighborIndex(of candidates: [CGRect], from source: CGRect, toward direction: GestureDirection) -> Int? {
        let origin = CGPoint(x: source.midX, y: source.midY)
        let scored = candidates.enumerated().compactMap { index, rect -> (index: Int, distance: CGFloat)? in
            let dx = rect.midX - origin.x
            let dy = rect.midY - origin.y
            let (along, across): (CGFloat, CGFloat) = switch direction {
            case .right: (dx, dy)
            case .left: (-dx, dy)
            case .up: (dy, dx)
            case .down: (-dy, dx)
            }
            guard along > 0, abs(across) <= along * 2 else { return nil }
            return (index, hypot(dx, dy))
        }
        return scored.min { $0.distance < $1.distance }?.index
    }

    static func map(_ frame: CGRect, from source: CGRect, to destination: CGRect) -> CGRect {
        let width = min(frame.width, destination.width)
        let height = min(frame.height, destination.height)
        let relativeX = source.width > frame.width ? (frame.minX - source.minX) / (source.width - frame.width) : 0.5
        let relativeY = source.height > frame.height ? (frame.minY - source.minY) / (source.height - frame.height) : 0.5
        let x = destination.minX + (destination.width - width) * min(max(relativeX, 0), 1)
        let y = destination.minY + (destination.height - height) * min(max(relativeY, 0), 1)
        return CGRect(x: x.rounded(), y: y.rounded(), width: width.rounded(), height: height.rounded())
    }

    static func centered(_ size: CGSize, in frame: CGRect) -> CGRect {
        let width = min(size.width, frame.width)
        let height = min(size.height, frame.height)
        return CGRect(
            x: (frame.midX - width / 2).rounded(),
            y: (frame.midY - height / 2).rounded(),
            width: width.rounded(),
            height: height.rounded()
        )
    }

    private static func overlap(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        return intersection.isNull ? 0 : intersection.width * intersection.height
    }
}

final class WindowSnapRegistry: @unchecked Sendable {
    struct Record {
        let windowID: CGWindowID
        let target: GestureWindowTarget
        var region: SnapRegion
        var snappedFrame: CGRect
        var restoreFrame: CGRect
        var screenIdentifier: String
    }

    static let shared = WindowSnapRegistry()
    private static let tolerance: CGFloat = 6

    private let lock = NSLock()
    private var records: [CGWindowID: Record] = [:]

    var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return records.isEmpty
    }

    func allRecords() -> [Record] {
        lock.lock()
        defer { lock.unlock() }
        return Array(records.values)
    }

    func record(for windowID: CGWindowID?) -> Record? {
        guard let windowID else { return nil }
        lock.lock()
        defer { lock.unlock() }
        return records[windowID]
    }

    func set(_ record: Record) {
        lock.lock()
        records[record.windowID] = record
        lock.unlock()
    }

    @discardableResult
    func remove(_ windowID: CGWindowID?) -> Record? {
        guard let windowID else { return nil }
        lock.lock()
        defer { lock.unlock() }
        return records.removeValue(forKey: windowID)
    }

    func liveRecord(for windowID: CGWindowID?) -> Record? {
        guard let record = record(for: windowID) else { return nil }
        guard let frame = record.target.frame, Self.matches(frame, record.snappedFrame) else {
            remove(windowID)
            return nil
        }
        return record
    }

    func liveRecords(screenIdentifier: String?) -> [Record] {
        lock.lock()
        let snapshot = Array(records.values)
        lock.unlock()

        return snapshot.filter { record in
            guard screenIdentifier == nil || record.screenIdentifier == screenIdentifier else { return false }
            return liveRecord(for: record.windowID) != nil
        }
    }

    static func matches(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        abs(lhs.minX - rhs.minX) <= tolerance && abs(lhs.minY - rhs.minY) <= tolerance
            && abs(lhs.width - rhs.width) <= tolerance && abs(lhs.height - rhs.height) <= tolerance
    }
}

final class WindowMinimizeHistory: @unchecked Sendable {
    struct Entry {
        let target: GestureWindowTarget
        let screenIdentifier: String?
    }

    static let shared = WindowMinimizeHistory()
    private static let capacity = 64

    private let lock = NSLock()
    private var entries: [Entry] = []

    func push(_ newEntries: [Entry]) {
        guard !newEntries.isEmpty else { return }
        lock.lock()
        let newIDs = Set(newEntries.compactMap(\.target.windowID))
        entries.removeAll { entry in entry.target.windowID.map(newIDs.contains) ?? false }
        entries.append(contentsOf: newEntries)
        if entries.count > Self.capacity {
            entries.removeFirst(entries.count - Self.capacity)
        }
        lock.unlock()
    }

    func popLatest(pid: pid_t) -> GestureWindowTarget? {
        lock.lock()
        defer { lock.unlock() }
        while let index = entries.lastIndex(where: { $0.target.pid == pid }) {
            let entry = entries.remove(at: index)
            if entry.target.isMinimized {
                return entry.target
            }
        }
        return nil
    }

    func take(pid: pid_t? = nil, screenIdentifier: String? = nil) -> [GestureWindowTarget] {
        lock.lock()
        defer { lock.unlock() }
        let matching = entries.filter { entry in
            (pid == nil || entry.target.pid == pid) && (screenIdentifier == nil || entry.screenIdentifier == screenIdentifier)
        }
        let matchingIDs = Set(matching.compactMap(\.target.windowID))
        entries.removeAll { entry in entry.target.windowID.map(matchingIDs.contains) ?? false }
        return matching.map(\.target).filter(\.isMinimized)
    }
}
