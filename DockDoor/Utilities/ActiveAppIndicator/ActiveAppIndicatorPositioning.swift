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
    /// - Parameters:
    ///   - indicatorLength: Explicit length (width for bottom, height for left/right).
    static func calculateIndicatorFrame(
        for dockItemFrame: CGRect,
        dockPosition: DockPosition,
        indicatorThickness: CGFloat,
        indicatorOffset: CGFloat,
        indicatorLength: CGFloat
    ) -> CGRect? {
        switch dockPosition {
        case .bottom:
            calculateBottomIndicatorFrame(
                dockItemFrame: dockItemFrame,
                indicatorThickness: indicatorThickness,
                indicatorOffset: indicatorOffset,
                indicatorLength: indicatorLength
            )
        case .left:
            calculateLeftIndicatorFrame(
                dockItemFrame: dockItemFrame,
                indicatorThickness: indicatorThickness,
                indicatorOffset: indicatorOffset,
                indicatorHeight: indicatorLength
            )
        case .right:
            calculateRightIndicatorFrame(
                dockItemFrame: dockItemFrame,
                indicatorThickness: indicatorThickness,
                indicatorOffset: indicatorOffset,
                indicatorHeight: indicatorLength
            )
        case .top, .cmdTab, .cli, .unknown:
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
        indicatorLength: CGFloat
    ) -> CGRect {
        // Center horizontally below the dock icon
        let x = dockItemFrame.midX - (indicatorLength / 2)

        // Position just below the dock icon
        // Positive offset moves indicator up (adds to Y in AppKit coords), negative moves down
        let y =
            dockItemFrame.minY - indicatorThickness - 2
                + indicatorOffset // 2px base gap

        return CGRect(x: x, y: y, width: indicatorLength, height: indicatorThickness)
    }

    // MARK: - Left Dock Positioning

    /// Calculates the indicator frame for a left-positioned dock.
    /// The indicator appears as a vertical line to the left of the dock icon.
    private static func calculateLeftIndicatorFrame(
        dockItemFrame: CGRect,
        indicatorThickness: CGFloat,
        indicatorOffset: CGFloat,
        indicatorHeight: CGFloat?
    ) -> CGRect {
        // Use explicit height if provided, otherwise 60% of dock icon height
        let height = indicatorHeight ?? (dockItemFrame.height * 0.655)

        // Position to the left of the dock icon
        // Negative offset moves indicator further left (away from dock)
        let x =
            dockItemFrame.origin.x - indicatorThickness - 2 - indicatorOffset // 2px base gap

        // Center vertically relative to the dock item
        let y = dockItemFrame.midY - (height / 2)

        return CGRect(x: x, y: y, width: indicatorThickness, height: height)
    }

    // MARK: - Right Dock Positioning

    /// Calculates the indicator frame for a right-positioned dock.
    /// The indicator appears as a vertical line to the right of the dock icon.
    private static func calculateRightIndicatorFrame(
        dockItemFrame: CGRect,
        indicatorThickness: CGFloat,
        indicatorOffset: CGFloat,
        indicatorHeight: CGFloat?
    ) -> CGRect {
        // Use explicit height if provided, otherwise 60% of dock icon height
        let height = indicatorHeight ?? (dockItemFrame.height * 0.655)

        // Position to the right of the dock icon
        // Positive offset moves indicator further right (away from dock)
        let dockItemRightInScreenCoords =
            dockItemFrame.origin.x + dockItemFrame.width
        let x = dockItemRightInScreenCoords + 2 + indicatorOffset // 2px base gap

        // Center vertically relative to the dock item
        let y = dockItemFrame.midY - (height / 2)

        return CGRect(x: x, y: y, width: indicatorThickness, height: height)
    }
}
