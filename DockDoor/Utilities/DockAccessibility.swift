import ApplicationServices
import Cocoa

/// Shared helpers for walking the Dock's accessibility tree.
enum DockAccessibility {
    static let dockBundleIdentifier = "com.apple.dock"

    // MARK: - Dock Tree Access

    static func dockApplication() -> NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: dockBundleIdentifier).first
    }

    static func dockList() -> (app: NSRunningApplication, element: AXUIElement)? {
        guard let dockApp = dockApplication() else { return nil }

        let dockElement = AXUIElementCreateApplication(dockApp.processIdentifier)
        guard let children = try? dockElement.children(),
              let dockList = children.first(where: { (try? $0.role()) == kAXListRole })
        else {
            return nil
        }

        return (dockApp, dockList)
    }

    static func dockItems() -> [AXUIElement]? {
        guard let dockList = dockList()?.element,
              let dockItems = try? dockList.children()
        else {
            return nil
        }

        return dockItems
    }

    // MARK: - Geometry

    static func frame(for item: AXUIElement) -> CGRect? {
        guard let position = try? item.position(),
              let size = try? item.size(),
              size.width > 0,
              size.height > 0
        else {
            return nil
        }

        return CGRect(origin: position, size: size)
    }

    static func currentDockFrame() -> CGRect? {
        guard let dockItems = dockItems() else { return nil }

        let itemFrames = dockItems.compactMap(frame(for:))
        guard let firstFrame = itemFrames.first else { return nil }

        return itemFrames.dropFirst().reduce(into: firstFrame) { partialResult, frame in
            partialResult = partialResult.union(frame)
        }
    }

    // MARK: - Item Lookup

    static func applicationDockItemFrame(for app: NSRunningApplication) -> CGRect? {
        guard let dockItems = dockItems() else { return nil }

        let bundleIdentifier = app.bundleIdentifier

        for item in dockItems {
            guard (try? item.subrole()) == "AXApplicationDockItem" else { continue }

            if let bundleIdentifier,
               let itemURL = try? item.attribute(kAXURLAttribute, NSURL.self)?.absoluteURL,
               let itemBundle = Bundle(url: itemURL),
               itemBundle.bundleIdentifier == bundleIdentifier
            {
                return frame(for: item)
            }

            if let itemTitle = try? item.title(),
               itemTitle == app.localizedName
            {
                return frame(for: item)
            }
        }

        return nil
    }
}
