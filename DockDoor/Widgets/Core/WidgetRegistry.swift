import Foundation

/// Discovers and loads widget manifests from the user's Application Support directory.
final class WidgetRegistry {
    static let shared = WidgetRegistry()

    private(set) var manifests: [WidgetManifest] = []

    private init() {}

    // Default install root: ~/Library/Application Support/DockDoor/Widgets/
    static var installRoot: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("DockDoor/Widgets", isDirectory: true)
    }

    func reload() {
        print("[WidgetRegistry] Reloading widgets…")
        manifests.removeAll()
        let fm = FileManager.default

        // Ensure directory exists
        do {
            try fm.createDirectory(at: Self.installRoot, withIntermediateDirectories: true)
            print("[WidgetRegistry] Ensured install root exists: \(Self.installRoot.path)")
        } catch {
            print("[WidgetRegistry] Failed to create install root: \(error)")
        }

        let contents: [URL]
        do {
            contents = try fm.contentsOfDirectory(at: Self.installRoot, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            print("[WidgetRegistry] Found \(contents.count) items in install root")
        } catch {
            print("[WidgetRegistry] Failed listing install root: \(error)")
            return
        }

        for dir in contents where dir.hasDirectoryPath {
            let manifestURL = dir.appendingPathComponent("manifest.json", isDirectory: false)
            do {
                let data = try Data(contentsOf: manifestURL)
                var manifest = try JSONDecoder().decode(WidgetManifest.self, from: data)
                manifest.installDirectory = dir
                manifests.append(manifest)
                print("[WidgetRegistry] Loaded manifest id=\(manifest.id) name=\(manifest.name) from \(dir.lastPathComponent)")
            } catch {
                print("[WidgetRegistry] Failed to load manifest at \(manifestURL.path): \(error)")
                continue
            }
        }

        print("[WidgetRegistry] Reload complete: \(manifests.count) manifest(s) loaded")
    }

    func matchingWidgets(for bundleId: String) -> [WidgetManifest] {
        if manifests.isEmpty { reload() }
        return manifests.filter { $0.supports(bundleId: bundleId) }
    }
}
