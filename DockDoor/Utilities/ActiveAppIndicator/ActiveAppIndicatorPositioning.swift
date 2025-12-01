import Cocoa
import Defaults

/// Handles positioning calculations for the active app indicator across different dock positions.
/// Supports bottom, left, and right dock orientations.
enum ActiveAppIndicatorPositioning {
    /// Supported dock positions for the indicator
    static let supportedPositions: Set<DockPosition> = [.bottom, .left, .right]

    /// Checks if the given dock position is supported
    static func isSupported(_ position: DockPosition) -> Bool {
        supportedPositions.contains(position)
    }

    /// Calculates the indicator frame for the given dock item frame and dock position.
    /// Returns nil if the dock position is not supported.
    static func calculateIndicatorFrame(
        for dockItemFrame: CGRect,
        dockPosition: DockPosition,
        indicatorThickness: CGFloat,
        indicatorOffset: CGFloat,
        on screen: NSScreen
    ) -> CGRect? {
        switch dockPosition {
        case .bottom:
            calculateBottomIndicatorFrame(
                dockItemFrame: dockItemFrame,
                indicatorThickness: indicatorThickness,
                indicatorOffset: indicatorOffset,
                screenHeight: screen.frame.height
            )
        case .left:
            calculateLeftIndicatorFrame(
                dockItemFrame: dockItemFrame,
                indicatorThickness: indicatorThickness,
                indicatorOffset: indicatorOffset,
                screenHeight: screen.frame.height
            )
        case .right:
            calculateRightIndicatorFrame(
                dockItemFrame: dockItemFrame,
                indicatorThickness: indicatorThickness,
                indicatorOffset: indicatorOffset,
                screenHeight: screen.frame.height
            )
        case .top, .cmdTab, .unknown:
            nil
        }
    }

    // MARK: - Bottom Dock Positioning

    /// Calculates the indicator frame for a bottom-positioned dock.
    /// The indicator appears as a horizontal line below the dock icon.
    private static func calculateBottomIndicatorFrame(
        dockItemFrame: CGRect,
        indicatorThickness: CGFloat,
        indicatorOffset: CGFloat,
        screenHeight: CGFloat
    ) -> CGRect {
        // Make indicator slightly narrower than dock icon (60% width)
        let indicatorWidth = dockItemFrame.width * 0.6

        // Center horizontally below the dock icon
        let x = dockItemFrame.midX - (indicatorWidth / 2)

        // Convert from screen coordinates (Y from top) to AppKit coordinates (Y from bottom)
        // The dock item frame uses screen coordinates where Y increases downward from top-left
        let dockItemBottomInScreenCoords = dockItemFrame.origin.y + dockItemFrame.height

        // Position just below the dock icon
        // Positive offset moves indicator up (adds to Y in AppKit coords), negative moves down
        let y = screenHeight - dockItemBottomInScreenCoords - indicatorThickness - 2 + indicatorOffset // 2px base gap

        return CGRect(x: x, y: y, width: indicatorWidth, height: indicatorThickness)
    }

    // MARK: - Left Dock Positioning

    /// Calculates the indicator frame for a left-positioned dock.
    /// The indicator appears as a vertical line to the left of the dock icon.
    private static func calculateLeftIndicatorFrame(
        dockItemFrame: CGRect,
        indicatorThickness: CGFloat,
        indicatorOffset: CGFloat,
        screenHeight: CGFloat
    ) -> CGRect {
        // Make indicator slightly shorter than dock icon height (60% height)
        let indicatorHeight = dockItemFrame.height * 0.6

        // Position to the left of the dock icon
        // Negative offset moves indicator further left (away from dock)
        let x = dockItemFrame.origin.x - indicatorThickness - 2 - indicatorOffset // 2px base gap

        // Convert Y coordinate: screen coords (top-left origin) to AppKit coords (bottom-left origin)
        // Center vertically relative to the dock item
        let dockItemCenterYInScreenCoords = dockItemFrame.origin.y + (dockItemFrame.height / 2)
        let y = screenHeight - dockItemCenterYInScreenCoords - (indicatorHeight / 2)

        return CGRect(x: x, y: y, width: indicatorThickness, height: indicatorHeight)
    }

    // MARK: - Right Dock Positioning

    /// Calculates the indicator frame for a right-positioned dock.
    /// The indicator appears as a vertical line to the right of the dock icon.
    private static func calculateRightIndicatorFrame(
        dockItemFrame: CGRect,
        indicatorThickness: CGFloat,
        indicatorOffset: CGFloat,
        screenHeight: CGFloat
    ) -> CGRect {
        // Make indicator slightly shorter than dock icon height (60% height)
        let indicatorHeight = dockItemFrame.height * 0.6

        // Position to the right of the dock icon
        // Positive offset moves indicator further right (away from dock)
        let dockItemRightInScreenCoords = dockItemFrame.origin.x + dockItemFrame.width
        let x = dockItemRightInScreenCoords + 2 + indicatorOffset // 2px base gap

        // Convert Y coordinate: screen coords (top-left origin) to AppKit coords (bottom-left origin)
        // Center vertically relative to the dock item
        let dockItemCenterYInScreenCoords = dockItemFrame.origin.y + (dockItemFrame.height / 2)
        let y = screenHeight - dockItemCenterYInScreenCoords - (indicatorHeight / 2)

        return CGRect(x: x, y: y, width: indicatorThickness, height: indicatorHeight)
    }
}
