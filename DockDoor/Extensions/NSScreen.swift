import Cocoa

extension NSScreen {
    static func screenContainingMouse(_ point: CGPoint) -> NSScreen {
        let screens = NSScreen.screens
        let pointInScreenCoordinates = CGPoint(x: point.x, y: NSScreen.screens.first!.frame.maxY - point.y)

        return screens.first { screen in
            NSPointInRect(pointInScreenCoordinates, screen.frame)
        } ?? NSScreen.main!
    }

    func convertPoint(fromGlobal point: CGPoint) -> CGPoint {
        let primaryScreen = NSScreen.screens.first!
        let baseCoordinate = primaryScreen.frame.maxY
        let flippedPoint = CGPoint(x: point.x, y: baseCoordinate - point.y)
        return CGPoint(x: flippedPoint.x - frame.minX, y: flippedPoint.y - frame.minY)
    }
}

extension NSScreen {
    // Generate a unique identifier string for a screen
    func uniqueIdentifier() -> String {
        // Combine multiple properties to create a reliable hash
        let components = [
            deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber as Any,
            frame.width,
            frame.height,
            deviceDescription[NSDeviceDescriptionKey("NSDeviceBitsPerSample")] as? NSNumber as Any,
            deviceDescription[NSDeviceDescriptionKey("NSDeviceColorSpaceName")] as? String as Any,
        ].compactMap { String(describing: $0) }

        return components.joined(separator: "-")
    }

    // Look up a screen using a saved identifier
    static func findScreen(byIdentifier identifier: String) -> NSScreen? {
        NSScreen.screens.first { screen in
            screen.uniqueIdentifier() == identifier
        }
    }
}
