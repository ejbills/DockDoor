import SwiftUI

struct SettingsLinkRow: View {
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    let icon: String
    let destination: URL
    var iconColor: Color = .accentColor

    var body: some View {
        Link(destination: destination) {
            HStack(spacing: 12) {
                SettingsIcon(systemName: icon, color: iconColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }
}
