import AppKit
import SwiftUI

// MARK: - Live Preview (in-memory)

private struct WidgetPreviewPane: View {
    let wireframe: Wireframe
    let mode: WidgetMode
    let context: [String: String]
    let actions: [String: String]

    var body: some View {
        GroupBox {
            switch mode {
            case .embedded:
                if let n = wireframe.embedded { render(n) } else { placeholder("No embedded layout") }
            case .full:
                if let n = wireframe.full { render(n) } else { placeholder("No full layout") }
            }
        }
    }

    @ViewBuilder private func render(_ node: WireNode) -> some View {
        let renderer = WireframeRenderer()
        renderer.render(node, context: context) { action in
            if let script = actions[action] { _ = AppleScriptExecutor.run(script) }
        }
        .frame(minWidth: 320, minHeight: 120)
    }

    @ViewBuilder private func placeholder(_ text: String) -> some View {
        Text(text).font(.caption).foregroundColor(.secondary)
            .padding(12)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
