import ApplicationServices.HIServices.AXActionConstants
import ApplicationServices.HIServices.AXAttributeConstants
import ApplicationServices.HIServices.AXError
import ApplicationServices.HIServices.AXRoleConstants
import ApplicationServices.HIServices.AXUIElement
import ApplicationServices.HIServices.AXValue
import Cocoa

extension AXUIElement {
    func axCallWhichCanThrow<T>(_ result: AXError, _ successValue: inout T) throws -> T? {
        switch result {
        case .success: return successValue
        // .cannotComplete can happen if the app is unresponsive; we throw in that case to retry until the call succeeds
        case .cannotComplete: throw AxError.runtimeError
        // for other errors it's pointless to retry
        default: return nil
        }
    }

    #if !APPSTORE_BUILD
        func cgWindowId() throws -> CGWindowID? {
            var id = CGWindowID(0)
            return try axCallWhichCanThrow(_AXUIElementGetWindow(self, &id), &id)
        }
    #else
        func cgWindowId() -> CGWindowID? {
            // First, try to get the window ID using position and size
            if let windowId = getCGWindowIdByFrame() {
                return windowId
            }

            // If that fails (possibly due to minimization), try to match based on other properties
            return getCGWindowIdByProperties()
        }

        private func getCGWindowIdByFrame() -> CGWindowID? {
            guard let pid = try? pid(),
                  let position = try? position(),
                  let size = try? size()
            else {
                return nil
            }

            let frame = CGRect(origin: position, size: size)
            let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []

            return windowList.first { windowInfo in
                guard let windowPid = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
                      windowPid == pid,
                      let windowBounds = windowInfo[kCGWindowBounds as String] as? [String: CGFloat]
                else {
                    return false
                }

                let windowFrame = CGRect(x: windowBounds["X"] ?? 0,
                                         y: windowBounds["Y"] ?? 0,
                                         width: windowBounds["Width"] ?? 0,
                                         height: windowBounds["Height"] ?? 0)

                return windowFrame == frame
            }?[kCGWindowNumber as String] as? CGWindowID
        }

        private func getCGWindowIdByProperties() -> CGWindowID? {
            guard let pid = try? pid(),
                  let title = try? title()
            else {
                return nil
            }

            let windowList = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []

            return windowList.first { windowInfo in
                let windowPid = windowInfo[kCGWindowOwnerPID as String] as? pid_t
                let windowTitle = windowInfo[kCGWindowName as String] as? String
                return windowPid == pid && windowTitle == title
            }?[kCGWindowNumber as String] as? CGWindowID
        }
    #endif
    func pid() throws -> pid_t? {
        var pid = pid_t(0)
        return try axCallWhichCanThrow(AXUIElementGetPid(self, &pid), &pid)
    }

    func attribute<T>(_ key: String, _ _: T.Type) throws -> T? {
        var value: AnyObject?
        return try axCallWhichCanThrow(AXUIElementCopyAttributeValue(self, key as CFString, &value), &value) as? T
    }

    private func value<T>(_ key: String, _ target: T, _ type: AXValueType) throws -> T? {
        if let a = try attribute(key, AXValue.self) {
            var value = target
            AXValueGetValue(a, type, &value)
            return value
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

    func isMinimized() throws -> Bool {
        try attribute(kAXMinimizedAttribute, Bool.self) == true
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
        try axCallWhichCanThrow(AXUIElementSetAttributeValue(self, key as CFString, value as CFTypeRef), &unused)
    }

    func performAction(_ action: String) throws {
        var unused: Void = ()
        try axCallWhichCanThrow(AXUIElementPerformAction(self, action as CFString), &unused)
    }
}

enum AxError: Error {
    case runtimeError
}
