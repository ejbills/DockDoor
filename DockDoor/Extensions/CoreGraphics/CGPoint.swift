import Cocoa

extension CGPoint {
    func screen() -> NSScreen? {
        // Try direct containment first
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(self) }) {
            return screen
        }

        // If that fails, try using the screen's visible frame
        if let screen = NSScreen.screens.first(where: { $0.visibleFrame.contains(self) }) {
            return screen
        }

        // If still no match, find the nearest screen by calculating distance to center
        return NSScreen.screens.min(by: { screen1, screen2 in
            let distance1 = self.distance(to: CGPoint(x: screen1.frame.midX, y: screen1.frame.midY))
            let distance2 = self.distance(to: CGPoint(x: screen2.frame.midX, y: screen2.frame.midY))
            return distance1 < distance2
        }) ?? NSScreen.main
    }

    func distance(to point: CGPoint) -> CGFloat {
        let dx = x - point.x
        let dy = y - point.y
        return sqrt(dx * dx + dy * dy)
    }

    func displace(by point: CGPoint = .init(x: 0.0, y: 0.0)) -> CGPoint {
        CGPoint(x: x + point.x,
                y: y + point.y)
    }

    /// Caps the point to the unit space
    func capped() -> CGPoint {
        CGPoint(x: max(min(x, 1), 0),
                y: max(min(y, 1), 0))
    }
}
