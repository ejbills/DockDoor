import ApplicationServices.HIServices.AXActionConstants
import ApplicationServices.HIServices.AXAttributeConstants
import ApplicationServices.HIServices.AXError
import ApplicationServices.HIServices.AXRoleConstants
import ApplicationServices.HIServices.AXUIElement
import ApplicationServices.HIServices.AXValue
import Cocoa

// NOTE: Borrows code from https://github.com/lwouis/alt-tab-macos/blob/master/src/api-wrappers/AXUIElement.swift

enum AXResponsiveness {
    private static let lock = NSLock()
    private static var unresponsiveUntil: [pid_t: Date] = [:]
    static let backoff: TimeInterval = 5

    static func markUnresponsive(_ pid: pid_t) {
        guard pid > 0, pid != ProcessInfo.processInfo.processIdentifier else { return }
        lock.lock()
        unresponsiveUntil[pid] = Date().addingTimeInterval(backoff)
        lock.unlock()
        DebugLogger.log("AXResponsiveness", details: "PID \(pid) unresponsive, backing off \(Int(backoff))s")
    }

    static func isUnresponsive(_ pid: pid_t) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let until = unresponsiveUntil[pid] else { return false }
        if until > Date() { return true }
        unresponsiveUntil.removeValue(forKey: pid)
        return false
    }
}

extension AXUIElement {
    func axCallWhichCanThrow<T>(_ result: AXError, _ successValue: inout T) throws -> T? {
        switch result {
        case .success: return successValue
        // .cannotComplete can happen if the app is unresponsive; we throw in that case to retry until the call succeeds
        case .cannotComplete:
            var pid = pid_t(0)
            if AXUIElementGetPid(self, &pid) == .success {
                AXResponsiveness.markUnresponsive(pid)
            }
            throw AxError.runtimeError
        // for other errors it's pointless to retry
        default: return nil
        }
    }

    func cgWindowId() throws -> CGWindowID? {
        var id = CGWindowID(0)
        return try axCallWhichCanThrow(_AXUIElementGetWindow(self, &id), &id)
    }

    func pid() throws -> pid_t? {
        var pid = pid_t(0)
        return try axCallWhichCanThrow(AXUIElementGetPid(self, &pid), &pid)
    }

    func attribute<T>(_ key: String, _ _: T.Type) throws -> T? {
        var value: AnyObject?
        let result: AXError = if needsMainThreadAXAccess {
            DispatchQueue.main.sync {
                AXUIElementCopyAttributeValue(self, key as CFString, &value)
            }
        } else {
            AXUIElementCopyAttributeValue(self, key as CFString, &value)
        }
        return try axCallWhichCanThrow(result, &value) as? T
    }

    private var needsMainThreadAXAccess: Bool {
        guard !Thread.isMainThread else { return false }

        var pid = pid_t(0)
        guard AXUIElementGetPid(self, &pid) == .success else { return false }
        return pid == ProcessInfo.processInfo.processIdentifier
    }

    private func value<T>(_ key: String, _ target: T, _ type: AXValueType) throws -> T? {
        if let a = try attribute(key, AXValue.self) {
            var value = target
            let success = withUnsafeMutablePointer(to: &value) { ptr in
                AXValueGetValue(a, type, ptr)
            }
            return success ? value : nil
        }
        return nil
    }

    func position() throws -> CGPoint? {
        try value(kAXPositionAttribute, CGPoint.zero, .cgPoint)
    }

    func size() throws -> CGSize? {
        try value(kAXSizeAttribute, CGSize.zero, .cgSize)
    }

    func title() throws -> String? {
        try attribute(kAXTitleAttribute, String.self)
    }

    func parent() throws -> AXUIElement? {
        try attribute(kAXParentAttribute, AXUIElement.self)
    }

    func children() throws -> [AXUIElement]? {
        try attribute(kAXChildrenAttribute, [AXUIElement].self)
    }

    func windows() throws -> [AXUIElement]? {
        try attribute(kAXWindowsAttribute, [AXUIElement].self)
    }

    static func windowsByBruteForce(_ pid: pid_t, app: NSRunningApplication? = nil) -> [AXUIElement] {
        DebugLogger.measureSlow("windowsByBruteForce", thresholdMs: 100, details: "PID: \(pid)") {
            var token = Data(count: 20)
            token.replaceSubrange(0 ..< 4, with: withUnsafeBytes(of: pid) { Data($0) })
            token.replaceSubrange(4 ..< 8, with: withUnsafeBytes(of: Int32(0)) { Data($0) })
            token.replaceSubrange(8 ..< 12, with: withUnsafeBytes(of: Int32(0x636F_636F)) { Data($0) })

            var results: [AXUIElement] = []
            var consecutiveTimeouts = 0
            for axId: AXUIElementID in 0 ..< 1000 {
                if AXResponsiveness.isUnresponsive(pid) { break }
                token.replaceSubrange(12 ..< 20, with: withUnsafeBytes(of: axId) { Data($0) })
                guard let el = _AXUIElementCreateWithRemoteToken(token as CFData)?.takeRetainedValue() else {
                    continue
                }

                let role: String?
                do {
                    role = try el.role()
                    consecutiveTimeouts = 0
                } catch {
                    consecutiveTimeouts += 1
                    if consecutiveTimeouts >= 2 { break }
                    continue
                }
                guard role == kAXWindowRole as String else { continue }

                if let app {
                    let windowID = (try? el.cgWindowId()) ?? 0
                    let attributes = WindowCandidateAttributes(axWindow: el)
                    if WindowCandidateDiscriminator.isPotentialAXWindow(
                        app: app,
                        level: windowID == 0 ? nil : windowID.cgsLevel(),
                        attributes: attributes
                    ) {
                        results.append(el)
                    }
                } else if let subrole = try? el.subrole(),
                          [kAXStandardWindowSubrole, kAXDialogSubrole].contains(subrole)
                {
                    results.append(el)
                }
            }
            return results
        }
    }

    static func allWindows(_ pid: pid_t, appElement: AXUIElement, app: NSRunningApplication? = nil, cgCandidates: [[String: AnyObject]]? = nil) -> [AXUIElement] {
        guard !AXResponsiveness.isUnresponsive(pid) else { return [] }

        return DebugLogger.measureSlow("allWindows", thresholdMs: 200, details: "PID: \(pid)") {
            var set = Set<AXUIElement>()

            let windows: [AXUIElement]?
            do {
                windows = try DebugLogger.measureSlow("appElement.windows()", thresholdMs: 50, details: "PID: \(pid)") {
                    try appElement.windows()
                }
            } catch {
                return []
            }
            if let windows { set.formUnion(windows) }

            // Brute force exists to reach windows the AX list omits (typically other Spaces); invisible helper windows on the current Space never justify it.
            let candidates = cgCandidates ?? getCGWindowCandidates(for: pid)
            let knownIDs = Set(set.compactMap { try? $0.cgWindowId() })
            let activeSpaces = currentActiveSpaceIDs()
            let hasUnreachedWindow = candidates.contains { desc in
                let windowID = CGWindowID((desc[kCGWindowNumber as String] as? NSNumber)?.uint32Value ?? 0)
                guard (desc[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                      !knownIDs.contains(windowID),
                      isValidCGWindowCandidate(windowID, in: candidates)
                else { return false }
                let isOnscreen = (desc[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue ?? false
                let spaces = Set(windowID.cgsSpaces().map { Int($0) })
                return isOnscreen || spaces.isEmpty || spaces.isDisjoint(with: activeSpaces)
            }
            if hasUnreachedWindow {
                set.formUnion(windowsByBruteForce(pid, app: app))
            }

            return Array(set)
        }
    }

    func isMinimized() throws -> Bool {
        let result = try attribute(kAXMinimizedAttribute, Bool.self) == true
        return result
    }

    func isFullscreen() throws -> Bool {
        try attribute(kAXFullscreenAttribute, Bool.self) == true
    }

    func focusedWindow() throws -> AXUIElement? {
        try attribute(kAXFocusedWindowAttribute, AXUIElement.self)
    }

    func role() throws -> String? {
        try attribute(kAXRoleAttribute, String.self)
    }

    func subrole() throws -> String? {
        try attribute(kAXSubroleAttribute, String.self)
    }

    func appIsRunning() throws -> Bool? {
        try attribute(kAXIsApplicationRunningAttribute, Bool.self)
    }

    func closeButton() throws -> AXUIElement? {
        try attribute(kAXCloseButtonAttribute, AXUIElement.self)
    }

    func minimizeButton() throws -> AXUIElement? {
        try attribute(kAXMinimizeButtonAttribute, AXUIElement.self)
    }

    func zoomButton() throws -> AXUIElement? {
        try attribute(kAXZoomButtonAttribute, AXUIElement.self)
    }

    func fullscreenButton() throws -> AXUIElement? {
        try attribute(kAXFullscreenAttribute, AXUIElement.self)
    }

    func subscribeToNotification(_ axObserver: AXObserver, _ notification: String, _ callback: (() -> Void)? = nil) throws {
        let result = AXObserverAddNotification(axObserver, self, notification as CFString, nil)
        if result == .success || result == .notificationAlreadyRegistered {
            callback?()
        } else if result != .notificationUnsupported, result != .notImplemented {
            throw AxError.runtimeError
        }
    }

    func setAttribute(_ key: String, _ value: Any) throws {
        var unused: Void = ()
        let result: AXError = if needsMainThreadAXAccess {
            DispatchQueue.main.sync {
                AXUIElementSetAttributeValue(self, key as CFString, value as CFTypeRef)
            }
        } else {
            AXUIElementSetAttributeValue(self, key as CFString, value as CFTypeRef)
        }
        try axCallWhichCanThrow(result, &unused)
    }

    func performAction(_ action: String) throws {
        var unused: Void = ()
        let result: AXError = if needsMainThreadAXAccess {
            DispatchQueue.main.sync {
                AXUIElementPerformAction(self, action as CFString)
            }
        } else {
            AXUIElementPerformAction(self, action as CFString)
        }
        try axCallWhichCanThrow(result, &unused)
    }
}

enum AxError: Error {
    case runtimeError
}

typealias AXUIElementID = UInt64

// MARK: - AX Readiness Probe

/// Probes Finder's AX tree to detect post-wake AX subsystem degradation.
func isAccessibilityReady() -> Bool {
    guard let finder = NSWorkspace.shared.runningApplications
        .first(where: { $0.bundleIdentifier == "com.apple.finder" })
    else {
        return false
    }

    let app = AXUIElementCreateApplication(finder.processIdentifier)
    AXUIElementSetMessagingTimeout(app, 1.0)

    guard let role = try? app.role(), role == kAXApplicationRole as String else {
        return false
    }

    guard let windows = try? app.windows(), !windows.isEmpty else {
        return false
    }

    // Reject partial-init state where app element is returned as its own child
    return windows.contains { element in
        guard let childRole = try? element.role() else { return false }
        return childRole == kAXWindowRole as String
    }
}
