import Cocoa
import ApplicationServices.HIServices.AXUIElement
import ApplicationServices.HIServices.AXValue
import ApplicationServices.HIServices.AXError
import ApplicationServices.HIServices.AXRoleConstants
import ApplicationServices.HIServices.AXAttributeConstants
import ApplicationServices.HIServices.AXActionConstants

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
        return try value(kAXPositionAttribute, CGPoint.zero, .cgPoint)
    }
    
    func size() throws -> CGSize? {
        return try value(kAXSizeAttribute, CGSize.zero, .cgSize)
    }
    
    func title() throws -> String? {
        return try attribute(kAXTitleAttribute, String.self)
    }
    
    func parent() throws -> AXUIElement? {
        return try attribute(kAXParentAttribute, AXUIElement.self)
    }
    
    func children() throws -> [AXUIElement]? {
        return try attribute(kAXChildrenAttribute, [AXUIElement].self)
    }
    
    func windows() throws -> [AXUIElement]? {
        return try attribute(kAXWindowsAttribute, [AXUIElement].self)
    }
    
    func isMinimized() throws -> Bool {
        return try attribute(kAXMinimizedAttribute, Bool.self) == true
    }
    
    func isFullscreen() throws -> Bool {
        return try attribute(kAXFullscreenAttribute, Bool.self) == true
    }
    
    func focusedWindow() throws -> AXUIElement? {
        return try attribute(kAXFocusedWindowAttribute, AXUIElement.self)
    }
    
    func role() throws -> String? {
        return try attribute(kAXRoleAttribute, String.self)
    }
    
    func subrole() throws -> String? {
        return try attribute(kAXSubroleAttribute, String.self)
    }
    
    func appIsRunning() throws -> Bool? {
        return try attribute(kAXIsApplicationRunningAttribute, Bool.self)
    }
    
    func closeButton() throws -> AXUIElement? {
        return try attribute(kAXCloseButtonAttribute, AXUIElement.self)
    }
    
    func subscribeToNotification(_ axObserver: AXObserver, _ notification: String, _ callback: (() -> Void)? = nil) throws {
        let result = AXObserverAddNotification(axObserver, self, notification as CFString, nil)
        if result == .success || result == .notificationAlreadyRegistered {
            callback?()
        } else if result != .notificationUnsupported && result != .notImplemented {
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
