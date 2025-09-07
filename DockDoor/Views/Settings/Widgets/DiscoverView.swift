import SwiftUI

struct DiscoverView: View {
    @State private var catalog: WidgetCatalog? = nil
    @State private var loading: Bool = false
    @State private var message: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Discover").font(.title2).bold()
                Spacer()
                Button(loading ? "Loading…" : "Refresh") { Task { await refresh() } }.disabled(loading)
            }
            if let message { Text(message).font(.caption).foregroundColor(.secondary) }

            if loading {
                ProgressView().frame(width: 24, height: 24)
            } else if let catalog {
                List(catalog.items) { item in
                    VStack(alignment: .leading) {
                        HStack {
                            Text(item.name).font(.headline)
                            Spacer()
                            Text(item.version.description).font(.caption).foregroundColor(.secondary)
                        }
                        Text(item.author).font(.caption).foregroundColor(.secondary)
                    }
                }
            } else {
                Text("No catalog loaded yet.").foregroundColor(.secondary)
            }
        }
        .task { await refresh() }
        .padding(8)
    }

    private func refresh() async {
        loading = true
        defer { loading = false }
        do {
            // During development, point to a local file URL stub. Replace with remote in Phase 3.
            // e.g., let url = URL(fileURLWithPath: "/path/to/cache.json")
            if let cached = try WidgetCatalogClient.shared.loadCachedCatalog() {
                catalog = cached
            } else {
                message = "Provide a catalog cache or configure remote URL."
            }
        } catch {
            message = "Failed to load catalog: \(error.localizedDescription)"
        }
    }
}
