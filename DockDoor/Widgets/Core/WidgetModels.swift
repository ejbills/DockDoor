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

// On-disk manifest schema for a declarative SwiftUI widget
struct WidgetManifest: Codable, Hashable {
    let id: String
    let name: String
    let version: String
    let author: String?
    let runtime: String // e.g., "declarative"
    let entry: String? // e.g., "layout.json"
    let modes: [WidgetMode]
    let matches: [WidgetMatchRule]
    // Optional action map: key -> AppleScript snippet to execute
    let actions: [String: String]?
    // Optional status provider for dynamic data
    let provider: WidgetStatusProvider?

    // Non-codable properties resolved at load time
    var installDirectory: URL?

    func supports(bundleId: String) -> Bool {
        matches.contains(where: { $0.bundleId == bundleId })
    }
}

// A simple selection result for the orchestrator
struct WidgetSelection {
    let embedded: [WidgetManifest]
    let full: [WidgetManifest]
}
