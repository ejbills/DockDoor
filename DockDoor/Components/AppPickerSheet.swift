import AppKit
import Defaults
import SwiftUI

struct InstalledApp: Identifiable {
    let id: String
    let name: String
    let icon: NSImage

    var bundleIdentifier: String { id }
}

struct AppPickerSheet: View {
    @Binding var selectedApps: [String]
    let title: String
    let description: String
    let selectionMode: SelectionMode
    @Environment(\.dismiss) private var dismiss

    @State private var installedApps: [InstalledApp] = []
    @State private var isLoading = true
    @State private var searchText = ""

    enum SelectionMode {
        case include // Selected apps ARE in the list (for grouping)
        case exclude // Selected apps are NOT shown (for filtering - inverted logic)
    }

    init(
        selectedApps: Binding<[String]>,
        title: String,
        description: String,
        selectionMode: SelectionMode = .include
    ) {
        _selectedApps = selectedApps
        self.title = title
        self.description = description
        self.selectionMode = selectionMode
    }

    private var filteredApps: [InstalledApp] {
        if searchText.isEmpty {
            return installedApps
        }
        return installedApps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()

            // Search
            TextField("Search apps...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .padding(.bottom, 8)

            // App list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading applications...")
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding()
                    } else if filteredApps.isEmpty {
                        Text(searchText.isEmpty ? "No applications found." : "No matching apps.")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(filteredApps) { app in
                            appRow(app)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 300)

            Divider()

            // Footer
            HStack {
                Text("\(selectedApps.count) app\(selectedApps.count == 1 ? "" : "s") selected")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.return)
                .buttonStyle(AccentButtonStyle())
            }
            .padding()
        }
        .frame(width: 400)
        .task {
            installedApps = await loadInstalledApps()
            isLoading = false
        }
    }

    @ViewBuilder
    private func appRow(_ app: InstalledApp) -> some View {
        HStack(spacing: 8) {
            Toggle(isOn: Binding(
                get: {
                    switch selectionMode {
                    case .include:
                        selectedApps.contains(app.bundleIdentifier)
                    case .exclude:
                        // For filtering: checked = NOT in filter list (app is shown)
                        !selectedApps.contains(app.bundleIdentifier) &&
                            !selectedApps.contains(where: { $0.caseInsensitiveCompare(app.name) == .orderedSame })
                    }
                },
                set: { isOn in
                    switch selectionMode {
                    case .include:
                        if isOn {
                            if !selectedApps.contains(app.bundleIdentifier) {
                                selectedApps.append(app.bundleIdentifier)
                            }
                        } else {
                            selectedApps.removeAll { $0 == app.bundleIdentifier }
                        }
                    case .exclude:
                        if isOn {
                            // Remove from filter (show the app)
                            selectedApps.removeAll { $0 == app.bundleIdentifier }
                            selectedApps.removeAll { $0.caseInsensitiveCompare(app.name) == .orderedSame }
                        } else {
                            // Add to filter (hide the app)
                            if !selectedApps.contains(app.bundleIdentifier) {
                                selectedApps.append(app.bundleIdentifier)
                            }
                        }
                    }
                }
            )) { EmptyView() }
                .toggleStyle(.checkbox)

            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 20, height: 20)

            Text(app.name)
                .lineLimit(1)

            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.primary.opacity(0.001)) // Hit target
        .contentShape(Rectangle())
    }

    private func loadInstalledApps() async -> [InstalledApp] {
        await Task.detached(priority: .userInitiated) {
            var apps: [InstalledApp] = []
            let workspace = NSWorkspace.shared
            let fileManager = FileManager.default

            let defaultLocations = [
                "/Applications",
                "/System/Applications",
                "/System/Applications/Utilities",
                "~/Applications",
            ].map { NSString(string: $0).expandingTildeInPath }

            let allLocations = Set(defaultLocations + Defaults[.customAppDirectories])

            for directory in allLocations {
                guard let enumerator = fileManager.enumerator(
                    at: URL(fileURLWithPath: directory),
                    includingPropertiesForKeys: [.isApplicationKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                ) else { continue }

                let urls = enumerator.allObjects.compactMap { $0 as? URL }
                for fileURL in urls {
                    guard fileURL.pathExtension == "app" else { continue }

                    guard let bundle = Bundle(url: fileURL),
                          let bundleId = bundle.bundleIdentifier,
                          let name = bundle.infoDictionary?["CFBundleName"] as? String ??
                          bundle.infoDictionary?["CFBundleDisplayName"] as? String
                    else { continue }

                    apps.append(InstalledApp(id: bundleId, name: name, icon: workspace.icon(forFile: fileURL.path)))
                }
            }

            // Add Finder explicitly
            apps.append(InstalledApp(
                id: "com.apple.finder",
                name: "Finder",
                icon: workspace.icon(forFile: "/System/Library/CoreServices/Finder.app")
            ))

            // Remove duplicates and sort
            var seenBundleIds = Set<String>()
            return apps.filter { app in
                if seenBundleIds.contains(app.id) {
                    return false
                }
                seenBundleIds.insert(app.id)
                return true
            }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }.value
    }
}
