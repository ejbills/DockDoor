import SwiftUI

/// Warnings tint the symbol orange; notes keep it secondary.
struct SettingsCallout: View {
    enum Tone {
        case warning
        case info
    }

    var tone: Tone = .warning
    var icon: String?
    var title: Text?
    let message: Text
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    private var symbol: String {
        icon ?? (tone == .warning ? "exclamationmark.triangle.fill" : "info.circle")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tone == .warning ? AnyShapeStyle(Color.orange) : AnyShapeStyle(.secondary))
                .font(.body)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                if let title {
                    title
                        .fontWeight(.medium)
                }
                message
                    .font(title == nil ? .callout : .footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.settings)
            }
        }
    }
}

struct SettingsWarningBanner: View {
    let text: LocalizedStringKey
    var icon = "exclamationmark.triangle.fill"

    var body: some View {
        SettingsCallout(tone: .warning, icon: icon, message: Text(text))
    }
}
