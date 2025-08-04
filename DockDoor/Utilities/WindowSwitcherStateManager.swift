import Defaults
import Foundation

final class WindowSwitcherStateManager: ObservableObject {
    @Published private(set) var currentIndex: Int = -1
    @Published private(set) var windows: [WindowInfo] = []
    @Published private(set) var isActive: Bool = false

    private var isInitialized: Bool = false

    func initializeWithWindows(_ newWindows: [WindowInfo]) {
        windows = newWindows
        isInitialized = true

        if !windows.isEmpty {
            if Defaults[.useClassicWindowOrdering], windows.count >= 2 {
                currentIndex = 1
            } else {
                currentIndex = 0
            }
        } else {
            currentIndex = -1
        }

        isActive = true
    }

    func setActive(_ active: Bool) {
        isActive = active
        if !active {
            currentIndex = -1
        }
    }

    func cycleForward() {
        guard !windows.isEmpty else { return }

        if currentIndex < 0 {
            currentIndex = 0
        } else {
            currentIndex = (currentIndex + 1) % windows.count
        }
    }

    func cycleBackward() {
        guard !windows.isEmpty else { return }

        if currentIndex < 0 {
            currentIndex = windows.count - 1
        } else {
            currentIndex = (currentIndex - 1 + windows.count) % windows.count
        }
    }

    func setIndex(_ index: Int) {
        guard !windows.isEmpty else {
            currentIndex = -1
            return
        }

        currentIndex = max(0, min(index, windows.count - 1))
    }

    func getCurrentWindow() -> WindowInfo? {
        guard currentIndex >= 0, currentIndex < windows.count else { return nil }
        return windows[currentIndex]
    }

    func removeWindow(at index: Int) {
        guard index >= 0, index < windows.count else { return }

        windows.remove(at: index)

        if windows.isEmpty {
            currentIndex = -1
            isActive = false
            return
        }

        if currentIndex == index {
            currentIndex = min(index, windows.count - 1)
        } else if currentIndex > index {
            currentIndex -= 1
        }
    }

    func updateWindow(at index: Int, with newInfo: WindowInfo) {
        guard index >= 0, index < windows.count else { return }
        windows[index] = newInfo
    }

    func reset() {
        windows.removeAll()
        currentIndex = -1
        isActive = false
        isInitialized = false
    }
}
