import Foundation
import SwiftUI

// High-level modes a widget can render in
enum WidgetMode: String, Codable, CaseIterable {
    case embedded
    case full
}

// Match rules for selecting widgets per app
struct WidgetMatchRule: Codable, Hashable {
    let bundleId: String
}

// Status provider configuration for dynamic data polling
struct WidgetStatusProvider: Codable, Hashable {
    let statusScript: String
    let pollIntervalMs: Int
    let delimiter: String
    let fields: [String: Int] // field name -> index mapping
}

// Simplified widget manifest - only name and author required, ID is auto-generated
struct WidgetManifest: Codable, Hashable {
    let id: UUID
    let name: String
    let author: String
    let runtime: String // "declarative" for JSON layouts, "native" for built-in SwiftUI views
    let entry: String? // e.g., "layout.json" for declarative, view class name for native
    let modes: [WidgetMode]
    let matches: [WidgetMatchRule]
    // Optional action map: key -> AppleScript snippet to execute
    let actions: [String: String]?
    // Optional status provider for dynamic data
    let provider: WidgetStatusProvider?

    // MARK: - Extended manifest fields (Marketplace + Builder)

    // Semantic version of the widget
    let version: SemVer?
    // Human-readable description
    let description: String?
    // Icon reference: URL string or asset/system name
    let icon: String?
    // Minimum supported DockDoor version
    let minAppVersion: SemVer?
    // Permission capabilities for security/trust surface
    let permissions: [WidgetPermission]?
    // Screenshot URLs for detail views
    let screenshots: [URL]?
    // Optional signature for remote installs
    let signature: String?
    // Source indicates whether local or remote
    let source: WidgetSource?
    // Updated at (ISO-8601 string). Keep as string for decoder compatibility.
    let updatedAt: String?

    // Computed install directory based on UUID
    var installDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("DockDoor/Widgets/\(id.uuidString)", isDirectory: true)
    }

    init(
        name: String,
        author: String,
        runtime: String,
        entry: String? = nil,
        modes: [WidgetMode],
        matches: [WidgetMatchRule],
        actions: [String: String]? = nil,
        provider: WidgetStatusProvider? = nil,
        version: SemVer? = nil,
        description: String? = nil,
        icon: String? = nil,
        minAppVersion: SemVer? = nil,
        permissions: [WidgetPermission]? = nil,
        screenshots: [URL]? = nil,
        signature: String? = nil,
        source: WidgetSource? = nil,
        updatedAt: String? = nil
    ) {
        id = UUID()
        self.name = name
        self.author = author
        self.runtime = runtime
        self.entry = entry
        self.modes = modes
        self.matches = matches
        self.actions = actions
        self.provider = provider
        self.version = version
        self.description = description
        self.icon = icon
        self.minAppVersion = minAppVersion
        self.permissions = permissions
        self.screenshots = screenshots
        self.signature = signature
        self.source = source
        self.updatedAt = updatedAt
    }

    func supports(bundleId: String) -> Bool {
        matches.contains(where: { $0.bundleId == bundleId })
    }

    func isNative() -> Bool {
        runtime == "native"
    }

    func isDeclarative() -> Bool {
        runtime == "declarative"
    }
}

// A simple selection result for the orchestrator
struct WidgetSelection {
    let embedded: [WidgetManifest]
    let full: [WidgetManifest]
}

// MARK: - Extensions / Supporting Types

/// Simple semantic version model with Comparable
struct SemVer: Codable, Hashable, Comparable, CustomStringConvertible {
    let major: Int
    let minor: Int
    let patch: Int

    init(_ major: Int, _ minor: Int, _ patch: Int) {
        self.major = major; self.minor = minor; self.patch = patch
    }

    init?(string: String) {
        let parts = string.split(separator: ".").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        major = parts[0]
        minor = parts[1]
        patch = parts.count > 2 ? parts[2] : 0
    }

    var description: String { "\(major).\(minor).\(patch)" }

    static func < (lhs: SemVer, rhs: SemVer) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }
}

/// Permissions that a widget can request/use
enum WidgetPermission: String, Codable, Hashable, CaseIterable {
    case appleScriptActions
}

/// Indicates where the widget came from
enum WidgetSource: String, Codable, Hashable {
    case local
    case remote
}

extension WidgetManifest {
    /// Parse ISO-8601 updatedAt string to Date
    var updatedAtDate: Date? {
        guard let updatedAt else { return nil }
        let f = ISO8601DateFormatter()
        return f.date(from: updatedAt)
    }

    /// Basic validators for Builder save/install
    func validate() -> [String] {
        var errors: [String] = []
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errors.append("Name is required") }
        if author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errors.append("Author is required") }
        if runtime == "declarative" {
            if entry == nil || entry?.isEmpty == true { errors.append("Entry (layout.json) is required for declarative widgets") }
        } else if runtime == "native" {
            if entry == nil || entry?.isEmpty == true { errors.append("Entry (native view identifier) is required for native widgets") }
        } else {
            errors.append("Unsupported runtime: \(runtime)")
        }
        if modes.isEmpty { errors.append("At least one mode (embedded/full) is required") }
        return errors
    }
}
