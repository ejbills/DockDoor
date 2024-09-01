import Cocoa

extension NSScreen {
    static func screenContainingMouse(_ point: CGPoint) -> NSScreen? {
        let screens = NSScreen.screens
        let pointInScreenCoordinates = CGPoint(x: point.x, y: NSScreen.screens.first!.frame.maxY - point.y)

        return screens.first { screen in
            NSPointInRect(pointInScreenCoordinates, screen.frame)
        } ?? NSScreen.main
    }

    func convertPoint(fromGlobal point: CGPoint) -> CGPoint {
        let primaryScreen = NSScreen.screens.first!
        let baseCoordinate = primaryScreen.frame.maxY
        let flippedPoint = CGPoint(x: point.x, y: baseCoordinate - point.y)
        return CGPoint(x: flippedPoint.x - frame.minX, y: flippedPoint.y - frame.minY)
    }
}
