import Cocoa
import Defaults
import ScreenCaptureKit
import SwiftUI

class SpaceWindowCacheManager {
    private var windowCache: [pid_t: Set<WindowInfo>] = [:]
    private let cacheLock = NSLock()

    private func notifyCoordinatorOfRemovedWindows(_ removedWindows: Set<WindowInfo>) {
        if !removedWindows.isEmpty {
            DispatchQueue.main.async { [weak self] in
                guard self != nil else { return }
                if let coordinator = SharedPreviewWindowCoordinator.activeInstance?.windowSwitcherCoordinator {
                    for removedWindow in removedWindows {
                        coordinator.removeWindow(byAx: removedWindow.axElement)
                    }
                }
            }
        }
    }

    private func notifyCoordinatorOfAddedWindows(_ addedWindows: Set<WindowInfo>) {
        if !addedWindows.isEmpty {
            DispatchQueue.main.async { [weak self] in
                guard self != nil else { return }
                if let coordinator = SharedPreviewWindowCoordinator.activeInstance?.windowSwitcherCoordinator {
                    coordinator.addWindows(Array(addedWindows))
                }
            }
        }
    }

    private func notifyCoordinatorOfUpdatedWindows(_ updatedWindows: [WindowInfo]) {
        if !updatedWindows.isEmpty {
            DispatchQueue.main.async { [weak self] in
                guard self != nil else { return }
                if let coordinator = SharedPreviewWindowCoordinator.activeInstance?.windowSwitcherCoordinator {
                    for updatedWindow in updatedWindows {
                        if let index = coordinator.windows.firstIndex(where: { $0.id == updatedWindow.id }) {
                            coordinator.updateWindow(at: index, with: updatedWindow)
                        }
                    }
                }
            }
        }
    }

    func readCache(pid: pid_t) -> Set<WindowInfo> {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return windowCache[pid] ?? []
    }

    func writeCache(pid: pid_t, windowSet: Set<WindowInfo>) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        let oldWindowSet = windowCache[pid] ?? []
        windowCache[pid] = windowSet

        let oldWindowIDs = Set(oldWindowSet.map(\.id))
        let newWindowIDs = Set(windowSet.map(\.id))

        let removedWindowIDs = oldWindowIDs.subtracting(newWindowIDs)
        let removedWindows = oldWindowSet.filter { removedWindowIDs.contains($0.id) }
        notifyCoordinatorOfRemovedWindows(Set(removedWindows))

        let addedWindowIDs = newWindowIDs.subtracting(oldWindowIDs)
        let addedWindows = windowSet.filter { addedWindowIDs.contains($0.id) }
        notifyCoordinatorOfAddedWindows(Set(addedWindows))

        let persistingWindowIDs = oldWindowIDs.intersection(newWindowIDs)
        var updatedWindows: [WindowInfo] = []

        for windowID in persistingWindowIDs {
            if let oldWindow = oldWindowSet.first(where: { $0.id == windowID }),
               let newWindow = windowSet.first(where: { $0.id == windowID }),
               oldWindow != newWindow
            {
                updatedWindows.append(newWindow)
            }
        }

        notifyCoordinatorOfUpdatedWindows(updatedWindows)
    }

    func updateCache(pid: pid_t, update: (inout Set<WindowInfo>) -> Void) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        var currentWindowSet = windowCache[pid] ?? []
        let oldWindowSet = currentWindowSet
        update(&currentWindowSet)
        windowCache[pid] = currentWindowSet

        let oldWindowIDs = Set(oldWindowSet.map(\.id))
        let newWindowIDs = Set(currentWindowSet.map(\.id))

        let removedWindowIDs = oldWindowIDs.subtracting(newWindowIDs)
        let removedWindows = oldWindowSet.filter { removedWindowIDs.contains($0.id) }
        notifyCoordinatorOfRemovedWindows(Set(removedWindows))

        let addedWindowIDs = newWindowIDs.subtracting(oldWindowIDs)
        let addedWindows = currentWindowSet.filter { addedWindowIDs.contains($0.id) }
        notifyCoordinatorOfAddedWindows(Set(addedWindows))

        let persistingWindowIDs = oldWindowIDs.intersection(newWindowIDs)
        var updatedWindows: [WindowInfo] = []

        for windowID in persistingWindowIDs {
            if let oldWindow = oldWindowSet.first(where: { $0.id == windowID }),
               let newWindow = currentWindowSet.first(where: { $0.id == windowID }),
               oldWindow != newWindow
            {
                updatedWindows.append(newWindow)
            }
        }

        notifyCoordinatorOfUpdatedWindows(updatedWindows)
    }

    func removeFromCache(pid: pid_t, windowId: CGWindowID) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if var windowSet = windowCache[pid],
           let windowToRemove = windowSet.first(where: { $0.id == windowId })
        {
            windowSet.remove(windowToRemove)
            if windowSet.isEmpty {
                windowCache.removeValue(forKey: pid)
            } else {
                windowCache[pid] = windowSet
            }
            notifyCoordinatorOfRemovedWindows([windowToRemove])
        }
    }

    func getAllWindows() -> [WindowInfo] {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        let sortOrder: (WindowInfo, WindowInfo) -> Bool = if Defaults[.sortWindowsByDate] {
            Defaults[.showOldestWindowsFirst]
                ? { $0.lastAccessedTime < $1.lastAccessedTime }
                : { $0.lastAccessedTime > $1.lastAccessedTime }
        } else {
            Defaults[.showOldestWindowsFirst]
                ? { $0.id < $1.id }
                : { $0.id > $1.id }
        }

        return Array(windowCache.values.flatMap { $0 }).sorted(by: sortOrder)
    }
}
