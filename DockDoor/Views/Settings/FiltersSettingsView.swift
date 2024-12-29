import AppKit
import Defaults
import SwiftUI

struct FiltersSettingsView: View {
    @Default(.appNameFilters) var appNameFilters
    @Default(.windowTitleFilters) var windowTitleFilters
    @Default(.ignoreAppsWithSingleWindow) var ignoreAppsWithSingleWindow
    @Default(.customAppDirectories) var customAppDirectories

    @State private var showingAddFilterSheet = false
    @State private var newFilter = FilterEntry(text: "")
    @State private var showingDirectoryPicker = false

    struct FilterEntry: Identifiable, Hashable {
        let id = UUID()
        var text: String
    }

    private var installedApps: [(name: String, icon: NSImage)] {
        var apps: [(String, NSImage)] = []
        var appLocations = [
            "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities",
            "~/Applications",
        ]

        // Add custom directories
        appLocations.append(contentsOf: customAppDirectories)

        for location in appLocations {
            let expandedPath = NSString(string: location).expandingTildeInPath
            let fileManager = FileManager.default
            guard let urls = try? fileManager.contentsOfDirectory(
                at: URL(fileURLWithPath: expandedPath),
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            let locationApps = urls
                .filter { $0.pathExtension == "app" }
                .compactMap { url -> (String, NSImage)? in
                    guard let bundle = Bundle(url: url),
                          let name = bundle.infoDictionary?["CFBundleName"] as? String ?? bundle.infoDictionary?["CFBundleDisplayName"] as? String
                    else { return nil }
                    return (name, NSWorkspace.shared.icon(forFile: url.path))
                }

            apps.append(contentsOf: locationApps)
        }

        // Remove duplicates by keeping first occurrence of each app name
        var seenNames = Set<String>()
        let uniqueApps = apps.filter { app in
            if seenNames.contains(app.0) {
                return false
            }
            seenNames.insert(app.0)
            return true
        }

        return uniqueApps.sorted { $0.0 < $1.0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle(isOn: $ignoreAppsWithSingleWindow, label: {
                Text("Ignore Apps with One Window")
            })

            // Custom App Directories Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Custom Application Directories")
                    .font(.headline)

                Text("Add additional directories to scan for applications")
                    .foregroundColor(.secondary)
                    .font(.body)

                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        if customAppDirectories.isEmpty {
                            Text("No custom directories added")
                                .foregroundColor(.secondary)
                                .padding(.vertical, 4)
                        } else {
                            ForEach(customAppDirectories, id: \.self) { directory in
                                HStack {
                                    Text(directory)
                                        .lineLimit(1)
                                        .truncationMode(.middle)

                                    Spacer()

                                    Button(action: {
                                        customAppDirectories.removeAll { $0 == directory }
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(Color.gray.opacity(0.25))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .frame(maxHeight: 100)

                HStack {
                    Button("Add Directory") {
                        showingDirectoryPicker = true
                    }
                    .fileImporter(
                        isPresented: $showingDirectoryPicker,
                        allowedContentTypes: [.folder],
                        allowsMultipleSelection: false
                    ) { result in
                        switch result {
                        case let .success(urls):
                            if let url = urls.first {
                                let path = url.path
                                if !customAppDirectories.contains(path) {
                                    customAppDirectories.append(path)
                                }
                            }
                        case let .failure(error):
                            print("Error selecting directory: \(error.localizedDescription)")
                        }
                    }
                    .buttonStyle(AccentButtonStyle(color: .accentColor))

                    Spacer()

                    if !customAppDirectories.isEmpty {
                        DangerButton(action: {
                            customAppDirectories.removeAll()
                        }) {
                            Text("Remove All")
                        }
                    }
                }
            }

            Divider()

            // App Filters Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Application filters")
                    .font(.headline)

                Text("Select which applications can be captured and previewed")
                    .foregroundColor(.secondary)
                    .font(.body)

                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(installedApps, id: \.name) { app in
                            HStack(spacing: 8) {
                                Toggle(isOn: Binding(
                                    get: { !appNameFilters.contains(app.name) },
                                    set: { isEnabled in
                                        if isEnabled {
                                            appNameFilters.removeAll { $0 == app.name }
                                        } else {
                                            appNameFilters.append(app.name)
                                        }
                                    }
                                )) { EmptyView() }

                                Image(nsImage: app.icon)
                                    .resizable()
                                    .frame(width: 16, height: 16)

                                Text(app.name)
                                    .lineLimit(1)

                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(8)
                }
                .frame(height: 200)
                .background(Color.gray.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Divider()

            // Window Title Filters Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Window title filters")
                    .font(.headline)

                Text("Exclude windows from capture by filtering specific text in their titles")
                    .foregroundColor(.secondary)
                    .font(.body)

                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        if !windowTitleFilters.isEmpty {
                            ForEach(windowTitleFilters, id: \.self) { filter in
                                HStack {
                                    Text(filter)
                                        .foregroundColor(.primary)

                                    Spacer()

                                    Button(action: {
                                        windowTitleFilters.removeAll { $0 == filter }
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 4)

                                if filter != windowTitleFilters.last {
                                    Divider()
                                }
                            }
                        } else {
                            Text("No filters added")
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(8)
                }
                .frame(height: 200)
                .background(Color.gray.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                HStack {
                    Button(action: { showingAddFilterSheet.toggle() }) {
                        Text("Add Filter")
                    }
                    .buttonStyle(AccentButtonStyle(color: .accentColor))

                    Spacer()

                    DangerButton(action: {
                        windowTitleFilters.removeAll()
                    }) {
                        Text("Remove All")
                    }
                }
            }
        }
        .padding(20)
        .frame(minWidth: 650)
        .sheet(isPresented: $showingAddFilterSheet) {
            AddFilterSheet(
                isPresented: $showingAddFilterSheet,
                filterToAdd: $newFilter,
                onAdd: { filter in
                    if !filter.text.isEmpty, !windowTitleFilters.contains(filter.text) {
                        windowTitleFilters.append(filter.text)
                    }
                }
            )
        }
    }
}

struct AddFilterSheet: View {
    @Binding var isPresented: Bool
    @Binding var filterToAdd: FiltersSettingsView.FilterEntry
    var onAdd: (FiltersSettingsView.FilterEntry) -> Void
    @State private var showingDuplicateAlert = false

    var body: some View {
        VStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Enter text to filter", text: $filterToAdd.text)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.vertical)

            HStack(spacing: 16) {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("Add") {
                    onAdd(filterToAdd)
                    filterToAdd = FiltersSettingsView.FilterEntry(text: "")
                    isPresented = false
                }
                .keyboardShortcut(.return)
                .disabled(filterToAdd.text.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }
}
