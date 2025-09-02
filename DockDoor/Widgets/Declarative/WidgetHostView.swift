import Foundation
import SwiftUI

/// Hosts and renders a declarative widget manifest for a given mode.
struct WidgetHostView: View {
    let manifest: WidgetManifest
    let mode: WidgetMode
    let context: [String: String]
    let screen: NSScreen?
    let onContextUpdate: (([String: String]) -> Void)?

    @State private var wireframe: Wireframe?
    @State private var loadError: String?
    @State private var dynamicContext: [String: String] = [:]

    init(manifest: WidgetManifest, mode: WidgetMode, context: [String: String], screen: NSScreen?, onContextUpdate: (([String: String]) -> Void)? = nil) {
        self.manifest = manifest
        self.mode = mode
        self.context = context
        self.screen = screen
        self.onContextUpdate = onContextUpdate
    }

    var body: some View {
        Group {
            if manifest.isNative() {
                renderNativeWidget()
            } else if let wireframe {
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
            if manifest.isDeclarative() {
                loadWireframe()
            }
        }
        // Only apply polling for declarative widgets - native widgets handle their own polling
        .widgetPolling(provider: manifest.isDeclarative() ? manifest.provider : nil) { updatedContext in
            dynamicContext = updatedContext
            onContextUpdate?(updatedContext)
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
        let dir = manifest.installDirectory
        let entryName = manifest.entry ?? "layout.json"
        let fileURL = dir.appendingPathComponent(entryName, isDirectory: false)
        do {
            let data = try Data(contentsOf: fileURL)
            let wf = try JSONDecoder().decode(Wireframe.self, from: data)
            wireframe = wf
        } catch {
            loadError = "Failed to load layout.json"
        }
    }

    @MainActor
    private func handleAction(_ action: String) { handleAction(action, extras: nil) }

    @ViewBuilder
    private func renderNativeWidget() -> some View {
        let mergedContext = context.merging(dynamicContext) { _, new in new }
        if let nativeWidget = NativeWidgetFactory.createWidget(
            manifest: manifest,
            context: mergedContext,
            mode: mode,
            screen: screen ?? NSScreen.main ?? NSScreen.screens.first!
        ) {
            nativeWidget
        } else {
            let name = manifest.entry ?? "<none>"
            placeholder("Native widget '\(name)' not found")
        }
    }
}

extension WidgetHostView {
    @MainActor
    private func handleAction(_ action: String, extras: [String: String]?) {
        guard let script = manifest.actions?[action], !script.isEmpty else { return }
        let expandedScript = expandScriptTemplates(script, extras: extras)
        Task.detached {
            _ = AppleScriptExecutor.run(expandedScript)
        }
    }

    private func expandScriptTemplates(_ script: String, extras: [String: String]?) -> String {
        var expanded = script
        var merged = context.merging(dynamicContext) { _, new in new }
        if let extras { merged.merge(extras) { _, new in new } }
        for (key, value) in merged {
            expanded = expanded.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        return expanded
    }
}
