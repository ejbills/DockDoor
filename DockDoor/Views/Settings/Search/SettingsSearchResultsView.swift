import SwiftUI

struct SettingsSearchResultsView: View {
    @ObservedObject var engine: SettingsSearchEngine
    let onSelect: (SettingsSearchItem) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if engine.results.isEmpty {
                    Text("No results")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else {
                    ForEach(engine.resultsByTab, id: \.tab) { group in
                        Section {
                            ForEach(group.items) { result in
                                SettingsSearchResultRow(item: result.item) {
                                    onSelect(result.item)
                                }
                            }
                        } header: {
                            Text(group.displayName)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .textCase(.uppercase)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.top, 12)
                                .padding(.bottom, 4)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

private struct SettingsSearchResultRow: View {
    let item: SettingsSearchItem
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: item.icon)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(.system(size: 12))
                        .lineLimit(1)

                    if !item.section.isEmpty {
                        Text(item.section)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .background(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .padding(.horizontal, 4)
    }
}
