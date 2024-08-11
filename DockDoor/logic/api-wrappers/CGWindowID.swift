import Cocoa

extension CGWindowID {
    func title() -> String? {
        cgProperty("kCGSWindowTitle", String.self)
    }

    func level() throws -> CGWindowLevel {
        var level = CGWindowLevel(0)
        CGSGetWindowLevel(cgsMainConnectionId, self, &level)
        return level
    }

    func spaces() -> [CGSSpaceID] {
        return CGSCopySpacesForWindows(cgsMainConnectionId, CGSSpaceMask.all.rawValue, [self] as CFArray) as! [CGSSpaceID]
    }

    func screenshot(bestResolution: Bool = false) -> CGImage? {
        // CGSHWCaptureWindowList
        var windowId_ = self
        let list = CGSHWCaptureWindowList(cgsMainConnectionId, &windowId_, 1, [.ignoreGlobalClipShape, bestResolution ? .bestResolution : .nominalResolution]).takeRetainedValue() as! [CGImage]
        return list.first
    }

    private func cgProperty<T>(_ key: String, _: T.Type) -> T? {
        var value: AnyObject?
        CGSCopyWindowProperty(cgsMainConnectionId, self, key as CFString, &value)
        return value as? T
    }
}
