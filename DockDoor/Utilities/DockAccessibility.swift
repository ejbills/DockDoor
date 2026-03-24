import ApplicationServices
import Cocoa

enum DockAccessibility {
    static func dockItems() -> [AXUIElement]? {
        guard
            let dockApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first
        else {
            return nil
        }

        let dockElement = AXUIElementCreateApplication(dockApp.processIdentifier)
        guard let children = try? dockElement.children(),
              let dockList = children.first(where: { (try? $0.role()) == kAXListRole }),
              let dockItems = try? dockList.children()
        else {
            return nil
        }

        return dockItems
    }

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

    static func applicationDockItemFrame(for app: NSRunningApplication) -> CGRect? {
        guard let bundleIdentifier = app.bundleIdentifier,
              let dockItems = dockItems()
        else {
            return nil
        }

        for item in dockItems {
            guard (try? item.subrole()) == "AXApplicationDockItem" else { continue }

            if let itemURL = try? item.attribute(kAXURLAttribute, NSURL.self)?.absoluteURL,
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
