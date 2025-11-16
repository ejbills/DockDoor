import Cocoa

extension CGWindowID {
    func cgsTitle() -> String? {
        var value: CFTypeRef?
        let status = CGSCopyWindowProperty(CGSMainConnectionID(), UInt32(self), "kCGSWindowTitle" as CFString, &value)
        guard status == 0, let str = value as? String else { return nil }
        return str
    }

    func cgsLevel() -> Int32 {
        var lvl: Int32 = 0
        _ = CGSGetWindowLevel(CGSMainConnectionID(), UInt32(self), &lvl)
        return lvl
    }

    func cgsSpaces() -> [CGSSpaceID] {
        let arr: CFArray = [NSNumber(value: UInt32(self))] as CFArray
        guard let spaces = CGSCopySpacesForWindows(CGSMainConnectionID(), kCGSAllSpacesMask, arr) as? [NSNumber] else { return [] }
        return spaces.map(\.uint64Value)
    }
}
