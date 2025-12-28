import SwiftUI

struct SettingsToggleRow: View {
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    let icon: String
    @Binding var isOn: Bool
    var iconColor: Color = .accentColor

    var body: some View {
        HStack(spacing: 12) {
            SettingsIcon(systemName: icon, color: iconColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding(.vertical, 2)
    }
}
