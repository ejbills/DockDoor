import AppKit
import Defaults
import SwiftUI

struct FiltersSettingsView: View {
    @Default(.appNameFilters) var appNameFilters
    @Default(.windowTitleFilters) var windowTitleFilters
    @Default(.widgetAppFilters) var widgetAppFilters
    @Default(.customAppDirectories) var customAppDirectories

    @State private var showingAddFilterSheet = false
    @State private var showingAppPickerSheet = false
    @State private var showingWidgetAppPickerSheet = false
    @State private var showingDirectoryPicker = false
    @State private var newFilter = FilterEntry(text: "")

    struct FilterEntry: Identifiable, Hashable {
        let id = UUID()
        var text: String
    }

    var body: some View {
        SettingsFormView {
            SettingsListSection(
                title: "Custom application directories",
                footer: "Add additional directories to scan for applications. This is useful if you keep apps outside standard locations.",
                items: customAppDirectories,
                itemIcon: "folder",
                emptyText: "No custom directories added",
                addTitle: "Add Directory…",
                onAdd: { showingDirectoryPicker = true },
                onRemove: { directory in customAppDirectories.removeAll { $0 == directory } },
                onRemoveAll: { customAppDirectories.removeAll() }
            )
            .settingsSearchTarget("filters.appDirectories")
            .fileImporter(
                isPresented: $showingDirectoryPicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                if case let .success(urls) = result, let path = urls.first?.path, !customAppDirectories.contains(path) {
                    customAppDirectories.append(path)
                }
            }

            SettingsListSection(
                title: "Application filters",
                footer: "Hide specific applications from DockDoor previews.",
                items: appNameFilters,
                itemIcon: "app",
                emptyText: "No apps hidden",
                addTitle: "Select Apps to Hide...",
                onAdd: { showingAppPickerSheet = true },
                onRemove: { filter in appNameFilters.removeAll { $0 == filter } },
                onRemoveAll: { appNameFilters.removeAll() }
            )
            .settingsSearchTarget("filters.appFilters")

            SettingsListSection(
                title: "Window title filters",
                footer: "Exclude windows from capture by filtering specific text in their titles (case-insensitive).",
                items: windowTitleFilters,
                itemIcon: "textformat",
                emptyText: "No window title filters added",
                addTitle: "Add Filter…",
                onAdd: { showingAddFilterSheet = true },
                onRemove: { filter in windowTitleFilters.removeAll { $0 == filter } },
                onRemoveAll: { windowTitleFilters.removeAll() }
            )
            .settingsSearchTarget("filters.windowTitle")

            SettingsListSection(
                title: "Widget app filters",
                footer: "Disable dock hover widgets for selected apps while keeping their regular previews. Useful for browsers that expose media sessions like YouTube.",
                items: widgetAppFilters,
                itemIcon: "square.grid.2x2",
                emptyText: "Widgets enabled for all apps",
                addTitle: "Select Apps to Disable Widgets For...",
                onAdd: { showingWidgetAppPickerSheet = true },
                onRemove: { filter in widgetAppFilters.removeAll { $0 == filter } },
                onRemoveAll: { widgetAppFilters.removeAll() }
            )
            .settingsSearchTarget("filters.widgetApps")
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
            .sheet(isPresented: $showingAppPickerSheet) {
                AppPickerSheet(
                    selectedApps: $appNameFilters,
                    title: "Application Filters",
                    description: "Uncheck apps to hide them from DockDoor previews.",
                    selectionMode: .exclude
                )
            }
            .sheet(isPresented: $showingWidgetAppPickerSheet) {
                AppPickerSheet(
                    selectedApps: $widgetAppFilters,
                    title: "Widget App Filters",
                    description: "Uncheck apps to disable dock hover widgets for them while keeping regular previews.",
                    selectionMode: .exclude
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
            TextField("Enter text to filter", text: $filterToAdd.text)
                .textFieldStyle(.roundedBorder)
                .padding(.vertical)

            HStack(spacing: 16) {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.automatic)
                .keyboardShortcut(.escape)

                Spacer()

                Button("Add") {
                    onAdd(filterToAdd)
                    filterToAdd = FiltersSettingsView.FilterEntry(text: "")
                    isPresented = false
                }
                .buttonStyle(.automatic)
                .keyboardShortcut(.return)
                .disabled(filterToAdd.text.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }
}
