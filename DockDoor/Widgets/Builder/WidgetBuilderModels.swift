import Foundation
import SwiftUI

// MARK: - Simple no-code editor models

enum EditorContainerType: String, CaseIterable, Identifiable {
    case hstack, vstack
    var id: String { rawValue }
}

enum EditorItemKind: String, CaseIterable, Identifiable {
    case text
    case imageSymbol
    case buttonRow
    case spacer
    var id: String { rawValue }
}

struct EditorItem: Identifiable, Hashable {
    let id = UUID()
    var kind: EditorItemKind
    // Text
    var text: String = ""
    var font: String = "body"
    var color: String = "primary"
    var lineLimit: Int? = 1
    // Image
    var symbol: String = "star"
    var size: CGFloat = 16
    // Button Row (editable buttons)
    var buttons: [EditorButton] = []
}

struct EditorContainer: Identifiable {
    let id = UUID()
    var type: EditorContainerType = .hstack
    var spacing: CGFloat = 8
    var children: [EditorItem] = []
}

// MARK: - Conversion to Wireframe/WireNode

extension EditorItem {
    func toWireNode() -> WireNode {
        switch kind {
        case .text:
            WireNode(
                type: .text,
                spacing: nil,
                alignment: nil,
                children: nil,
                text: text,
                font: font,
                foreground: color,
                truncation: "tail",
                lineLimit: lineLimit,
                symbol: nil,
                size: nil,
                buttons: nil
            )
        case .imageSymbol:
            WireNode(
                type: .imageSymbol,
                spacing: nil,
                alignment: nil,
                children: nil,
                text: nil,
                font: nil,
                foreground: nil,
                truncation: nil,
                lineLimit: nil,
                symbol: symbol,
                size: size,
                buttons: nil
            )
        case .buttonRow:
            WireNode(
                type: .buttonRow,
                spacing: spacingDefault,
                alignment: nil,
                children: nil,
                text: nil,
                font: nil,
                foreground: nil,
                truncation: nil,
                lineLimit: nil,
                symbol: nil,
                size: nil,
                buttons: buttons.map { WireButton(symbol: $0.symbol, action: $0.action) }
            )
        case .spacer:
            WireNode(
                type: .spacer,
                spacing: nil,
                alignment: nil,
                children: nil,
                text: nil,
                font: nil,
                foreground: nil,
                truncation: nil,
                lineLimit: nil,
                symbol: nil,
                size: nil,
                buttons: nil
            )
        }
    }

    private var spacingDefault: CGFloat { 8 }
}

extension EditorContainer {
    func toWireNode() -> WireNode {
        let childrenNodes = children.map { $0.toWireNode() }
        switch type {
        case .hstack:
            return WireNode(
                type: .hstack,
                spacing: spacing,
                alignment: nil,
                children: childrenNodes,
                text: nil,
                font: nil,
                foreground: nil,
                truncation: nil,
                lineLimit: nil,
                symbol: nil,
                size: nil,
                buttons: nil
            )
        case .vstack:
            return WireNode(
                type: .vstack,
                spacing: spacing,
                alignment: "leading",
                children: childrenNodes,
                text: nil,
                font: nil,
                foreground: nil,
                truncation: nil,
                lineLimit: nil,
                symbol: nil,
                size: nil,
                buttons: nil
            )
        }
    }

    func toWireframe(embeddedOnly: Bool = true) -> Wireframe {
        let node = toWireNode()
        return Wireframe(embedded: node, full: embeddedOnly ? nil : node)
    }
}

// Editable button model for button rows
struct EditorButton: Identifiable, Hashable {
    let id = UUID()
    var symbol: String
    var action: String
}
