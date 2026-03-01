import Defaults
import SwiftUI

// Pure UI state container for window preview presentation
class PreviewStateCoordinator: ObservableObject {
    @Published var currIndex: Int = -1
    @Published var windowSwitcherActive: Bool = false

    // MARK: - Keybind Session Tracking

    /// Tracks whether the window switcher was activated via keybind (not just visible)
    @Published private(set) var isKeybindSessionActive: Bool = false

    @MainActor
    func activateKeybindSession() {
        isKeybindSessionActive = true
    }

    @MainActor
    func deactivateKeybindSession() {
        isKeybindSessionActive = false
        searchQuery = ""
    }

    // MARK: - UI State

    @Published var hasMovedSinceOpen: Bool = false
    var initialHoverLocation: CGPoint?
    @Published var fullWindowPreviewActive: Bool = false
    @Published var windows: [WindowInfo] = []
    @Published var shouldScrollToIndex: Bool = true

    @Published var searchQuery: String = "" {
        didSet {
            if windowSwitcherActive {
                Task { @MainActor in
                    updateIndexForSearch()
                }
            }
        }
    }

    var hasActiveSearch: Bool {
        !searchQuery.isEmpty
    }

    @Published var overallMaxPreviewDimension: CGPoint = .zero
    @Published var windowDimensionsMap: [Int: WindowPreviewHoverContainer.WindowDimensions] = [:]
    @Published var effectiveGridColumns: Int = 1
    @Published var effectiveGridRows: Int = 1
    @Published var expectedContentSize: CGSize = .zero
    @Published var frameRefreshRequestId: UUID?
    private var lastKnownBestGuessMonitor: NSScreen?

    enum WindowState {
        case windowSwitcher
        case fullWindowPreview
        case both
    }

    @MainActor
    func setShowing(_ state: WindowState? = .both, toState: Bool) {
        let oldSwitcherState = windowSwitcherActive
        switch state {
        case .windowSwitcher:
            windowSwitcherActive = toState
        case .fullWindowPreview:
            fullWindowPreviewActive = toState
        case .both:
            windowSwitcherActive = toState
            fullWindowPreviewActive = toState
        case .none:
            return
        }

        if !oldSwitcherState, windowSwitcherActive {
            hasMovedSinceOpen = false
            initialHoverLocation = nil
        }

        // If window switcher state changed and we have windows, recalculate dimensions
        if oldSwitcherState != windowSwitcherActive, !windows.isEmpty {
            if let monitor = lastKnownBestGuessMonitor {
                let dockPosition = DockUtils.getDockPosition()
                recomputeAndPublishDimensions(dockPosition: dockPosition, bestGuessMonitor: monitor)
            }
        }
    }

    @MainActor
    func setIndex(to: Int, shouldScroll: Bool = true) {
        shouldScrollToIndex = shouldScroll
        if to >= 0, to < windows.count {
            currIndex = to
        } else {
            currIndex = -1
        }
    }

    @MainActor
    func setWindows(_ newWindows: [WindowInfo], dockPosition: DockPosition, bestGuessMonitor: NSScreen, isMockPreviewActive: Bool = false) {
        windows = newWindows
        lastKnownBestGuessMonitor = bestGuessMonitor

        if currIndex >= windows.count {
            currIndex = windows.isEmpty ? -1 : windows.count - 1
        }

        recomputeAndPublishDimensions(dockPosition: dockPosition, bestGuessMonitor: bestGuessMonitor, isMockPreviewActive: isMockPreviewActive)
    }

    /// Merges fresh windows into the current display without jarring replacement.
    /// Preserves window order and selected index where possible.
    @MainActor
    func mergeWindows(_ freshWindows: [WindowInfo], dockPosition: DockPosition, bestGuessMonitor: NSScreen) {
        guard !windows.isEmpty else {
            setWindows(freshWindows, dockPosition: dockPosition, bestGuessMonitor: bestGuessMonitor)
            return
        }

        let previousWindowCount = windows.count
        let selectedWindowID: CGWindowID? = (currIndex >= 0 && currIndex < windows.count) ? windows[currIndex].id : nil

        let freshWindowsByID: [CGWindowID: WindowInfo] = Dictionary(
            freshWindows.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let freshIDs = Set(freshWindowsByID.keys)
        let existingIDs = Set(windows.map(\.id))

        // Update existing windows in place
        for index in windows.indices {
            if let fresh = freshWindowsByID[windows[index].id] {
                windows[index] = fresh
            }
        }

        // Add new windows at the end
        for freshWindow in freshWindows where !existingIDs.contains(freshWindow.id) {
            windows.append(freshWindow)
        }

        // Remove stale windows
        let staleIDs = existingIDs.subtracting(freshIDs)
        if !staleIDs.isEmpty {
            windows.removeAll { staleIDs.contains($0.id) }
        }

        // Restore selection to the same window, or clamp if it was removed
        if let selectedID = selectedWindowID, let newIndex = windows.firstIndex(where: { $0.id == selectedID }) {
            currIndex = newIndex
        } else if currIndex >= windows.count {
            currIndex = windows.isEmpty ? -1 : windows.count - 1
        }

        lastKnownBestGuessMonitor = bestGuessMonitor
        recomputeAndPublishDimensions(dockPosition: dockPosition, bestGuessMonitor: bestGuessMonitor)

        if windows.count != previousWindowCount {
            frameRefreshRequestId = UUID()
        }
    }

    @MainActor
    func updateWindow(at index: Int, with newInfo: WindowInfo) {
        guard index >= 0, index < windows.count else { return }
        windows[index] = newInfo
    }

    @MainActor
    func removeWindow(at indexToRemove: Int) {
        guard indexToRemove >= 0, indexToRemove < windows.count else { return }

        let oldCurrIndex = currIndex
        windows.remove(at: indexToRemove)

        if windows.isEmpty {
            currIndex = -1
            SharedPreviewWindowCoordinator.activeInstance?.hideWindow()
            return
        }

        if oldCurrIndex == indexToRemove {
            currIndex = min(indexToRemove, windows.count - 1)
        } else if oldCurrIndex > indexToRemove {
            currIndex = oldCurrIndex - 1
        }

        if currIndex >= windows.count {
            currIndex = windows.count - 1
        }

        // Recompute dimensions and request frame refresh
        if let monitor = lastKnownBestGuessMonitor {
            let dockPosition = DockUtils.getDockPosition()
            recomputeAndPublishDimensions(dockPosition: dockPosition, bestGuessMonitor: monitor)
            frameRefreshRequestId = UUID()
        }
    }

    @MainActor
    func removeWindow(byAx ax: AXUIElement) {
        guard let indexToRemove = windows.firstIndex(where: { $0.axElement == ax }) else {
            return // Window not found
        }
        removeWindow(at: indexToRemove)
    }

    @MainActor
    func addWindows(_ newWindowsToAdd: [WindowInfo]) {
        guard !newWindowsToAdd.isEmpty else { return }
        // Gate additions by PID of the currently displayed windows (if any)
        guard let currentPid = windows.first?.app.processIdentifier else {
            // No active windows context; ignore additions to avoid cross-app injection
            return
        }
        let gated: [WindowInfo] = newWindowsToAdd.filter { $0.app.processIdentifier == currentPid }

        var windowsWereAdded = false
        for newWin in gated {
            if !windows.contains(where: { $0.id == newWin.id }) {
                windows.append(newWin)
                windowsWereAdded = true
            }
        }

        // Recompute dimensions if any windows were added
        if windowsWereAdded, let monitor = lastKnownBestGuessMonitor {
            let dockPosition = DockUtils.getDockPosition()
            recomputeAndPublishDimensions(dockPosition: dockPosition, bestGuessMonitor: monitor)
        }
    }

    @MainActor
    func removeAllWindows() {
        windows.removeAll()
        currIndex = -1 // Reset to no selection
        SharedPreviewWindowCoordinator.activeInstance?.hideWindow()
    }

    @MainActor
    func recomputeAndPublishDimensions(dockPosition: DockPosition, bestGuessMonitor: NSScreen, isMockPreviewActive: Bool = false) {
        let panelSize = getWindowSize()

        let newOverallMaxDimension = WindowPreviewHoverContainer.calculateOverallMaxDimensions(
            windows: windows,
            dockPosition: dockPosition,
            isWindowSwitcherActive: windowSwitcherActive,
            isMockPreviewActive: isMockPreviewActive,
            sharedPanelWindowSize: panelSize
        )

        let (cols, rows) = WindowPreviewHoverContainer.calculateEffectiveMaxColumnsAndRows(
            bestGuessMonitor: bestGuessMonitor,
            overallMaxDimensions: newOverallMaxDimension,
            dockPosition: dockPosition,
            isWindowSwitcherActive: windowSwitcherActive,
            previewMaxColumns: Defaults[.previewMaxColumns],
            previewMaxRows: Defaults[.previewMaxRows],
            switcherMaxRows: Defaults[.switcherMaxRows],
            totalItems: windows.count
        )

        let newDimensionsMap = WindowPreviewHoverContainer.precomputeWindowDimensions(
            windows: windows,
            overallMaxDimensions: newOverallMaxDimension,
            bestGuessMonitor: bestGuessMonitor,
            dockPosition: dockPosition,
            isWindowSwitcherActive: windowSwitcherActive,
            effectiveMaxColumns: cols,
            effectiveMaxRows: rows
        )

        overallMaxPreviewDimension = newOverallMaxDimension
        windowDimensionsMap = newDimensionsMap
        effectiveGridColumns = cols
        effectiveGridRows = rows

        if Defaults[.allowDynamicImageSizing], !windowSwitcherActive {
            expectedContentSize = Self.computeExpectedContentSize(
                windowCount: windows.count,
                dimensionsMap: newDimensionsMap,
                isHorizontal: dockPosition.isHorizontalFlow,
                maxColumns: cols,
                maxRows: rows
            )
        } else {
            expectedContentSize = .zero
        }
    }

    private static func computeExpectedContentSize(
        windowCount: Int,
        dimensionsMap: [Int: WindowPreviewHoverContainer.WindowDimensions],
        isHorizontal: Bool,
        maxColumns: Int,
        maxRows: Int
    ) -> CGSize {
        guard windowCount > 0 else { return .zero }

        let itemSpacing = HoverContainerPadding.itemSpacing
        let padding = HoverContainerPadding.totalPerSide()

        let chunks = WindowPreviewHoverContainer.chunkArray(
            items: Array(0 ..< windowCount),
            isHorizontal: isHorizontal,
            maxColumns: maxColumns,
            maxRows: maxRows
        )

        if isHorizontal {
            var maxRowWidth: CGFloat = 0

            for row in chunks {
                var rowWidth: CGFloat = 0
                for windowIndex in row {
                    let dims = dimensionsMap[windowIndex]
                    rowWidth += dims?.size.width ?? dims?.maxDimensions.width ?? 0
                }
                rowWidth += CGFloat(max(0, row.count - 1)) * itemSpacing
                maxRowWidth = max(maxRowWidth, rowWidth)
            }

            return CGSize(width: maxRowWidth + padding * 2, height: 0)
        } else {
            var maxColHeight: CGFloat = 0

            for col in chunks {
                var colHeight: CGFloat = 0
                for windowIndex in col {
                    let dims = dimensionsMap[windowIndex]
                    colHeight += dims?.size.height ?? dims?.maxDimensions.height ?? 0
                }
                colHeight += CGFloat(max(0, col.count - 1)) * itemSpacing
                maxColHeight = max(maxColHeight, colHeight)
            }

            return CGSize(width: 0, height: maxColHeight + padding * 2)
        }
    }

    @MainActor
    private func updateIndexForSearch() {
        if !hasActiveSearch {
            if currIndex >= windows.count {
                currIndex = windows.isEmpty ? -1 : 0
            }
        } else {
            let filtered = filteredWindowIndices()
            currIndex = filtered.first ?? -1
        }
    }

    /// Returns the indices of windows that match the current search query.
    /// If no search is active, returns all window indices.
    func filteredWindowIndices() -> [Int] {
        guard windowSwitcherActive, !searchQuery.isEmpty else {
            return Array(windows.indices)
        }

        let query = searchQuery.lowercased()
        let fuzziness = Defaults[.searchFuzziness]

        return windows.enumerated().compactMap { idx, win in
            let appName = win.app.localizedName?.lowercased() ?? ""
            let windowTitle = (win.windowName ?? "").lowercased()
            return (StringMatchingUtil.fuzzyMatch(query: query, target: appName, fuzziness: fuzziness) ||
                StringMatchingUtil.fuzzyMatch(query: query, target: windowTitle, fuzziness: fuzziness)) ? idx : nil
        }
    }

    // MARK: - Keyboard Navigation

    /// Cycle to the next window in the grid
    @MainActor
    func cycleForward() {
        guard !windows.isEmpty else { return }

        if hasActiveSearch {
            cycleFilteredForward()
            return
        }

        shouldScrollToIndex = true
        if currIndex < 0 {
            currIndex = 0
            return
        }

        let forwardDirection: ArrowDirection = .right
        currIndex = WindowPreviewHoverContainer.navigateWindowSwitcher(
            from: currIndex,
            direction: forwardDirection,
            totalItems: windows.count,
            dockPosition: .bottom,
            isWindowSwitcherActive: true
        )
    }

    /// Cycle to the previous window in the grid
    @MainActor
    func cycleBackward() {
        guard !windows.isEmpty else { return }

        if hasActiveSearch {
            cycleFilteredBackward()
            return
        }

        shouldScrollToIndex = true
        if currIndex < 0 {
            currIndex = windows.count - 1
            return
        }

        let backwardDirection: ArrowDirection = .left
        currIndex = WindowPreviewHoverContainer.navigateWindowSwitcher(
            from: currIndex,
            direction: backwardDirection,
            totalItems: windows.count,
            dockPosition: .bottom,
            isWindowSwitcherActive: true
        )
    }

    @MainActor
    private func cycleFilteredForward() {
        let filtered = filteredWindowIndices()
        guard !filtered.isEmpty else { return }

        shouldScrollToIndex = true
        if currIndex < 0 {
            currIndex = filtered.first ?? 0
            return
        }

        if let currentPos = filtered.firstIndex(of: currIndex) {
            let nextPos = (currentPos + 1) % filtered.count
            currIndex = filtered[nextPos]
        } else {
            currIndex = filtered.first ?? 0
        }
    }

    @MainActor
    private func cycleFilteredBackward() {
        let filtered = filteredWindowIndices()
        guard !filtered.isEmpty else { return }

        shouldScrollToIndex = true
        if currIndex < 0 {
            currIndex = filtered.last ?? 0
            return
        }

        if let currentPos = filtered.firstIndex(of: currIndex) {
            let prevPos = (currentPos - 1 + filtered.count) % filtered.count
            currIndex = filtered[prevPos]
        } else {
            currIndex = filtered.last ?? 0
        }
    }

    /// Navigate within filtered results using arrow direction
    @MainActor
    func navigateFiltered(direction: ArrowDirection) {
        let filtered = filteredWindowIndices()
        guard !filtered.isEmpty else { return }

        shouldScrollToIndex = true
        guard let currentFilteredPos = filtered.firstIndex(of: currIndex) else {
            currIndex = filtered.first ?? 0
            return
        }

        let newFilteredPos = WindowPreviewHoverContainer.navigateWindowSwitcher(
            from: currentFilteredPos,
            direction: direction,
            totalItems: filtered.count,
            dockPosition: .bottom,
            isWindowSwitcherActive: true
        )

        currIndex = filtered[newFilteredPos]
    }

    // MARK: - Window Switcher Initialization

    /// Initialize for window switcher keybind activation
    @MainActor
    func initializeForWindowSwitcher(with newWindows: [WindowInfo], dockPosition: DockPosition, bestGuessMonitor: NSScreen) {
        setWindows(newWindows, dockPosition: dockPosition, bestGuessMonitor: bestGuessMonitor)
        searchQuery = ""

        if !windows.isEmpty {
            if Defaults[.useClassicWindowOrdering], windows.count >= 2 {
                currIndex = 1
            } else {
                currIndex = 0
            }
        } else {
            currIndex = -1
        }
    }

    /// Get the currently selected window
    func getCurrentWindow() -> WindowInfo? {
        guard currIndex >= 0, currIndex < windows.count else { return nil }
        return windows[currIndex]
    }
}
