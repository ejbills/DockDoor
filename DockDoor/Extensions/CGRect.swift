import Cocoa

extension CGRect {
    func containsWithBuffer(_ point: CGPoint, buffer: CGFloat = 20) -> Bool {
        let screen = NSScreen.screenContainingMouse(point)
        let screenHeight = screen?.frame.height ?? 0

        // Convert the rect to screen coordinates (flipped Y)
        let windowTop = screenHeight - minY
        let windowBottom = windowTop - height

        // Find closest point on the rect
        let closestX = max(minX, min(point.x, maxX))
        let closestY = max(windowBottom, min(point.y, windowTop))

        let distance = hypot(
            point.x - closestX,
            point.y - closestY
        )
        return distance <= buffer
    }
}
