import Cocoa
import Defaults

struct RunningDockItem {
    let app: NSRunningApplication
    let element: AXUIElement
    let frame: CGRect
}

/// Handles dock item detection and indicator positioning calculations.
enum ActiveAppIndicatorDockDetection {
    static func dockList() -> AXUIElement? {
        guard let dockApp = DockUtils.runningDock,
              let children = try? AXUIElementCreateApplication(dockApp.processIdentifier).children()
        else { return nil }
        return children.first { (try? $0.role()) == kAXListRole }
    }

    static func isDockShown(listFrame: CGRect?) -> Bool {
        guard let listFrame else { return false }
        let screens = NSScreen.screens
        guard let index = DockLockerGeometry.screenIndexHoldingDock(
            dockRect: listFrame,
            screenFrames: screens.map(\.cgFrame),
            dockPosition: DockUtils.getDockPosition()
        ) else { return false }
        return screens[index].cgFrame.contains(CGPoint(x: listFrame.midX, y: listFrame.midY))
    }

    /// Finds the dock item frame for a given running application.
    /// - Parameter app: The running application to find in the dock.
    /// - Returns: The frame of the dock item, or nil if not found.
    static func getDockItemFrame(for app: NSRunningApplication) -> CGRect? {
        let shortcutBundleIdentifier = LauncherShortcutResolver.owningShortcutBundleIdentifier(of: app)
        guard let bundleIdentifier = shortcutBundleIdentifier ?? app.bundleIdentifier,
              let dockItems = try? dockList()?.children()
        else {
            return nil
        }

        let appItems = dockItems.filter { (try? $0.subrole()) == "AXApplicationDockItem" }
        let matchingItems = DockObserver.applicationDockItems(from: appItems).filter { $0.bundleIdentifier == bundleIdentifier }
        if matchingItems.count > 1 {
            guard let result = DockObserver.activeInstance?.resolveInstances(of: matchingItems).first(where: {
                $0.status.resolvedApplication?.processIdentifier == app.processIdentifier
            }), let item = result.dockItemElement else { return nil }
            return frame(of: item).map { restingFrame($0, among: appItems) }
        }
        if let item = matchingItems.first {
            return frame(of: item.element).map { restingFrame($0, among: appItems) }
        }
        if shortcutBundleIdentifier == nil, let title = app.localizedName,
           let item = appItems.first(where: { (try? $0.title()) == title })
        {
            return frame(of: item).map { restingFrame($0, among: appItems) }
        }

        return nil
    }

    private static func restingFrame(_ itemFrame: CGRect, among items: [AXUIElement]) -> CGRect {
        let frames = items.compactMap { frame(of: $0) }
        var resting = itemFrame
        switch DockUtils.getDockPosition() {
        case .bottom:
            if let edge = frames.map(\.maxY).max() { resting.origin.y = edge - resting.height }
        case .left:
            if let edge = frames.map(\.minX).min() { resting.origin.x = edge }
        case .right:
            if let edge = frames.map(\.maxX).max() { resting.origin.x = edge - resting.width }
        case .top, .cmdTab, .cli, .unknown:
            break
        }
        return resting
    }

    /// Gets the frame for a dock element from accessibility.
    static func frame(of element: AXUIElement) -> CGRect? {
        guard let position = try? element.position(),
              let size = try? element.size()
        else { return nil }

        return CGRect(origin: position, size: size)
    }

    static func appKitFrame(of element: AXUIElement) -> CGRect? {
        frame(of: element).map(appKitFrame(fromAccessibilityFrame:))
    }

    private static func appKitFrame(fromAccessibilityFrame frame: CGRect) -> CGRect {
        let screen = NSScreen.screenFromQuartzPoint(
            CGPoint(x: frame.midX, y: frame.midY)
        )
        let appKitOrigin = DockObserver.nsPointFromCGPoint(
            CGPoint(x: frame.minX, y: frame.maxY),
            forScreen: screen
        )

        return CGRect(origin: appKitOrigin, size: frame.size)
    }

    /// Calculates indicator height, offset, and length based on dock size and position.
    /// Values derived from testing for dock sizes 36-156.
    /// - Parameters:
    ///   - dockSize: The current dock icon size.
    ///   - dockPosition: The current dock position.
    /// - Returns: A tuple containing the calculated height, offset, and length.
    static func calculateAutoSize(
        dockSize: CGFloat,
        dockPosition: DockPosition
    ) -> (height: CGFloat, offset: CGFloat, length: CGFloat) {
        let size = Int(dockSize)

        let height: CGFloat = size <= 50 ? 3.0 : 4.0

        let dotInset: CGFloat = if #available(macOS 27.0, *) { 5.0 } else { 0.0 }

        let offset: CGFloat =
            switch dockPosition {
            case .bottom:
                (size <= 50 ? 4.0 : 5.0) + dotInset
            case .left:
                (size <= 50 ? -4.0 : -5.0) - dotInset
            case .right:
                -3.0 - dotInset
            default:
                0.0
            }

        let length: CGFloat =
            if dockSize <= 40 {
                floor(dockSize * 0.30)
            } else if dockSize <= 50 {
                floor(dockSize * 0.35)
            } else if dockSize <= 80 {
                floor(dockSize * 0.40)
            } else {
                floor(dockSize * 0.45)
            }

        return (height, offset, length)
    }

    private static func resolveMetrics(
        dockSize: CGFloat,
        dockPosition: DockPosition
    ) -> (thickness: CGFloat, offset: CGFloat, length: CGFloat) {
        let autoSize = calculateAutoSize(
            dockSize: dockSize,
            dockPosition: dockPosition
        )

        let thickness = Defaults[.activeAppIndicatorAutoSize]
            ? autoSize.height : Defaults[.activeAppIndicatorHeight]
        let offset = Defaults[.activeAppIndicatorAutoSize]
            ? autoSize.offset : Defaults[.activeAppIndicatorOffset]
        let length = Defaults[.activeAppIndicatorAutoLength]
            ? autoSize.length : Defaults[.activeAppIndicatorLength]

        return (thickness, offset, length)
    }

    static func dotMetrics(
        dockSize: CGFloat,
        dockPosition: DockPosition
    ) -> (dotSize: CGFloat, thickness: CGFloat, offset: CGFloat) {
        let autoSize = calculateAutoSize(
            dockSize: dockSize,
            dockPosition: dockPosition
        )
        let offset = Defaults[.activeAppIndicatorAutoSize]
            ? autoSize.offset : Defaults[.activeAppIndicatorOffset]
        let dotSize: CGFloat = dockSize <= 50 ? 5.0 : 6.0
        return (dotSize, autoSize.height, offset)
    }

    static func getRunningAppDockItems() -> [RunningDockItem] {
        (DockObserver.activeInstance?.resolvedApplicationDockItems() ?? []).compactMap { result in
            guard result.isRunning == true, let app = result.status.resolvedApplication,
                  let item = result.dockItemElement, let frame = appKitFrame(of: item)
            else { return nil }
            return RunningDockItem(app: app, element: item, frame: frame)
        }
    }

    /// Positions the indicator window relative to the dock item.
    /// - Parameters:
    ///   - indicatorWindow: The window to position.
    ///   - dockItemFrame: The frame of the dock item.
    ///   - dockPosition: The current dock position.
    static func positionIndicator(
        _ indicatorWindow: ActiveAppIndicatorWindow,
        relativeTo dockItemFrame: CGRect,
        dockPosition: DockPosition
    ) {
        let appKitDockItemFrame = appKitFrame(fromAccessibilityFrame: dockItemFrame)
        guard let screen = CGPoint(
            x: appKitDockItemFrame.midX,
            y: appKitDockItemFrame.midY
        ).screen() else { return }

        let metrics = resolveMetrics(
            dockSize: DockUtils.getDockSize(on: screen),
            dockPosition: dockPosition
        )

        // Calculate the indicator frame using the positioning module
        guard
            var indicatorFrame =
            ActiveAppIndicatorPositioning.calculateIndicatorFrame(
                for: appKitDockItemFrame,
                dockPosition: dockPosition,
                indicatorThickness: metrics.thickness,
                indicatorOffset: metrics.offset,
                indicatorLength: metrics.length
            )
        else {
            indicatorWindow.orderOut(nil)
            return
        }

        // Apply shift setting for alignment (-2 to +2 pixels)
        indicatorFrame.origin.x += Defaults[.activeAppIndicatorShift]

        indicatorWindow.setFrame(indicatorFrame, display: true)
    }

    /// Calculates the indicator frame without applying it to the window.
    static func calculateIndicatorFrame(
        relativeTo dockItemFrame: CGRect,
        dockPosition: DockPosition
    ) -> CGRect? {
        let appKitDockItemFrame = appKitFrame(fromAccessibilityFrame: dockItemFrame)
        guard let screen = CGPoint(
            x: appKitDockItemFrame.midX,
            y: appKitDockItemFrame.midY
        ).screen() else { return nil }

        let metrics = resolveMetrics(
            dockSize: DockUtils.getDockSize(on: screen),
            dockPosition: dockPosition
        )

        guard
            var indicatorFrame =
            ActiveAppIndicatorPositioning.calculateIndicatorFrame(
                for: appKitDockItemFrame,
                dockPosition: dockPosition,
                indicatorThickness: metrics.thickness,
                indicatorOffset: metrics.offset,
                indicatorLength: metrics.length
            )
        else {
            return nil
        }

        indicatorFrame.origin.x += Defaults[.activeAppIndicatorShift]
        return indicatorFrame
    }

    /// Returns a collapsed version of a frame (zero length, centered at the same position).
    static func collapsedFrame(
        from frame: CGRect,
        dockPosition: DockPosition
    ) -> CGRect {
        switch dockPosition {
        case .bottom:
            CGRect(
                x: frame.midX,
                y: frame.origin.y,
                width: 0,
                height: frame.height
            )
        case .left, .right:
            CGRect(
                x: frame.origin.x,
                y: frame.midY,
                width: frame.width,
                height: 0
            )
        default:
            frame
        }
    }
}
