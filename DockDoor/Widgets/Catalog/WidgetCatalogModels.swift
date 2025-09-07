import Foundation

struct WidgetCatalog: Codable {
    let items: [WidgetCatalogItem]
    let updatedAt: String?
}

struct WidgetCatalogItem: Codable, Hashable, Identifiable {
    let id: UUID
    let name: String
    let author: String
    let version: SemVer
    let runtime: String
    let entry: String?
    let modes: [WidgetMode]
    let matches: [WidgetMatchRule]
    let actions: [String: String]?
    let provider: WidgetStatusProvider?
    let icon: String?
    let screenshots: [URL]?
    let permissions: [WidgetPermission]?
    let minAppVersion: SemVer?
    let downloadURL: URL
    let signature: String
    let sha256: String
    let releaseNotes: String?
}
