import AppKit
import SwiftUI

struct MyWidgetsView: View {
    @State private var manifests: [WidgetManifest] = []
    @State private var showingPreviewPlayground: Bool = false
    @State private var message: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("My Widgets").font(.title2).bold()
                Spacer()
                Button("Open Docs") { openDocs() }
                Button("Preview from Folder…") { showingPreviewPlayground = true }
                Button("Import .zip") { importZip() }
                Button("Open Widgets Folder") { openWidgetsFolder() }
            }
            if let message { Text(message).font(.caption).foregroundColor(.secondary) }

            GroupBox(label: Text("Installed")) {
                if manifests.isEmpty {
                    Text("No widgets installed").foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    List {
                        ForEach(manifests, id: \.self) { m in
                            HStack(spacing: 8) {
                                if let icon = m.icon, !icon.isEmpty {
                                    Image(systemName: "square.grid.2x2") // placeholder
                                        .foregroundStyle(.secondary)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(m.name).font(.headline)
                                    Text("by \(m.author)").font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                Button(role: .destructive) { removeWidget(m) } label: { Image(systemName: "trash") }.buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(minHeight: 180)
                }
            }
        }
        .onAppear(perform: reload)
        .sheet(isPresented: $showingPreviewPlayground) { WidgetPreviewPlaygroundView() }
        .padding(8)
    }

    private func reload() { manifests = WidgetRegistry.loadManifests() }

    private func openWidgetsFolder() {
        let url = WidgetRegistry.installRoot
        _ = try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }

    private func importZip() {
        // Placeholder for Phase 3
        message = "Import is coming soon."
    }

    private func openDocs() {
        let repoURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("docs/widgets.md")
        if FileManager.default.fileExists(atPath: repoURL.path) {
            NSWorkspace.shared.open(repoURL)
        } else if let online = URL(string: "https://github.com/ejbills/DockDoor/blob/main/docs/widgets.md") {
            NSWorkspace.shared.open(online)
        }
    }

    private func removeWidget(_ m: WidgetManifest) {
        do { try WidgetRegistry.uninstall(id: m.id); reload(); message = "Removed \(m.name)" }
        catch { message = "Failed to remove \(m.name)" }
    }
}
