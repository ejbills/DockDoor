import Defaults
import SwiftUI

class PreviewStateCoordinator: ObservableObject {
    @Published var currIndex: Int = 0
    @Published var windowSwitcherActive: Bool = false
    @Published var fullWindowPreviewActive: Bool = false
    @Published var windows: [WindowInfo] = []

    @Published var overallMaxPreviewDimension: CGPoint = .zero
    @Published var windowDimensionsMap: [Int: WindowPreviewHoverContainer.WindowDimensions] = [:]

    enum WindowState {
        case windowSwitcher
        case fullWindowPreview
        case both
    }

    func setShowing(_ state: WindowState? = .both, toState: Bool) {
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
    }

    func setIndex(to: Int) {
        currIndex = to
    }

    func setWindows(_ newWindows: [WindowInfo], dockPosition: DockPosition, bestGuessMonitor: NSScreen, isMockPreviewActive: Bool = false) {
        let filteredWindows = newWindows.filter { windowInfo in
            let isDockDoorApp = windowInfo.app.localizedName?.contains("DockDoor") ?? false
            if isDockDoorApp {
                // If it's DockDoor, only include it if its settings are visible
                return (NSApp.delegate as? AppDelegate)?.settingsWindowController.window?.isVisible ?? false
            }
            // If it's not DockDoor, always include it
            return true
        }

        windows = filteredWindows

        if currIndex >= windows.count {
            currIndex = max(0, windows.count - 1)
        }
        recomputeAndPublishDimensions(dockPosition: dockPosition, bestGuessMonitor: bestGuessMonitor, isMockPreviewActive: isMockPreviewActive)
    }

    func updateWindow(at index: Int, with newInfo: WindowInfo, dockPosition: DockPosition, bestGuessMonitor: NSScreen, isMockPreviewActive: Bool = false) {
        guard index >= 0, index < windows.count else { return }
        windows[index] = newInfo
    }

    func removeWindow(at index: Int, dockPosition: DockPosition, bestGuessMonitor: NSScreen, isMockPreviewActive: Bool = false) {
        guard index >= 0, index < windows.count else { return }
        windows.remove(at: index)
        if currIndex >= windows.count {
            currIndex = max(0, windows.count - 1)
        }
        if windows.isEmpty { SharedPreviewWindowCoordinator.activeInstance?.hideWindow() }
    }

    func removeAllWindows(dockPosition: DockPosition, bestGuessMonitor: NSScreen, isMockPreviewActive: Bool = false) {
        windows.removeAll()
        currIndex = 0
        SharedPreviewWindowCoordinator.activeInstance?.hideWindow()
    }

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
