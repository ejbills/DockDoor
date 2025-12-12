import Defaults
import SwiftUI

// Pure UI state container for window preview presentation
class PreviewStateCoordinator: ObservableObject {
    @Published var currIndex: Int = -1
    @Published var windowSwitcherActive: Bool = false

    @Published var hasMovedSinceOpen: Bool = false
    @Published var lastInputWasKeyboard: Bool = true
    var initialHoverLocation: CGPoint?
    @Published var isKeyboardScrolling: Bool = false
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
            lastInputWasKeyboard = true
            initialHoverLocation = nil
            isKeyboardScrolling = false
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
    func setIndex(to: Int, shouldScroll: Bool = true, fromKeyboard: Bool = true) {
        shouldScrollToIndex = shouldScroll
        lastInputWasKeyboard = fromKeyboard
        if fromKeyboard {
            initialHoverLocation = nil
            hasMovedSinceOpen = false
        }
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

        // Recompute dimensions after removing window
        if let monitor = lastKnownBestGuessMonitor {
            let dockPosition = DockUtils.getDockPosition()
            recomputeAndPublishDimensions(dockPosition: dockPosition, bestGuessMonitor: monitor)
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

        let newDimensionsMap = WindowPreviewHoverContainer.precomputeWindowDimensions(
            windows: windows,
            overallMaxDimensions: newOverallMaxDimension,
            bestGuessMonitor: bestGuessMonitor,
            dockPosition: dockPosition,
            isWindowSwitcherActive: windowSwitcherActive,
            previewMaxColumns: Defaults[.previewMaxColumns],
            previewMaxRows: Defaults[.previewMaxRows],
            switcherMaxRows: Defaults[.switcherMaxRows]
        )

        overallMaxPreviewDimension = newOverallMaxDimension
        windowDimensionsMap = newDimensionsMap
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
}
