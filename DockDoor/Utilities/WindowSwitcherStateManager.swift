import Defaults
import Foundation
import ScreenCaptureKit

final class WindowSwitcherStateManager: ObservableObject {
    @Published private(set) var currentIndex: Int = -1
    @Published private(set) var windowIDs: [CGWindowID] = []
    @Published private(set) var isActive: Bool = false

    private var isInitialized: Bool = false

    func initializeWithWindows(_ newWindows: [WindowInfo]) {
        windowIDs = newWindows.map(\.id)
        isInitialized = true

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

    func setActive(_ active: Bool) {
        isActive = active
        if !active {
            currentIndex = -1
        }
    }

    func cycleForward() {
        guard !windowIDs.isEmpty else { return }

        if currentIndex < 0 {
            currentIndex = 0
        } else {
            currentIndex = (currentIndex + 1) % windowIDs.count
        }
    }

    func cycleBackward() {
        guard !windowIDs.isEmpty else { return }

        if currentIndex < 0 {
            currentIndex = windowIDs.count - 1
        } else {
            currentIndex = (currentIndex - 1 + windowIDs.count) % windowIDs.count
        }
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
        currentIndex = -1
        isActive = false
        isInitialized = false
    }
}
