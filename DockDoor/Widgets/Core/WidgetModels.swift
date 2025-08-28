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

    // Computed install directory based on UUID
    var installDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("DockDoor/Widgets/\(id.uuidString)", isDirectory: true)
    }

    init(name: String, author: String, runtime: String, entry: String? = nil, modes: [WidgetMode], matches: [WidgetMatchRule], actions: [String: String]? = nil, provider: WidgetStatusProvider? = nil) {
        id = UUID()
        self.name = name
        self.author = author
        self.runtime = runtime
        self.entry = entry
        self.modes = modes
        self.matches = matches
        self.actions = actions
        self.provider = provider
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
