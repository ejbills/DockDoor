import Cocoa
import Defaults

extension NSScreen {
    static func screenFromQuartzPoint(_ point: CGPoint) -> NSScreen {
        let pointInScreenCoordinates = CGPoint(x: point.x, y: NSScreen.screens.first!.frame.maxY - point.y)

        // NSMouseInRect(_, _, false) is inclusive at a frame's top edge, so a window
        // flush with the top of a screen still matches; NSPointInRect would exclude it.
        return NSScreen.screens.first { NSMouseInRect(pointInScreenCoordinates, $0.frame, false) }
            ?? pointInScreenCoordinates.screen()
            ?? NSScreen.main!
    }

    func convertPoint(fromGlobal point: CGPoint) -> CGPoint {
        let primaryScreen = NSScreen.screens.first!
        let baseCoordinate = primaryScreen.frame.maxY
        let flippedPoint = CGPoint(x: point.x, y: baseCoordinate - point.y)
        return CGPoint(x: flippedPoint.x - frame.minX, y: flippedPoint.y - frame.minY)
    }

    /// Returns the screen frame in CG global coordinate space (origin top-left, Y increases downward).
    var cgFrame: CGRect {
        guard let primaryHeight = NSScreen.screens.first?.frame.height else { return frame }
        return CGRect(x: frame.minX, y: primaryHeight - frame.maxY, width: frame.width, height: frame.height)
    }
}

extension NSScreen {
    static let systemMainDisplayIdentifier = "system-main-display"

    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }

    static var systemMain: NSScreen? {
        screens.first
    }

    /// A user-facing display name including resolution and "(Main)" suffix if applicable.
    var displayName: String {
        let isMain = self == NSScreen.systemMain
        var name = localizedName
        if name.isEmpty {
            if let displayID {
                name = String(format: NSLocalizedString("Display %u", comment: "Generic display name with CGDirectDisplayID"), displayID)
            } else {
                name = String(localized: "Unknown Display")
            }
        }
        return name + (isMain ? " (Main)" : "")
    }

    /// Persistent identifier backed by the display's hardware UUID; CGDirectDisplayID is reassigned across reboots.
    func uniqueIdentifier() -> String {
        if let displayID, let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue() {
            return CFUUIDCreateString(nil, uuid) as String
        }
        return legacyIdentifier()
    }

    func legacyIdentifier() -> String {
        let components = [
            deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber as Any,
            frame.width,
            frame.height,
            deviceDescription[NSDeviceDescriptionKey("NSDeviceBitsPerSample")] as? NSNumber as Any,
            deviceDescription[NSDeviceDescriptionKey("NSDeviceColorSpaceName")] as? String as Any,
        ].compactMap { String(describing: $0) }

        return components.joined(separator: "-")
    }

    static func findScreen(byIdentifier identifier: String) -> NSScreen? {
        guard !identifier.isEmpty else { return nil }
        if identifier == systemMainDisplayIdentifier { return systemMain }
        return screens.first { $0.uniqueIdentifier() == identifier }
            ?? screens.first { $0.legacyIdentifier() == identifier }
    }

    static func migrateScreenIdentifier(_ key: Defaults.Key<String>) {
        let stored = Defaults[key]
        guard !stored.isEmpty, stored != systemMainDisplayIdentifier,
              !screens.contains(where: { $0.uniqueIdentifier() == stored }),
              let screen = screens.first(where: { $0.legacyIdentifier() == stored })
        else { return }
        Defaults[key] = screen.uniqueIdentifier()
    }
}
