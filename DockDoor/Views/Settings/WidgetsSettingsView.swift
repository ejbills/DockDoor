import AppKit
import Defaults
import SwiftUI

struct WidgetsSettingsView: View {
    @Default(.useWidgetSystem) private var useWidgetSystem
    @State private var manifests: [WidgetManifest] = []
    @State private var installing: Bool = false
    @State private var message: String? = nil

    var body: some View {
        BaseSettingsView {
            VStack(alignment: .leading, spacing: 16) {
                StyledGroupBox(label: "Widgets (Experimental)") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(isOn: $useWidgetSystem) { Text("Enable Widget System (Experimental)") }
                        Text("Allows installing and rendering widgets without updating the app.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack(spacing: 8) {
                            Button(action: installSampleWidget) {
                                if installing { ProgressView().scaleEffect(0.8) } else { Text("Install Sample Widget") }
                            }
                            .disabled(installing)
                            Button(action: openWidgetsFolder) { Text("Open Widgets Folder") }
                        }

                        if let message { Text(message).font(.caption).foregroundColor(.secondary) }
                    }
                }

                StyledGroupBox(label: "Installed Widgets") {
                    VStack(alignment: .leading, spacing: 8) {
                        if manifests.isEmpty {
                            Text("No widgets installed").foregroundColor(.secondary)
                        } else {
                            ForEach(manifests, id: \.self) { m in
                                HStack(alignment: .center, spacing: 10) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(m.name).font(.headline)
                                        Text("\(m.id) • v\(m.version)").font(.caption).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Button(role: .destructive) { removeWidget(m) } label: { Image(systemName: "trash") }
                                        .buttonStyle(.plain)
                                }
                                .padding(.vertical, 4)
                                if m != manifests.last { Divider() }
                            }
                        }
                    }
                }
            }
            .onAppear(perform: reload)
        }
    }

    private func reload() {
        WidgetRegistry.shared.reload()
        manifests = WidgetRegistry.shared.manifests
    }

    private func openWidgetsFolder() {
        let url = WidgetRegistry.installRoot
        _ = try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }

    private func removeWidget(_ m: WidgetManifest) {
        guard let dir = m.installDirectory else { return }
        do {
            try FileManager.default.removeItem(at: dir)
            message = "Removed \(m.name)"
            reload()
        } catch {
            message = "Failed to remove \(m.name)"
        }
    }

    private func installSampleWidget() {
        installing = true
        message = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let sampleId = "com.dockdoor.sample.music"
            let root = WidgetRegistry.installRoot.appendingPathComponent(sampleId, isDirectory: true)
            let fm = FileManager.default
            do {
                try fm.createDirectory(at: root, withIntermediateDirectories: true)
                let manifest = Self.sampleManifest
                let layout = Self.sampleLayout
                try manifest.write(to: root.appendingPathComponent("manifest.json"), atomically: true, encoding: .utf8)
                try layout.write(to: root.appendingPathComponent("layout.json"), atomically: true, encoding: .utf8)
                DispatchQueue.main.async {
                    installing = false
                    message = "Installed sample widget targeting Music.app"
                    reload()
                }
            } catch {
                DispatchQueue.main.async {
                    installing = false
                    message = "Failed to install sample widget"
                }
            }
        }
    }

    // MARK: - Sample Files

    private static var sampleManifest: String {
        """
        {\n  \"id\": \"com.dockdoor.sample.music\",\n  \"name\": \"Sample Music Controls\",\n  \"version\": \"1.0.0\",\n  \"author\": \"DockDoor\",\n  \"runtime\": \"declarative\",\n  \"entry\": \"layout.json\",\n  \"modes\": [\"embedded\", \"full\"],\n  \"matches\": [{ \"bundleId\": \"com.apple.Music\" }]\n}\n
        """
    }

    private static var sampleLayout: String {
        """
        {\n  \"embedded\": {\n    \"type\": \"hstack\",\n    \"spacing\": 8,\n    \"children\": [\n      {\"type\": \"imageSymbol\", \"symbol\": \"music.note\", \"size\": 16},\n      {\"type\": \"text\", \"text\": \"Music\", \"font\": \"callout\"},\n      {\"type\": \"spacer\"},\n      {\"type\": \"buttonRow\", \"buttons\": [\n        {\"symbol\": \"backward.fill\", \"action\": \"media.previous\"},\n        {\"symbol\": \"playpause.fill\", \"action\": \"media.playPause\"},\n        {\"symbol\": \"forward.fill\", \"action\": \"media.next\"}\n      ]}\n    ]\n  },\n  \"full\": {\n    \"type\": \"vstack\",\n    \"spacing\": 12,\n    \"children\": [\n      {\"type\": \"text\", \"text\": \"Sample Music Controls\", \"font\": \"title3\"},\n      {\"type\": \"buttonRow\", \"buttons\": [\n        {\"symbol\": \"backward.fill\", \"action\": \"media.previous\"},\n        {\"symbol\": \"playpause.fill\", \"action\": \"media.playPause\"},\n        {\"symbol\": \"forward.fill\", \"action\": \"media.next\"}\n      ]}\n    ]\n  }\n}\n
        """
    }
}
