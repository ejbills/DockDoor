import Foundation

/// Discovers and loads widget manifests from the user's Application Support directory.
/// Stateless utility: fetch manifests on demand; no global singleton needed.
enum WidgetRegistry {
    // Default install root: ~/Library/Application Support/DockDoor/Widgets/
    static var installRoot: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("DockDoor/Widgets", isDirectory: true)
    }

    /// Load all manifests currently installed on disk.
    static func loadManifests() -> [WidgetManifest] {
        var results: [WidgetManifest] = []
        let fm = FileManager.default

        // Ensure directory exists (best-effort)
        do {
            try fm.createDirectory(at: installRoot, withIntermediateDirectories: true)
        } catch {
            // Ignore directory creation errors; discovery will fail below
        }

        let contents: [URL]
        do {
            contents = try fm.contentsOfDirectory(at: installRoot, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        } catch {
            return []
        }

        for dir in contents where dir.hasDirectoryPath {
            let manifestURL = dir.appendingPathComponent("manifest.json", isDirectory: false)
            do {
                let data = try Data(contentsOf: manifestURL)
                let manifest = try JSONDecoder().decode(WidgetManifest.self, from: data)
                results.append(manifest)
            } catch {
                continue
            }
        }

        return results
    }

    /// Return manifests matching a bundle id, discovered at call time.
    static func matchingWidgets(for bundleId: String) -> [WidgetManifest] {
        loadManifests().filter { $0.supports(bundleId: bundleId) }
    }

    // MARK: - Install/Uninstall Helpers

    /// Install (or update) a widget manifest to the install root.
    /// Writes to: ~/Library/Application Support/DockDoor/Widgets/<UUID>/manifest.json
    static func install(manifest: WidgetManifest, overwrite: Bool = true) throws {
        let fm = FileManager.default
        let dir = manifest.installDirectory
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("manifest.json")
        if fm.fileExists(atPath: url.path), !overwrite {
            return
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        let data = try encoder.encode(manifest)
        try data.write(to: url, options: .atomic)
    }

    /// Uninstall a widget by id (removes its directory).
    static func uninstall(id: UUID) throws {
        let fm = FileManager.default
        let dir = installRoot.appendingPathComponent(id.uuidString, isDirectory: true)
        if fm.fileExists(atPath: dir.path) {
            try fm.removeItem(at: dir)
        }
    }
}
