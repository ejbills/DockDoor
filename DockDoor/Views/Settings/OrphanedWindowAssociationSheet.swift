import Defaults
import SwiftUI

struct OrphanedWindowAssociationSheet: View {
    @Binding var isPresented: Bool
    @Binding var orphanedWindowAssociations: [OrphanedWindowAssociation]

    @State private var orphanedWindows: [OrphanedWindowInfo] = []
    @State private var potentialApps: [PotentialAssociationApp] = []
    @State private var selectedWindows: Set<CGWindowID> = []
    @State private var selectedApp: PotentialAssociationApp?
    @State private var isLoading = false
    @State private var searchText = ""

    var filteredOrphanedWindows: [OrphanedWindowInfo] {
        if searchText.isEmpty {
            return orphanedWindows
        }
        return orphanedWindows.filter { window in
            window.windowTitle.localizedCaseInsensitiveContains(searchText) ||
                window.scAppBundleID.localizedCaseInsensitiveContains(searchText)
        }
    }

    var filteredPotentialApps: [PotentialAssociationApp] {
        if searchText.isEmpty {
            return potentialApps
        }
        return potentialApps.filter { app in
            app.localizedName.localizedCaseInsensitiveContains(searchText) ||
                app.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            if isLoading {
                loadingView
            } else {
                contentView
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .frame(width: 900, height: 650)
        .onAppear {
            Task {
                await loadData()
            }
        }
    }

    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Associate Orphaned Windows")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Connect orphaned windows with their corresponding dock applications")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Done") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            // Search and controls
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search windows or apps...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlColor))
                .cornerRadius(8)

                Button("Refresh") {
                    Task {
                        await loadData()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)
            }
        }
        .padding(20)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .controlSize(.large)

            Text("Scanning for orphaned windows...")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("This may take a moment while we analyze window associations")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private var contentView: some View {
        HStack(spacing: 0) {
            // Orphaned Windows Panel
            orphanedWindowsPanel

            Divider()

            // Apps Panel
            appsPanel
        }
    }

    private var orphanedWindowsPanel: some View {
        VStack(spacing: 0) {
            // Panel header
            HStack {
                Label("Orphaned Windows", systemImage: "questionmark.app.dashed")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                Text("\(filteredOrphanedWindows.count)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(NSColor.quaternaryLabelColor))
                    .cornerRadius(12)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(NSColor.separatorColor).opacity(0.5))

            // Windows list
            if filteredOrphanedWindows.isEmpty {
                emptyOrphanedWindowsView
            } else {
                orphanedWindowsList
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyOrphanedWindowsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)

            VStack(spacing: 8) {
                Text("No Orphaned Windows Found")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(searchText.isEmpty ?
                    "All windows appear to be properly associated with their applications." :
                    "No orphaned windows match your search criteria.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private var orphanedWindowsList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(filteredOrphanedWindows) { window in
                    orphanedWindowRow(window)
                }
            }
        }
    }

    private func orphanedWindowRow(_ window: OrphanedWindowInfo) -> some View {
        let isSelected = selectedWindows.contains(window.windowID)

        return HStack(spacing: 12) {
            Button(action: {
                if isSelected {
                    selectedWindows.remove(window.windowID)
                } else {
                    selectedWindows.insert(window.windowID)
                }
            }) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(window.windowTitle)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .foregroundColor(.primary)

                HStack(spacing: 12) {
                    Label("Bundle: \(window.scAppBundleID)", systemImage: "app.badge")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    Label("Size: \(Int(window.frame.width))×\(Int(window.frame.height))", systemImage: "aspectratio")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                if window.windowLayer != 0 {
                    Label("Layer: \(window.windowLayer)", systemImage: "square.stack")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelected {
                selectedWindows.remove(window.windowID)
            } else {
                selectedWindows.insert(window.windowID)
            }
        }
    }

    private var appsPanel: some View {
        VStack(spacing: 0) {
            // Panel header
            HStack {
                Label("Target Applications", systemImage: "app.connected.to.app.below.fill")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                if let selectedApp {
                    HStack(spacing: 6) {
                        Image(nsImage: selectedApp.icon)
                            .resizable()
                            .frame(width: 16, height: 16)
                        Text(selectedApp.localizedName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.2))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(NSColor.separatorColor).opacity(0.5))

            // Apps list
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(filteredPotentialApps) { app in
                        appRow(app)
                    }
                }
            }

            // Association controls
            associationControls
        }
        .frame(maxWidth: .infinity)
    }

    private func appRow(_ app: PotentialAssociationApp) -> some View {
        let isSelected = selectedApp?.bundleIdentifier == app.bundleIdentifier

        return HStack(spacing: 12) {
            Button(action: {
                selectedApp = isSelected ? nil : app
            }) {
                Image(systemName: isSelected ? "dot.radiowaves.left.and.right" : "circle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)

            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.localizedName)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .foregroundColor(.primary)

                Text(app.bundleIdentifier)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedApp = isSelected ? nil : app
        }
    }

    private var associationControls: some View {
        VStack(spacing: 12) {
            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(selectedWindows.count) windows selected")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if let selectedApp {
                        Text("Target: \(selectedApp.localizedName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No target application selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Button("Create Association") {
                    associateSelectedWindows()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedWindows.isEmpty || selectedApp == nil)
            }
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func loadData() async {
        isLoading = true
        selectedWindows.removeAll()
        selectedApp = nil
        searchText = ""

        async let orphanedWindowsTask = OrphanedWindowUtil.findOrphanedWindows()
        let potentialAppsTask = OrphanedWindowUtil.getPotentialAssociationApps()

        orphanedWindows = await orphanedWindowsTask
        potentialApps = potentialAppsTask

        isLoading = false
    }

    private func associateSelectedWindows() {
        guard let selectedApp else { return }

        for windowID in selectedWindows {
            if let window = orphanedWindows.first(where: { $0.windowID == windowID }) {
                let association = OrphanedWindowAssociation(
                    windowID: windowID,
                    windowTitle: window.windowTitle,
                    bundleIdentifier: selectedApp.bundleIdentifier,
                    processID: selectedApp.processID,
                    windowSize: window.frame.size,
                    windowLayer: window.windowLayer,
                    originalBundleID: window.scAppBundleID
                )

                // Remove existing association for this window if it exists
                orphanedWindowAssociations.removeAll { $0.windowID == windowID }
                // Add new association
                orphanedWindowAssociations.append(association)
            }
        }

        // Clear selections and refresh
        selectedWindows.removeAll()
        self.selectedApp = nil

        // Refresh the orphaned windows list
        Task {
            await loadData()
        }
    }
}
