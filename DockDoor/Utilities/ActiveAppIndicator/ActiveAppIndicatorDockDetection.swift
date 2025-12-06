import Cocoa
import Defaults

/// Handles dock item detection and indicator positioning calculations.
enum ActiveAppIndicatorDockDetection {
    /// Finds the dock item frame for a given running application.
    /// - Parameter app: The running application to find in the dock.
    /// - Returns: The frame of the dock item, or nil if not found.
    static func getDockItemFrame(for app: NSRunningApplication) -> CGRect? {
        guard let bundleIdentifier = app.bundleIdentifier else { return nil }

        // Get the Dock application
        guard
            let dockApp = NSRunningApplication.runningApplications(
                withBundleIdentifier: "com.apple.dock"
            ).first
        else {
            return nil
        }

        let dockElement = AXUIElementCreateApplication(
            dockApp.processIdentifier
        )

        // Navigate to the dock's list of items
        guard let children = try? dockElement.children(),
              let axList = children.first(where: { element in
                  (try? element.role()) == kAXListRole
              }),
              let dockItems = try? axList.children()
        else {
            return nil
        }

        // Find the dock item for this app
        for item in dockItems {
            guard let subrole = try? item.subrole(),
                  subrole == "AXApplicationDockItem"
            else { continue }

            // Check if this is our app by comparing bundle identifiers
            if let itemURL = try? item.attribute(kAXURLAttribute, NSURL.self)?
                .absoluteURL,
                let itemBundle = Bundle(url: itemURL),
                itemBundle.bundleIdentifier == bundleIdentifier
            {
                return getFrameForDockItem(item)
            }

            // Check by running app if bundle ID check failed
            if let itemTitle = try? item.title(),
               itemTitle == app.localizedName
            {
                return getFrameForDockItem(item)
            }
        }

        return nil
    }

    /// Gets the frame for a dock item from accessibility.
    private static func getFrameForDockItem(_ item: AXUIElement) -> CGRect? {
        guard let position = try? item.position(),
              let size = try? item.size()
        else { return nil }

        return CGRect(origin: position, size: size)
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

        let offset: CGFloat =
            switch dockPosition {
            case .bottom:
                size <= 50 ? 4.0 : 5.0
            case .left:
                size <= 50 ? -4.0 : -5.0
            case .right:
                -3.0
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
        let indicatorThickness: CGFloat
        let indicatorOffset: CGFloat
        let indicatorLength: CGFloat

        let dockSize = DockUtils.getDockSize()
        let autoSize = calculateAutoSize(
            dockSize: dockSize,
            dockPosition: dockPosition
        )

        // Auto size controls height and offset
        if Defaults[.activeAppIndicatorAutoSize] {
            indicatorThickness = autoSize.height
            indicatorOffset = autoSize.offset
        } else {
            indicatorThickness = Defaults[.activeAppIndicatorHeight]
            indicatorOffset = Defaults[.activeAppIndicatorOffset]
        }

        if Defaults[.activeAppIndicatorAutoLength] {
            indicatorLength = autoSize.length
        } else {
            indicatorLength = Defaults[.activeAppIndicatorLength]
        }

        // Get the screen containing the dock
        guard
            let screen = NSScreen.screens.first(where: {
                $0.frame.contains(dockItemFrame.origin)
            }) ?? NSScreen.main
        else {
            return
        }

        // Calculate the indicator frame using the positioning module
        guard
            var indicatorFrame =
            ActiveAppIndicatorPositioning.calculateIndicatorFrame(
                for: dockItemFrame,
                dockPosition: dockPosition,
                indicatorThickness: indicatorThickness,
                indicatorOffset: indicatorOffset,
                indicatorLength: indicatorLength,
                on: screen
            )
        else {
            indicatorWindow.orderOut(nil)
            return
        }

        // Apply shift setting for alignment (-2 to +2 pixels)
        indicatorFrame.origin.x += Defaults[.activeAppIndicatorShift]

        indicatorWindow.setFrame(indicatorFrame, display: true)
    }
}
