import SwiftUI

struct SettingsLinkRow: View {
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    let icon: String
    var iconColor: Color = .secondary
    let destination: URL

    var body: some View {
        Link(destination: destination) {
            HStack(spacing: 12) {
                SettingsIcon(systemName: icon, color: iconColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }
}
