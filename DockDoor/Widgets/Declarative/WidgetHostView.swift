import applescript_adapter
import Foundation
import SwiftUI

/// Hosts and renders a declarative widget manifest for a given mode.
struct WidgetHostView: View {
    let manifest: WidgetManifest
    let mode: WidgetMode
    let context: [String: String]

    @State private var wireframe: Wireframe?
    @State private var loadError: String?

    var body: some View {
        Group {
            if let wireframe {
                let renderer = WireframeRenderer()
                switch mode {
                case .embedded:
                    if let n = wireframe.embedded { AnyView(renderer.render(n, context: context, onAction: handleAction)) } else { placeholder("No embedded layout") }
                case .full:
                    if let n = wireframe.full { AnyView(renderer.render(n, context: context, onAction: handleAction)) } else { placeholder("No full layout") }
                }
            } else if let loadError {
                placeholder(loadError)
            } else {
                ProgressView().frame(width: 24, height: 24)
            }
        }
        .onAppear(perform: loadWireframe)
    }

    @ViewBuilder
    private func placeholder(_ text: String) -> some View {
        Text(text).font(.caption).foregroundColor(.secondary)
            .padding(12)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func loadWireframe() {
        guard let dir = manifest.installDirectory else {
            print("[WidgetHost] Missing install directory for id=\(manifest.id)")
            loadError = "Missing install directory"
            return
        }
        let entryName = manifest.entry ?? "layout.json"
        let fileURL = dir.appendingPathComponent(entryName, isDirectory: false)
        do {
            let data = try Data(contentsOf: fileURL)
            let wf = try JSONDecoder().decode(Wireframe.self, from: data)
            wireframe = wf
            print("[WidgetHost] Loaded wireframe for id=\(manifest.id) mode=\(mode) from \(fileURL.path)")
        } catch {
            print("[WidgetHost] Failed to load wireframe at \(fileURL.path): \(error)")
            loadError = "Failed to load layout.json"
        }
    }

    private func handleAction(_ action: String) {
        guard let script = manifest.actions?[action], !script.isEmpty else {
            print("[WidgetHost] No script found for action=\(action) (id=\(manifest.id))")
            return
        }
        print("[WidgetHost] AppleScriptAdapter: executing action=\(action) (id=\(manifest.id))")
        Task {
            do {
                let runner = AppleScriptRunner()
                let res = try await runner.run(script: script)
                print("[WidgetHost] status=\(res.status)")
                if !res.stdout.isEmpty { print("[WidgetHost] stdout: \(res.stdout)") }
                if !res.stderr.isEmpty { print("[WidgetHost] stderr: \(res.stderr)") }
            } catch {
                print("[WidgetHost] AppleScriptAdapter error: \(error)")
            }
        }
    }
}
