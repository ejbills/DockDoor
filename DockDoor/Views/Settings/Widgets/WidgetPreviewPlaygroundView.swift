import AppKit
import SwiftUI

struct WidgetPreviewPlaygroundView: View {
    @State private var selectedFolder: URL? = nil
    @State private var manifest: WidgetManifest? = nil
    @State private var layoutData: Data? = nil
    @State private var message: String? = nil
    @State private var mode: WidgetMode = .embedded
    @State private var mockContext: [String: String] = [:]
    @State private var installedForPreview: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Widget Preview Playground").font(.title3).bold()
                Spacer()
                Button("Open Docs") { openDocs() }
            }

            HStack(spacing: 8) {
                Button("Choose Folder…") { chooseFolder() }
                if let folder = selectedFolder { Text(folder.path).font(.caption).foregroundColor(.secondary) }
                Spacer()
                Picker("Mode", selection: $mode) { Text("Embedded").tag(WidgetMode.embedded); Text("Full").tag(WidgetMode.full) }
                    .pickerStyle(.segmented)
            }

            if let message { Text(message).font(.caption).foregroundColor(.secondary) }

            GroupBox(label: Text("Preview")) {
                if let manifest, installedForPreview {
                    WidgetHostView(
                        manifest: manifest,
                        mode: mode,
                        context: mockContext,
                        screen: NSScreen.main
                    )
                    .frame(minWidth: 360, minHeight: 140)
                } else {
                    Text("Select a widget folder containing manifest.json and layout.json, then Install for Preview.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            GroupBox(label: Text("Mock Data")) {
                VStack(alignment: .leading, spacing: 6) {
                    if mockContext.isEmpty { Text("No mock keys yet").foregroundColor(.secondary) }
                    ForEach(Array(mockContext.keys).sorted(), id: \.self) { key in
                        HStack { Text(key); Spacer(); TextField("Value", text: Binding(get: { mockContext[key] ?? "" }, set: { mockContext[key] = $0 })) }
                    }
                    HStack { Button("Add media keys") { addDefaultMockKeys() }; Spacer() }
                }
            }

            HStack {
                if let manifest, installedForPreview { Button("Uninstall Preview") { uninstall(manifest) } }
                Spacer()
                if let manifest, let layoutData, !installedForPreview { Button("Install for Preview") { installForPreview(manifest, layoutData: layoutData) } }
            }
        }
        .padding(8)
    }

    // MARK: - Actions

    private func openDocs() {
        // Try local docs first
        if let docsURL = Bundle.main.url(forResource: "widgets", withExtension: "md") {
            NSWorkspace.shared.open(docsURL)
        } else if let repoDocs = URL(string: "https://github.com/ejbills/DockDoor/blob/main/docs/widgets.md") {
            NSWorkspace.shared.open(repoDocs)
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            selectedFolder = url
            loadManifestAndLayout(at: url)
        }
    }

    private func loadManifestAndLayout(at url: URL) {
        message = nil
        let manifestURL = url.appendingPathComponent("manifest.json")
        let layoutURL = url.appendingPathComponent("layout.json")
        do {
            let mdata = try Data(contentsOf: manifestURL)
            let manifest = try JSONDecoder().decode(WidgetManifest.self, from: mdata)
            let ldata = try Data(contentsOf: layoutURL)
            _ = try JSONDecoder().decode(Wireframe.self, from: ldata) // validate layout
            self.manifest = manifest
            layoutData = ldata
            installedForPreview = false
            message = "Loaded \(manifest.name). Click Install for Preview to render."
        } catch {
            message = "Failed to load widget: \(error.localizedDescription)"
            manifest = nil
            layoutData = nil
        }
    }

    private func installForPreview(_ manifest: WidgetManifest, layoutData: Data) {
        do {
            try WidgetRegistry.install(manifest: manifest, layout: layoutData, overwrite: true)
            installedForPreview = true
            message = "Installed \(manifest.name) for preview"
        } catch {
            message = "Install failed: \(error.localizedDescription)"
        }
    }

    private func uninstall(_ manifest: WidgetManifest) {
        do {
            try WidgetRegistry.uninstall(id: manifest.id)
            installedForPreview = false
            message = "Uninstalled preview"
        } catch {
            message = "Uninstall failed: \(error.localizedDescription)"
        }
    }

    private func addDefaultMockKeys() {
        mockContext.merge(["media.title": "Song", "media.artist": "Artist"]) { _, n in n }
    }
}
