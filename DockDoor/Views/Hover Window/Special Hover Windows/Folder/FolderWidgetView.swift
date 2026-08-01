import Defaults
import SwiftUI

struct FolderWidgetContainerView: View {
    let folderURL: URL
    let folderName: String
    let bestGuessMonitor: NSScreen
    let dockPosition: DockPosition
    let dockItemElement: AXUIElement?
    let backgroundAppearance: BackgroundAppearance

    var body: some View {
        BaseHoverContainer(
            bestGuessMonitor: bestGuessMonitor,
            content: {
                FolderWidgetPanelView(folderURL: folderURL, folderName: folderName)
                    .overlay {
                        WindowDismissalContainer(
                            appName: folderName,
                            bestGuessMonitor: bestGuessMonitor,
                            dockPosition: dockPosition,
                            dockItemElement: dockItemElement,
                            minimizeAllWindowsCallback: { _ in }
                        )
                        .allowsHitTesting(false)
                    }
            },
            isWidget: true,
            backgroundAppearance: backgroundAppearance
        )
    }
}

struct FolderWidgetPanelView: View {
    let folderURL: URL
    let folderName: String

    @Default(.folderWidgetDefaultSortOrder) private var defaultSortOrder
    @Default(.folderWidgetDefaultSortReversed) private var defaultSortReversed
    @Default(.folderWidgetRememberSortPerFolder) private var rememberSortPerFolder
    @Default(.folderWidgetSortOrders) private var folderSortOrders
    @Default(.folderWidgetSortReversed) private var folderSortReversed
    @Default(.folderWidgetShowHiddenFiles) private var showHiddenFiles
    @Default(.showAnimations) private var showAnimations

    @State private var navigationStack: [FolderWidgetLevel] = []

    private let panelWidth: CGFloat = 360
    private let contentHeight: CGFloat = 336

    private var currentURL: URL {
        navigationStack.last?.url ?? folderURL
    }

    private var currentName: String {
        navigationStack.last?.name ?? folderName
    }

    private var sortOrder: FolderWidgetSortOrder {
        guard rememberSortPerFolder else { return defaultSortOrder }
        return folderSortOrders[currentURL.path] ?? defaultSortOrder
    }

    private var isSortReversed: Bool {
        guard rememberSortPerFolder else { return defaultSortReversed }
        return folderSortReversed[currentURL.path] ?? defaultSortReversed
    }

    var body: some View {
        VStack(spacing: 10) {
            header
            sortControls

            ZStack {
                FolderWidgetListView(
                    url: currentURL,
                    sortOrder: sortOrder,
                    isSortReversed: isSortReversed,
                    showHiddenFiles: showHiddenFiles,
                    contentHeight: contentHeight,
                    onOpenFolder: navigateIntoFolder
                )
                .id(currentURL.path)
                .transition(.opacity)
            }
            .frame(height: contentHeight)
            .animation(navigationAnimation, value: currentURL.path)
        }
        .frame(width: panelWidth)
        .globalPadding(20)
    }

    private var navigationAnimation: Animation? {
        showAnimations ? .smooth(duration: 0.25) : nil
    }

    private var header: some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: currentURL.path))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text(currentName)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text(String(localized: "Folder"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .id(currentURL.path)
            .transition(.opacity)

            Spacer(minLength: 8)

            Button {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: currentURL.path)
                SharedPreviewWindowCoordinator.activeInstance?.hideWindow()
            } label: {
                Image(systemName: "arrow.up.forward.square")
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(String(localized: "Open in Finder"))
        }
        .frame(height: 44)
    }

    private var sortControls: some View {
        HStack(spacing: 6) {
            if !navigationStack.isEmpty {
                Button {
                    navigateBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 30, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(String(localized: "Back"))
                .transition(.scale(scale: 0.6).combined(with: .opacity))
            }

            Menu {
                ForEach(FolderWidgetSortOrder.allCases, id: \.self) { order in
                    Button {
                        setSortOrder(order)
                    } label: {
                        Label(order.localizedName, systemImage: order == sortOrder ? "checkmark" : order.iconName)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: sortOrder.iconName)
                    Text(sortOrder.localizedName)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .font(.caption)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                setSortReversed(!isSortReversed)
            } label: {
                Image(systemName: isSortReversed ? "arrow.down" : "arrow.up")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 30, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(isSortReversed ? String(localized: "Descending") : String(localized: "Ascending"))

            Toggle(isOn: $showHiddenFiles) {
                Image(systemName: showHiddenFiles ? "eye" : "eye.slash")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 30, height: 28)
            }
            .toggleStyle(.button)
            .labelsHidden()
            .help(String(localized: "Show hidden files"))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func setSortOrder(_ order: FolderWidgetSortOrder) {
        if rememberSortPerFolder {
            folderSortOrders[currentURL.path] = order
        } else {
            defaultSortOrder = order
        }
    }

    private func setSortReversed(_ reversed: Bool) {
        if rememberSortPerFolder {
            folderSortReversed[currentURL.path] = reversed
        } else {
            defaultSortReversed = reversed
        }
    }

    private func navigateIntoFolder(_ item: FolderWidgetItem) {
        if let url = FolderWidgetAuthorization.accessibleURL(for: item.url) {
            push(FolderWidgetLevel(url: url, name: item.name))
        } else if let url = FolderWidgetAuthorization.requestAccess(to: item.url) {
            push(FolderWidgetLevel(url: url, name: item.name))
        }
    }

    private func push(_ level: FolderWidgetLevel) {
        withAnimation(showAnimations ? .smooth(duration: 0.25) : nil) {
            navigationStack.append(level)
        }
    }

    private func navigateBack() {
        withAnimation(showAnimations ? .smooth(duration: 0.25) : nil) {
            _ = navigationStack.popLast()
        }
    }
}

private struct FolderWidgetListView: View {
    let url: URL
    let sortOrder: FolderWidgetSortOrder
    let isSortReversed: Bool
    let showHiddenFiles: Bool
    let contentHeight: CGFloat
    let onOpenFolder: (FolderWidgetItem) -> Void

    @Default(.showAnimations) private var showAnimations

    @State private var accessState: FolderWidgetAccessState = .loading
    @State private var sortedItems: [FolderWidgetItem] = []
    @State private var hasCompletedInitialLoad = false

    private let rowHeight: CGFloat = 48

    var body: some View {
        content
            .task {
                await reload()
            }
            .onChange(of: showHiddenFiles) { _ in
                Task { await reload() }
            }
            .onChange(of: sortOrder) { newOrder in
                resort(order: newOrder, reversed: isSortReversed)
            }
            .onChange(of: isSortReversed) { newReversed in
                resort(order: sortOrder, reversed: newReversed)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch accessState {
        case .loading:
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity)
                .frame(height: contentHeight)
        case let .accessible(items):
            if items.isEmpty {
                stateView(
                    systemName: "folder",
                    title: String(localized: "Empty folder"),
                    message: String(localized: "There are no visible items in this folder.")
                )
            } else {
                itemList
            }
        case .permissionDenied:
            stateView(
                systemName: "lock.fill",
                title: String(localized: "Folder Access Required"),
                message: String(localized: "Choose this folder to let DockDoor show its contents."),
                buttonTitle: String(localized: "Allow Access..."),
                action: requestFolderAccess
            )
        case .missing:
            stateView(
                systemName: "questionmark.folder",
                title: String(localized: "Folder Not Found"),
                message: String(localized: "This Dock folder no longer exists.")
            )
        case .failed:
            stateView(
                systemName: "exclamationmark.triangle",
                title: String(localized: "Unable to Load Folder"),
                message: String(localized: "DockDoor could not read this folder.")
            )
        }
    }

    private var itemList: some View {
        let cornerRadius: CGFloat = 16
        let shouldFeather = CGFloat(sortedItems.count) * (rowHeight + 6) > contentHeight

        return ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.gray.opacity(0.08))

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(sortedItems) { item in
                        FolderWidgetItemRow(item: item) {
                            if item.isDirectory {
                                onOpenFolder(item)
                            } else {
                                NSWorkspace.shared.open(item.url)
                                SharedPreviewWindowCoordinator.activeInstance?.hideWindow()
                            }
                        }
                    }
                }
                .padding(8)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabledIfAvailable()
            .fadeOnEdges(axis: .vertical, fadeLength: 18, disable: !shouldFeather)
        }
        .frame(height: contentHeight)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private func stateView(
        systemName: String,
        title: String,
        message: String,
        buttonTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemName)
                .font(.title2)
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let buttonTitle, let action {
                Button(buttonTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: contentHeight)
        .padding(.horizontal, 14)
        .background(Color.gray.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func reload() async {
        await MainActor.run { applyContentChange { accessState = .loading } }

        let urlToLoad = FolderWidgetAuthorization.resolvedAuthorizedURL(for: url) ?? url
        let didStartAccessing = urlToLoad.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                urlToLoad.stopAccessingSecurityScopedResource()
            }
        }

        let result = await FolderWidgetLoader.loadItems(from: urlToLoad, showHiddenFiles: showHiddenFiles)
        await MainActor.run {
            applyContentChange { accessState = result }
            resort(order: sortOrder, reversed: isSortReversed)
        }
    }

    private func applyContentChange(_ change: () -> Void) {
        if showAnimations, hasCompletedInitialLoad {
            withAnimation(.smooth(duration: 0.25), change)
        } else {
            change()
        }
    }

    private func resort(order: FolderWidgetSortOrder, reversed: Bool) {
        guard case let .accessible(items) = accessState else {
            sortedItems = []
            return
        }

        Task.detached(priority: .userInitiated) {
            let sorted = Self.sort(items, order: order, reversed: reversed)
            await MainActor.run {
                applyContentChange { sortedItems = sorted }
                hasCompletedInitialLoad = true
            }
        }
    }

    private static func sort(_ items: [FolderWidgetItem], order: FolderWidgetSortOrder, reversed: Bool) -> [FolderWidgetItem] {
        var sorted = items.sorted { lhs, rhs in
            switch order {
            case .dateModified:
                lhs.modifiedDate < rhs.modifiedDate
            case .dateAdded:
                lhs.addedDate < rhs.addedDate
            case .name:
                lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            case .kind:
                lhs.localizedKind.localizedStandardCompare(rhs.localizedKind) == .orderedAscending
            case .size:
                lhs.size < rhs.size
            }
        }

        if reversed {
            sorted.reverse()
        }

        return sorted
    }

    private func requestFolderAccess() {
        guard FolderWidgetAuthorization.requestAccess(to: url) != nil else { return }
        Task { await reload() }
    }
}

private struct FolderWidgetItemRow: View {
    let item: FolderWidgetItem
    let action: () -> Void

    @Default(.showAnimations) private var showAnimations

    @State private var icon: NSImage?
    @State private var isHovering = false

    private static let modifiedFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Group {
                    if let icon {
                        Image(nsImage: icon)
                            .resizable()
                            .scaledToFit()
                            .transition(.opacity)
                    } else {
                        Color.clear
                    }
                }
                .frame(width: 28, height: 28)
                .animation(showAnimations ? .easeIn(duration: 0.12) : nil, value: icon)
                .onAppear { loadIcon() }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 8)

                if item.isDirectory {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.gray.opacity(isHovering ? 0.24 : 0.14))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(isHovering ? 0.14 : 0.08), lineWidth: 1)
        }
        .onHover { hovering in
            withAnimation(showAnimations ? .snappy(duration: 0.175) : nil) {
                isHovering = hovering
            }
        }
        .onDrag {
            NSItemProvider(object: item.url as NSURL)
        }
    }

    private var subtitle: String {
        let modified = Self.modifiedFormatter.localizedString(for: item.modifiedDate, relativeTo: Date())
        if item.localizedKind.isEmpty {
            return modified
        }
        return "\(item.localizedKind) - \(modified)"
    }

    private func loadIcon() {
        DispatchQueue.global(qos: .userInitiated).async {
            let loaded = NSWorkspace.shared.icon(forFile: item.url.path)
            DispatchQueue.main.async {
                if icon != loaded { icon = loaded }
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func scrollClipDisabledIfAvailable() -> some View {
        if #available(macOS 14.0, *) {
            scrollClipDisabled()
        } else {
            self
        }
    }
}

private struct FolderWidgetLevel: Hashable {
    let url: URL
    let name: String
}
