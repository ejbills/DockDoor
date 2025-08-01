import AppKit
import Defaults
import SwiftUI

struct FiltersSettingsView: View {
    @Default(.appNameFilters) var appNameFilters
    @Default(.windowTitleFilters) var windowTitleFilters
    @Default(.customAppDirectories) var customAppDirectories
    @Default(.orphanedWindowAssociations) var orphanedWindowAssociations

    @State private var showingAddFilterSheet = false
    @State private var showingOrphanedWindowSheet = false
    @State private var newFilter = FilterEntry(text: "")
    @State private var showingDirectoryPicker = false

    struct FilterEntry: Identifiable, Hashable {
        let id = UUID()
        var text: String
    }

    private var installedApps: [(name: String, icon: NSImage)] {
        var apps: [(String, NSImage)] = []
        let appLocations = [
            "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities",
            "~/Applications",
        ]

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

        return apps.sorted { $0.0 < $1.0 }
    }

    var body: some View {
        BaseSettingsView {
            VStack(alignment: .leading, spacing: 16) {
                // Custom App Directories Section
                StyledGroupBox(label: "Custom Application Directories") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add additional directories to scan for applications. This is useful if you keep apps outside standard locations.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 4)

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
                        }
                        .frame(maxHeight: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                        )
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
                }

                // App Filters Section
                StyledGroupBox(label: "Application Filters") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Select which applications DockDoor should show previews for. Unchecked apps will be ignored.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 4)

                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                if installedApps.isEmpty {
                                    Text("No applications found or scanned yet.")
                                        .foregroundColor(.secondary)
                                        .padding()
                                } else {
                                    ForEach(installedApps, id: \.name) { app in
                                        HStack(spacing: 8) {
                                            Toggle(isOn: Binding(
                                                get: { !appNameFilters.contains(app.name) },
                                                set: { isEnabled in
                                                    if isEnabled {
                                                        appNameFilters.removeAll { $0 == app.name }
                                                    } else {
                                                        if !appNameFilters.contains(app.name) {
                                                            appNameFilters.append(app.name)
                                                        }
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
                            }
                            .padding(8)
                        }
                        .frame(height: 200)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                        )
                    }
                }

                // Orphaned Window Associations Section
                StyledGroupBox(label: "Orphaned Window Associations") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "questionmark.app.dashed")
                                .foregroundColor(.orange)
                                .font(.system(size: 14))

                            Text("Some apps don't properly associate their windows with their dock icons. Create manual associations to fix this.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        .padding(.bottom, 4)

                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                if orphanedWindowAssociations.isEmpty {
                                    VStack(spacing: 8) {
                                        Image(systemName: "app.connected.to.app.below.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.secondary)
                                        Text("No window associations configured")
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                } else {
                                    ForEach(orphanedWindowAssociations, id: \.windowID) { association in
                                        HStack(spacing: 12) {
                                            Image(systemName: "link")
                                                .foregroundColor(.accentColor)
                                                .font(.system(size: 12))

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(association.windowTitle)
                                                    .font(.system(size: 12, weight: .medium))
                                                    .lineLimit(1)
                                                HStack(spacing: 4) {
                                                    Image(systemName: "arrow.right")
                                                        .font(.system(size: 8))
                                                        .foregroundColor(.secondary)
                                                    Text(association.bundleIdentifier)
                                                        .font(.system(size: 10))
                                                        .foregroundColor(.secondary)
                                                        .lineLimit(1)
                                                }
                                            }

                                            Spacer()

                                            Button(action: {
                                                orphanedWindowAssociations.removeAll { $0.windowID == association.windowID }
                                            }) {
                                                Image(systemName: "trash")
                                                    .foregroundColor(.secondary)
                                                    .font(.system(size: 11))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color(NSColor.controlColor).opacity(0.5))
                                        .cornerRadius(6)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(8)
                        }
                        .frame(maxHeight: 120)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                        )

                        HStack {
                            Button("Manage Associations") {
                                showingOrphanedWindowSheet = true
                            }
                            .buttonStyle(AccentButtonStyle(color: .accentColor))

                            Spacer()

                            if !orphanedWindowAssociations.isEmpty {
                                DangerButton(action: {
                                    orphanedWindowAssociations.removeAll()
                                }) {
                                    Text("Clear All")
                                }
                            }
                        }
                    }
                }

                // Window Title Filters Section
                StyledGroupBox(label: "Window Title Filters") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Exclude windows from capture by filtering specific text in their titles (case-insensitive).")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 4)

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
                        .frame(maxHeight: 150)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                        )
                        HStack {
                            Button("Add Filter") {
                                showingAddFilterSheet = true
                            }
                            .buttonStyle(AccentButtonStyle(color: .accentColor))

                            Spacer()

                            if !windowTitleFilters.isEmpty {
                                DangerButton(action: {
                                    windowTitleFilters.removeAll()
                                }) {
                                    Text("Remove All")
                                }
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddFilterSheet) {
                AddFilterSheet(
                    isPresented: $showingAddFilterSheet,
                    filterToAdd: $newFilter,
                    onAdd: { filter in
                        if !filter.text.isEmpty, !windowTitleFilters.contains(where: { $0.caseInsensitiveCompare(filter.text) == .orderedSame }) {
                            windowTitleFilters.append(filter.text)
                        }
                    }
                )
            }
            .sheet(isPresented: $showingOrphanedWindowSheet) {
                OrphanedWindowAssociationSheet(
                    isPresented: $showingOrphanedWindowSheet,
                    orphanedWindowAssociations: $orphanedWindowAssociations
                )
            }
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
