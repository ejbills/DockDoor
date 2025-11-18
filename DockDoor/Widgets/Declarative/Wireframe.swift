import Foundation
import SwiftUI

// Minimal SwiftUI-wireframe schema and renderer.

enum WireNodeType: String, Codable {
    case vstack
    case hstack
    case zstack
    case text
    case imageSymbol
    case buttonRow
    case spacer
}

struct WireNode: Codable {
    let type: WireNodeType
    let spacing: CGFloat?
    let alignment: String?
    let children: [WireNode]?

    // Text
    let text: String?
    let font: String?
    let foreground: String?
    let truncation: String? // "head", "tail", "middle"
    let lineLimit: Int?

    // Image Symbol
    let symbol: String?
    let size: CGFloat?

    // Button Row
    let buttons: [WireButton]?
}

struct WireButton: Codable, Hashable {
    let symbol: String
    let action: String
}

struct Wireframe: Codable {
    let embedded: WireNode?
    let full: WireNode?
}

/// Very small renderer that ignores dynamic bindings for now and focuses on structure.
struct WireframeRenderer {
    func render(_ node: WireNode, context: [String: String], onAction: @escaping (String) -> Void) -> some View {
        switch node.type {
        case .vstack:
            return AnyView(VStack(alignment: mapAlignment(node.alignment), spacing: node.spacing ?? 8) {
                ForEach(Array((node.children ?? []).enumerated()), id: \.offset) { _, child in
                    render(child, context: context, onAction: onAction)
                }
            })
        case .hstack:
            return AnyView(HStack(alignment: .center, spacing: node.spacing ?? 8) {
                ForEach(Array((node.children ?? []).enumerated()), id: \.offset) { _, child in
                    render(child, context: context, onAction: onAction)
                }
            })
        case .zstack:
            return AnyView(ZStack {
                ForEach(Array((node.children ?? []).enumerated()), id: \.offset) { _, child in
                    render(child, context: context, onAction: onAction)
                }
            })
        case .text:
            let textContent = substitute(node.text ?? "", with: context)
            return AnyView(renderText(content: textContent, node: node))
        case .imageSymbol:
            let symbolName = node.symbol ?? "questionmark"
            let img = Image(systemName: symbolName)
                .resizable()
                .scaledToFit()
                .frame(width: node.size ?? 16, height: node.size ?? 16)
            return AnyView(img)
        case .buttonRow:
            let buttons = node.buttons ?? []
            return AnyView(HStack(spacing: node.spacing ?? 8) {
                ForEach(buttons, id: \.self) { btn in
                    Button(action: { onAction(btn.action) }) {
                        Image(systemName: btn.symbol)
                    }
                    .buttonStyle(.borderless)
                }
            })
        case .spacer:
            return AnyView(Spacer())
        }
    }

    func getFont(_ style: String) -> Font {
        switch style {
        case "caption": .caption
        case "callout": .callout
        case "subheadline": .subheadline
        case "headline": .headline
        case "title3": .title3
        case "title2": .title2
        case "title": .title
        default: .body
        }
    }

    func mapAlignment(_ value: String?) -> HorizontalAlignment {
        switch value {
        case "leading": .leading
        case "trailing": .trailing
        default: .center
        }
    }

    private func getForegroundColor(_ colorName: String) -> Color {
        switch colorName {
        case "primary": .primary
        case "secondary": .secondary
        case "white": .white
        case "gray": .gray
        default: .primary
        }
    }

    private func getTruncationMode(_ truncation: String) -> Text.TruncationMode {
        switch truncation {
        case "head": .head
        case "tail": .tail
        case "middle": .middle
        default: .tail
        }
    }

    @ViewBuilder
    private func renderText(content: String, node: WireNode) -> some View {
        let baseText = Text(content)
        let font = node.font.map(getFont) ?? .body
        let color = node.foreground.map(getForegroundColor) ?? .primary
        let truncation = node.truncation.map(getTruncationMode) ?? .tail

        if let lineLimit = node.lineLimit {
            baseText
                .font(font)
                .foregroundColor(color)
                .truncationMode(truncation)
                .lineLimit(lineLimit)
        } else {
            baseText
                .font(font)
                .foregroundColor(color)
                .truncationMode(truncation)
        }
    }
}

extension WireframeRenderer {
    func substitute(_ input: String, with ctx: [String: String]) -> String {
        var result = input
        for (k, v) in ctx {
            result = result.replacingOccurrences(of: "{{\(k)}}", with: v)
        }
        return result
    }
}
