import SwiftUI

struct DiscoverView: View {
    @State private var catalog: WidgetCatalog? = nil
    @State private var loading: Bool = false
    @State private var message: String? = nil
    @State private var searchText: String = ""

    private var filteredItems: [WidgetCatalogItem] {
        guard let items = catalog?.items else { return [] }
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return items }
        return items.filter { item in
            item.name.lowercased().contains(q) ||
                item.author.lowercased().contains(q) ||
                (item.releaseNotes?.lowercased().contains(q) ?? false)
        }
    }

    var body: some View {
        StyledGroupBox(label: "Marketplace") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 8) {
                    TextField("Search widgets", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 260)
                    Spacer()
                    Button(loading ? "Loading…" : "Refresh") { Task { await refresh() } }
                        .disabled(loading)
                }

                if let message { Text(message).font(.caption).foregroundColor(.secondary) }

                if loading {
                    HStack { ProgressView(); Text("Loading catalog…").foregroundColor(.secondary) }
                } else if catalog == nil {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("No catalog available")
                            .font(.headline)
                        Text("Add a cached catalog or configure a remote source in a future update.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    List(filteredItems) { item in
                        HStack(alignment: .center, spacing: 12) {
                            Image(systemName: "square.grid.2x2")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(item.name).font(.headline)
                                    Spacer(minLength: 8)
                                    Text(item.version.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Text("by \(item.author)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if let notes = item.releaseNotes, !notes.isEmpty {
                                    Text(notes)
                                        .lineLimit(2)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Button("Install") {}
                                .disabled(true)
                                .help("Installation from Marketplace will be available in a future update or with network enabled.")
                        }
                        .padding(.vertical, 2)
                    }
                    .frame(minHeight: 220)
                }
            }
        }
        .task { await refresh() }
    }

    private func refresh() async {
        loading = true
        defer { loading = false }
        do {
            if let cached = try WidgetCatalogClient.shared.loadCachedCatalog() {
                catalog = cached
                message = nil
            } else {
                catalog = nil
                message = "No cached catalog found."
            }
        } catch {
            catalog = nil
            message = "Failed to load catalog: \(error.localizedDescription)"
        }
    }
}
