import Foundation
import SwiftUI

/// Hosts and renders a declarative widget manifest for a given mode.
struct WidgetHostView: View {
    let manifest: WidgetManifest
    let mode: WidgetMode
    let context: [String: String]

    @State private var wireframe: Wireframe?
    @State private var loadError: String?
    @State private var dynamicContext: [String: String] = [:]
    @State private var statusTimer: Timer?

    var body: some View {
        Group {
            if let wireframe {
                let renderer = WireframeRenderer()
                let mergedContext = context.merging(dynamicContext) { _, new in new }
                switch mode {
                case .embedded:
                    if let n = wireframe.embedded { AnyView(renderer.render(n, context: mergedContext, onAction: handleAction)) } else { placeholder("No embedded layout") }
                case .full:
                    if let n = wireframe.full { AnyView(renderer.render(n, context: mergedContext, onAction: handleAction)) } else { placeholder("No full layout") }
                }
            } else if let loadError {
                placeholder(loadError)
            } else {
                ProgressView().frame(width: 24, height: 24)
            }
        }
        .onAppear {
            loadWireframe()
            startStatusPolling()
        }
        .onDisappear {
            stopStatusPolling()
        }
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
        print("[WidgetHost] AppleScript: executing action=\(action) (id=\(manifest.id))")
        Task.detached {
            let expandedScript = expandScriptTemplates(script)
            let result = AppleScriptExecutor.run(expandedScript)

            if let output = result.output {
                print("[WidgetHost] stdout: \(output)")
            }
            if let error = result.error {
                print("[WidgetHost] stderr: \(error)")
            }
        }
    }

    private func expandScriptTemplates(_ script: String) -> String {
        var expanded = script
        let mergedContext = context.merging(dynamicContext) { _, new in new }
        for (key, value) in mergedContext {
            expanded = expanded.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        return expanded
    }

    private func startStatusPolling() {
        guard let provider = manifest.provider else { return }

        let interval = TimeInterval(provider.pollIntervalMs) / 1000.0
        statusTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [self] _ in
            Task { @MainActor in
                await pollStatus(provider: provider)
            }
        }

        // Initial poll
        Task { @MainActor in
            await pollStatus(provider: provider)
        }
    }

    private func stopStatusPolling() {
        statusTimer?.invalidate()
        statusTimer = nil
    }

    @MainActor
    private func pollStatus(provider: WidgetStatusProvider) async {
        let result = await Task.detached {
            AppleScriptExecutor.run(provider.statusScript)
        }.value

        if let error = result.error {
            print("[WidgetHost] Status polling failed for id=\(manifest.id): \(error)")
            return
        }

        guard let output = result.output else {
            print("[WidgetHost] Status polling returned no output for id=\(manifest.id)")
            return
        }

        let components = output.components(separatedBy: provider.delimiter)

        var newDynamicContext: [String: String] = [:]
        for (fieldName, index) in provider.fields {
            if index < components.count {
                newDynamicContext[fieldName] = components[index]
            }
        }

        dynamicContext = newDynamicContext
    }
}
