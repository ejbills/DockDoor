import Defaults
import SwiftUI

extension Notification.Name {
    static let mouseHoverSelectionChanged = Notification.Name("mouseHoverSelectionChanged")
}

/// Pure UI state container for window preview presentation.
/// Manages both keyboard (focused) and mouse (hovered) selection states.
class PreviewStateCoordinator: ObservableObject {
    // MARK: - Selection State

    @Published var focusedIndex: Int = -1
    @Published var hoveredIndex: Int?

    /// Returns the effective current index based on last activity type.
    var currIndex: Int {
        switch lastActivityType {
        case .keyboard, .none:
            focusedIndex
        case .mouse:
            hoveredIndex ?? focusedIndex
        }
    }

    // MARK: - Window State

    @Published var windowSwitcherActive: Bool = false
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

    // MARK: - Layout State

    @Published var overallMaxPreviewDimension: CGPoint = .zero
    @Published var windowDimensionsMap: [Int: WindowPreviewHoverContainer.WindowDimensions] = [:]
    private var lastKnownBestGuessMonitor: NSScreen?

    // MARK: - Activity Tracking

    enum ActivityType {
        case none
        case keyboard
        case mouse
    }

    private(set) var lastActivityType: ActivityType = .none

    private func postMouseHoverNotification() {
        NotificationCenter.default.post(name: .mouseHoverSelectionChanged, object: nil)
    }

    // MARK: - Mouse Hover Tracking

    private var initialMousePosition: CGPoint?
    private(set) var isMouseHoverEnabled: Bool = false
    private let mouseMovementThreshold: CGFloat = 0.001
    private var pendingHoverIndex: Int?
    private var mouseMovedMonitor: Any?

    @MainActor
    func recordInitialMousePosition() {
        initialMousePosition = NSEvent.mouseLocation
        isMouseHoverEnabled = false
        pendingHoverIndex = nil
        startMouseMovedMonitor()
    }

    @MainActor
    private func startMouseMovedMonitor() {
        stopMouseMovedMonitor()
        mouseMovedMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.handleMouseMoved()
            return event
        }
    }

    @MainActor
    private func stopMouseMovedMonitor() {
        if let monitor = mouseMovedMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMovedMonitor = nil
        }
    }

    @MainActor
    private func handleMouseMoved() {
        guard windowSwitcherActive else {
            stopMouseMovedMonitor()
            return
        }

        if !isMouseHoverEnabled {
            _ = checkAndEnableMouseHover()
        } else if hoveredIndex != nil {
            lastActivityType = .mouse
            postMouseHoverNotification()
        }
    }

    @MainActor
    func checkAndEnableMouseHover() -> Bool {
        guard !isMouseHoverEnabled else { return true }
        guard let initial = initialMousePosition else {
            isMouseHoverEnabled = true
            return true
        }

        let current = NSEvent.mouseLocation
        let dx = abs(current.x - initial.x)
        let dy = abs(current.y - initial.y)

        if dx > mouseMovementThreshold || dy > mouseMovementThreshold {
            isMouseHoverEnabled = true
            if let pending = pendingHoverIndex {
                setIndex(to: pending, source: .mouse)
                pendingHoverIndex = nil
            }
            return true
        }
        return false
    }

    @MainActor
    func setPendingHoverIndex(_ index: Int?) {
        pendingHoverIndex = index
    }

    @MainActor
    func resetMouseHoverTracking() {
        initialMousePosition = nil
        isMouseHoverEnabled = false
        pendingHoverIndex = nil
        stopMouseMovedMonitor()
    }

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
            recordInitialMousePosition()
        } else if oldSwitcherState, !windowSwitcherActive {
            resetMouseHoverTracking()
        }

        if oldSwitcherState != windowSwitcherActive, !windows.isEmpty {
            if let monitor = lastKnownBestGuessMonitor {
                let dockPosition = DockUtils.getDockPosition()
                recomputeAndPublishDimensions(dockPosition: dockPosition, bestGuessMonitor: monitor)
            }
        }
    }

    @MainActor
    func setIndex(to: Int, shouldScroll: Bool = true, source: ActivityType = .keyboard) {
        shouldScrollToIndex = shouldScroll
        lastActivityType = source

        let validIndex = (to >= 0 && to < windows.count) ? to : -1

        switch source {
        case .keyboard, .none:
            focusedIndex = validIndex
        case .mouse:
            hoveredIndex = validIndex >= 0 ? validIndex : nil
            postMouseHoverNotification()
        }
    }

    @MainActor
    func setFocusedIndex(to: Int, shouldScroll: Bool = true) {
        setIndex(to: to, shouldScroll: shouldScroll, source: .keyboard)
    }

    @MainActor
    func setHoveredIndex(to: Int?) {
        lastActivityType = .mouse
        hoveredIndex = to
        if to != nil {
            postMouseHoverNotification()
        }
    }

    @MainActor
    func clearHoveredIndex() {
        hoveredIndex = nil
        if lastActivityType == .mouse {
            lastActivityType = .keyboard
        }
    }

    @MainActor
    func setWindows(_ newWindows: [WindowInfo], dockPosition: DockPosition, bestGuessMonitor: NSScreen, isMockPreviewActive: Bool = false) {
        windows = newWindows
        lastKnownBestGuessMonitor = bestGuessMonitor

        if focusedIndex >= windows.count {
            focusedIndex = windows.isEmpty ? -1 : windows.count - 1
        }
        if let hovered = hoveredIndex, hovered >= windows.count {
            hoveredIndex = nil
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

        let oldFocusedIndex = focusedIndex
        windows.remove(at: indexToRemove)

        if windows.isEmpty {
            focusedIndex = -1
            hoveredIndex = nil
            SharedPreviewWindowCoordinator.activeInstance?.hideWindow()
            return
        }

        if oldFocusedIndex == indexToRemove {
            focusedIndex = min(indexToRemove, windows.count - 1)
        } else if oldFocusedIndex > indexToRemove {
            focusedIndex = oldFocusedIndex - 1
        }

        if focusedIndex >= windows.count {
            focusedIndex = windows.count - 1
        }

        // Clear hovered index if it was the removed window
        if let hovered = hoveredIndex {
            if hovered == indexToRemove {
                hoveredIndex = nil
            } else if hovered > indexToRemove {
                hoveredIndex = hovered - 1
            }
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
        focusedIndex = -1
        hoveredIndex = nil
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
            if focusedIndex >= windows.count {
                focusedIndex = windows.isEmpty ? -1 : 0
            }
        } else {
            let query = searchQuery.lowercased()
            let filteredIndices = windows.enumerated().compactMap { idx, win in
                let appName = win.app.localizedName?.lowercased() ?? ""
                let windowTitle = (win.windowName ?? "").lowercased()
                return (appName.contains(query) || windowTitle.contains(query)) ? idx : nil
            }
            focusedIndex = filteredIndices.first ?? -1
        }
        // Clear hover when search changes
        hoveredIndex = nil
    }
}
