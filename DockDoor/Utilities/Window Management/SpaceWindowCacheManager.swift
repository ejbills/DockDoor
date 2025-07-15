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

        let removedWindows = oldWindowSet.subtracting(windowSet)
        notifyCoordinatorOfRemovedWindows(removedWindows)

        let addedWindows = windowSet.subtracting(oldWindowSet)
        notifyCoordinatorOfAddedWindows(addedWindows)
    }

    func updateCache(pid: pid_t, update: (inout Set<WindowInfo>) -> Void) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        var currentWindowSet = windowCache[pid] ?? []
        let oldWindowSet = currentWindowSet
        update(&currentWindowSet)
        windowCache[pid] = currentWindowSet

        let removedWindows = oldWindowSet.subtracting(currentWindowSet)
        notifyCoordinatorOfRemovedWindows(removedWindows)

        let addedWindows = currentWindowSet.subtracting(oldWindowSet)
        notifyCoordinatorOfAddedWindows(addedWindows)
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
        return Array(windowCache.values.flatMap { $0 }).sorted(by: { $0.lastAccessedTime > $1.lastAccessedTime })
    }
}
