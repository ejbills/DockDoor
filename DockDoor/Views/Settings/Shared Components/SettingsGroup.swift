import SwiftUI

struct SettingsGroup<Content: View>: View {
    var header: LocalizedStringKey?
    var compact: Bool
    @ViewBuilder var content: Content

    init(header: LocalizedStringKey? = nil, compact: Bool = false, @ViewBuilder content: () -> Content) {
        self.header = header
        self.compact = compact
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let header {
                Text(header)
                    .textCase(.uppercase)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }

            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(.horizontal, 14)
            .padding(.vertical, compact ? 8 : 14)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}
