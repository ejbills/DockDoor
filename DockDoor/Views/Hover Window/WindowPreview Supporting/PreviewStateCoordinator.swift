import Defaults
import SwiftUI

// Manages window element states and presentation of window switcher (and associated cycling
class PreviewStateCoordinator: ObservableObject {
    @Published var currIndex: Int = -1
    @Published var windowSwitcherActive: Bool = false
    @Published var fullWindowPreviewActive: Bool = false
    @Published var windows: [WindowInfo] = []

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

        if windowSwitcherActive {
            if !oldSwitcherState || currIndex < 0 { // If just activated or was unselected
                if Defaults[.useClassicWindowOrdering], windows.count >= 2 {
                    currIndex = 1
                } else if !windows.isEmpty {
                    currIndex = 0
                } else {
                    currIndex = -1 // No windows to select
                }
            }
        } else {
            currIndex = -1 // Dock previews have no initial selection
        }
    }

    @MainActor
    func setIndex(to: Int) {
        // If window switcher is active, currIndex must be valid if windows exist
        if windowSwitcherActive {
            if !windows.isEmpty {
                currIndex = max(0, min(to, windows.count - 1))
            } else {
                currIndex = -1
            }
        } else {
            if to >= 0, to < windows.count {
                currIndex = to
            } else {
                currIndex = -1 // Allow unselecting or invalid index becomes -1
            }
        }
    }

    @MainActor
    func setWindows(_ newWindows: [WindowInfo], dockPosition: DockPosition, bestGuessMonitor: NSScreen, isMockPreviewActive: Bool = false) {
        windows = newWindows
        lastKnownBestGuessMonitor = bestGuessMonitor

        if windowSwitcherActive {
            if currIndex >= windows.count || (currIndex < 0 && !windows.isEmpty) {
                if Defaults[.useClassicWindowOrdering], windows.count >= 2 {
                    currIndex = 1
                } else if !windows.isEmpty {
                    currIndex = 0
                } else {
                    currIndex = -1
                }
            } else if windows.isEmpty { // If list became empty
                currIndex = -1
            }
        } else {
            // For dock previews, always reset to no initial selection when windows are set/reset
            currIndex = -1
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
        windowDimensionsMap.removeValue(forKey: indexToRemove)
        var newDimensionsMap: [Int: WindowPreviewHoverContainer.WindowDimensions] = [:]
        for (key, value) in windowDimensionsMap {
            if key < indexToRemove {
                newDimensionsMap[key] = value
            } else {
                newDimensionsMap[key - 1] = value
            }
        }
        windowDimensionsMap = newDimensionsMap

        let newWindowsCount = windows.count

        if newWindowsCount == 0 {
            currIndex = -1
            SharedPreviewWindowCoordinator.activeInstance?.hideWindow()
            return
        }

        if oldCurrIndex == indexToRemove {
            currIndex = min(indexToRemove, newWindowsCount - 1)
        } else if oldCurrIndex > indexToRemove {
            currIndex = oldCurrIndex - 1
        }

        if windowSwitcherActive {
            if currIndex < 0, newWindowsCount > 0 {
                currIndex = 0
            } else if currIndex >= newWindowsCount {
                currIndex = newWindowsCount - 1
            }
        } else {
            if currIndex >= newWindowsCount {
                currIndex = newWindowsCount - 1
            }
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

        guard let monitor = lastKnownBestGuessMonitor, overallMaxPreviewDimension != .zero else {
            // Add windows to the list but skip dimension calculation for now.
            // They will be processed in the next full setWindows call.
            for newWin in newWindowsToAdd {
                if !windows.contains(where: { $0.id == newWin.id }) {
                    windows.append(newWin)
                }
            }
            return
        }

        for newWin in newWindowsToAdd {
            if !windows.contains(where: { $0.id == newWin.id }) {
                windows.append(newWin)

                let newWindowIndex = windows.count - 1
                let singleWindowDimensions = WindowPreviewHoverContainer.calculateSingleWindowDimensions(
                    windowInfo: newWin,
                    overallMaxDimensions: overallMaxPreviewDimension,
                    bestGuessMonitor: monitor
                )
                windowDimensionsMap[newWindowIndex] = singleWindowDimensions
            }
        }
    }

    @MainActor
    func removeAllWindows() {
        windows.removeAll()
        currIndex = -1 // Reset to no selection
        SharedPreviewWindowCoordinator.activeInstance?.hideWindow()
    }

    @MainActor
    private func recomputeAndPublishDimensions(dockPosition: DockPosition, bestGuessMonitor: NSScreen, isMockPreviewActive: Bool = false) {
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
            bestGuessMonitor: bestGuessMonitor
        )

        overallMaxPreviewDimension = newOverallMaxDimension
        windowDimensionsMap = newDimensionsMap
    }
}
