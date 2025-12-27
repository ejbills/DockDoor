import SwiftUI

struct SettingsPickerRow<SelectionValue: Hashable, Content: View>: View {
    let title: LocalizedStringKey
    var description: LocalizedStringKey?
    let icon: String
    @Binding var selection: SelectionValue
    var iconColor: Color = .accentColor
    @ViewBuilder var content: Content

    init(
        title: LocalizedStringKey,
        description: LocalizedStringKey? = nil,
        icon: String,
        selection: Binding<SelectionValue>,
        iconColor: Color = .accentColor,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.description = description
        self.icon = icon
        _selection = selection
        self.iconColor = iconColor
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 12) {
            SettingsIcon(systemName: icon, color: iconColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)

                if let description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Picker("", selection: $selection) {
                content
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: 150)
        }
        .padding(.vertical, 4)
    }
}
