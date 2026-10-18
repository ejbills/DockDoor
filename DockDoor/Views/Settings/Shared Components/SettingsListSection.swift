import SwiftUI

struct SettingsListSection: View {
    let title: LocalizedStringKey
    let footer: LocalizedStringKey
    let items: [String]
    let itemIcon: String
    let emptyText: LocalizedStringKey
    let addTitle: LocalizedStringKey
    let onAdd: () -> Void
    let onRemove: (String) -> Void
    let onRemoveAll: () -> Void

    var body: some View {
        Section {
            if items.isEmpty {
                Text(emptyText)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items, id: \.self) { item in
                    HStack(spacing: 8) {
                        Image(systemName: itemIcon)
                            .foregroundStyle(.secondary)
                            .frame(width: 18)
                        Text(item)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button {
                            onRemove(item)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Remove")
                        .accessibilityLabel("Remove \(item)")
                    }
                }
            }

            HStack {
                Button(addTitle, action: onAdd)
                    .buttonStyle(.settings)
                Spacer()
                if !items.isEmpty {
                    DangerButton(action: onRemoveAll) {
                        Text("Remove All")
                    }
                }
            }
        } header: {
            Text(title)
        } footer: {
            Text(footer)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
