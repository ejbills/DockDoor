import AppKit
import Defaults
import Foundation
import ScreenCaptureKit

final class WindowSwitcherStateManager: ObservableObject {
    @Published private(set) var currentIndex: Int = -1
    @Published private(set) var windowIDs: [CGWindowID] = []
    @Published private(set) var isActive: Bool = false
    @Published private(set) var filteredIndices: [Int] = []

    private var isInitialized: Bool = false
    private var searchQuery: String = ""

    var hasActiveSearch: Bool {
        !searchQuery.isEmpty
    }

    func initializeWithWindows(_ newWindows: [WindowInfo]) {
        windowIDs = newWindows.map(\.id)
        isInitialized = true
        searchQuery = ""
        filteredIndices = Array(windowIDs.indices)

        if !windowIDs.isEmpty {
            if Defaults[.useClassicWindowOrdering], windowIDs.count >= 2 {
                currentIndex = 1
            } else {
                currentIndex = 0
            }
        } else {
            currentIndex = -1
        }

        isActive = true
    }

    func setSearchQuery(_ query: String, windows: [WindowInfo]) {
        searchQuery = query
        recomputeFilteredIndices(windows: windows)

        if hasActiveSearch {
            currentIndex = filteredIndices.first ?? -1
        } else if currentIndex < 0, !windowIDs.isEmpty {
            currentIndex = 0
        }
    }

    private func recomputeFilteredIndices(windows: [WindowInfo]) {
        guard !searchQuery.isEmpty else {
            filteredIndices = Array(windowIDs.indices)
            return
        }

        let query = searchQuery.lowercased()
        let fuzziness = Defaults[.searchFuzziness]

        filteredIndices = windows.enumerated().compactMap { idx, win in
            let appName = win.app.localizedName?.lowercased() ?? ""
            let windowTitle = (win.windowName ?? "").lowercased()
            return (StringMatchingUtil.fuzzyMatch(query: query, target: appName, fuzziness: fuzziness) ||
                StringMatchingUtil.fuzzyMatch(query: query, target: windowTitle, fuzziness: fuzziness)) ? idx : nil
        }
    }

    func setActive(_ active: Bool) {
        isActive = active
        if !active {
            currentIndex = -1
        }
    }

    func cycleForward() {
        guard !windowIDs.isEmpty else { return }

        if hasActiveSearch {
            cycleFilteredForward()
            return
        }

        if currentIndex < 0 {
            currentIndex = 0
            return
        }

        currentIndex = WindowPreviewHoverContainer.navigateWindowSwitcher(
            from: currentIndex,
            direction: .right,
            totalItems: windowIDs.count,
            dockPosition: .bottom,
            isWindowSwitcherActive: true
        )
    }

    func cycleBackward() {
        guard !windowIDs.isEmpty else { return }

        if hasActiveSearch {
            cycleFilteredBackward()
            return
        }

        if currentIndex < 0 {
            currentIndex = windowIDs.count - 1
            return
        }

        currentIndex = WindowPreviewHoverContainer.navigateWindowSwitcher(
            from: currentIndex,
            direction: .left,
            totalItems: windowIDs.count,
            dockPosition: .bottom,
            isWindowSwitcherActive: true
        )
    }

    private func cycleFilteredForward() {
        guard !filteredIndices.isEmpty else { return }

        if currentIndex < 0 {
            currentIndex = filteredIndices.first ?? 0
            return
        }

        if let currentPos = filteredIndices.firstIndex(of: currentIndex) {
            let nextPos = (currentPos + 1) % filteredIndices.count
            currentIndex = filteredIndices[nextPos]
        } else {
            currentIndex = filteredIndices.first ?? 0
        }
    }

    private func cycleFilteredBackward() {
        guard !filteredIndices.isEmpty else { return }

        if currentIndex < 0 {
            currentIndex = filteredIndices.last ?? 0
            return
        }

        if let currentPos = filteredIndices.firstIndex(of: currentIndex) {
            let prevPos = (currentPos - 1 + filteredIndices.count) % filteredIndices.count
            currentIndex = filteredIndices[prevPos]
        } else {
            currentIndex = filteredIndices.last ?? 0
        }
    }

    func navigateFiltered(direction: ArrowDirection) {
        guard !filteredIndices.isEmpty else { return }

        guard let currentFilteredPos = filteredIndices.firstIndex(of: currentIndex) else {
            currentIndex = filteredIndices.first ?? 0
            return
        }

        let newFilteredPos = WindowPreviewHoverContainer.navigateWindowSwitcher(
            from: currentFilteredPos,
            direction: direction,
            totalItems: filteredIndices.count,
            dockPosition: .bottom,
            isWindowSwitcherActive: true
        )

        currentIndex = filteredIndices[newFilteredPos]
    }

    func setIndex(_ index: Int) {
        guard !windowIDs.isEmpty else {
            currentIndex = -1
            return
        }

        currentIndex = max(0, min(index, windowIDs.count - 1))
    }

    func getCurrentWindow() -> WindowInfo? {
        guard currentIndex >= 0, currentIndex < windowIDs.count else { return nil }
        let windowID = windowIDs[currentIndex]

        // Simple lookup from global cache - if window doesn't exist, return nil
        let allWindows = WindowUtil.getAllWindowsOfAllApps()
        return allWindows.first(where: { $0.id == windowID })
    }

    func removeWindow(at index: Int) {
        guard index >= 0, index < windowIDs.count else { return }

        windowIDs.remove(at: index)

        if windowIDs.isEmpty {
            currentIndex = -1
            isActive = false
            return
        }

        if currentIndex == index {
            currentIndex = min(index, windowIDs.count - 1)
        } else if currentIndex > index {
            currentIndex -= 1
        }
    }

    func updateWindow(at index: Int, with newInfo: WindowInfo) {
        guard index >= 0, index < windowIDs.count else { return }
        windowIDs[index] = newInfo.id
    }

    func reset() {
        windowIDs.removeAll()
        filteredIndices.removeAll()
        searchQuery = ""
        currentIndex = -1
        isActive = false
        isInitialized = false
    }
}
