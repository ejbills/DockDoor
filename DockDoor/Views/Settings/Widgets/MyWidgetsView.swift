import AppKit
import SwiftUI

struct MyWidgetsView: View {
    @State private var manifests: [WidgetManifest] = []
    @State private var message: String? = nil
    @State private var searchText: String = ""

    private var filteredManifests: [WidgetManifest] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return manifests }
        let q = searchText.lowercased()
        return manifests.filter { m in
            m.name.lowercased().contains(q) ||
                m.author.lowercased().contains(q) ||
                (m.description?.lowercased().contains(q) ?? false)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StyledGroupBox(label: "My Widgets") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        TextField("Search installed widgets", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 260)
                        Spacer()
                        Button("Install from Folder…") { installFromFolder() }
                        Button("Docs") { openDocs() }
                    }

                    if let message { Text(message).font(.caption).foregroundColor(.secondary) }

                    Divider()

                    if manifests.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("No widgets installed")
                                .foregroundColor(.secondary)
                            Text("Install from a folder with manifest.json (and optional layout.json), or use Marketplace below.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        List {
                            ForEach(filteredManifests, id: \.self) { m in
                                HStack(spacing: 10) {
                                    Image(systemName: "square.grid.2x2")
                                        .foregroundStyle(.secondary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(m.name).font(.headline)
                                            if let v = m.version { Text(v.description).font(.caption).foregroundColor(.secondary) }
                                        }
                                        Text("by \(m.author)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        if let d = m.description, !d.isEmpty {
                                            Text(d).font(.caption).foregroundColor(.secondary).lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                    Button("Reveal") { revealWidget(m) }.buttonStyle(.plain)
                                    Divider().frame(height: 14)
                                    Button(role: .destructive) { removeWidget(m) } label: { Text("Remove") }.buttonStyle(.plain)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .frame(minHeight: 200)
                    }
                }
            }
        }
        .onAppear(perform: reload)
    }

    private func reload() { manifests = WidgetRegistry.loadManifests() }

    private func revealWidget(_ m: WidgetManifest) {
        NSWorkspace.shared.activateFileViewerSelecting([m.installDirectory])
    }

    private func installFromFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let manifestURL = url.appendingPathComponent("manifest.json")
                let mdata = try Data(contentsOf: manifestURL)
                let manifest = try JSONDecoder().decode(WidgetManifest.self, from: mdata)

                // Optional layout.json for declarative widgets
                let layoutURL = url.appendingPathComponent("layout.json")
                if FileManager.default.fileExists(atPath: layoutURL.path) {
                    let ldata = try Data(contentsOf: layoutURL)
                    try WidgetRegistry.install(manifest: manifest, layout: ldata, overwrite: true)
                } else {
                    try WidgetRegistry.install(manifest: manifest, overwrite: true)
                }
                message = "Installed \(manifest.name)"
                reload()
            } catch {
                message = "Install failed: \(error.localizedDescription)"
            }
        }
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
        do {
            try WidgetRegistry.uninstall(id: m.id)
            reload()
            message = "Removed \(m.name)"
        } catch {
            message = "Failed to remove \(m.name)"
        }
    }
}
