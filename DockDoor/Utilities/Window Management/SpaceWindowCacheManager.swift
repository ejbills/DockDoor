import Cocoa
import Defaults
import ScreenCaptureKit
import SwiftUI

class SpaceWindowCacheManager {
    private var windowCache: [pid_t: Set<WindowInfo>] = [:]
    private var coordinatorNotificationSuppressionCounts: [pid_t: Int] = [:]
    private let cacheLock = NSLock()

    private func logSuppressedCoordinatorPublish(pid: pid_t, reason: String, oldCount: Int, newCount: Int, depth: Int) {
        DebugLogger.log(
            "WindowCachePublish",
            details: "suppressed \(reason), PID: \(pid), old: \(oldCount), new: \(newCount), depth: \(depth)"
        )
    }

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

    func withCoordinatorNotificationsSuppressed<T>(
        for pid: pid_t,
        operation: () async throws -> T
    ) async throws -> T {
        cacheLock.lock()
        let depth = coordinatorNotificationSuppressionCounts[pid, default: 0] + 1
        coordinatorNotificationSuppressionCounts[pid] = depth
        cacheLock.unlock()
        DebugLogger.log("WindowCachePublish", details: "suppress begin, PID: \(pid), depth: \(depth)")

        defer {
            var remainingCount = 0
            cacheLock.lock()
            remainingCount = (coordinatorNotificationSuppressionCounts[pid] ?? 1) - 1
            if remainingCount > 0 {
                coordinatorNotificationSuppressionCounts[pid] = remainingCount
            } else {
                coordinatorNotificationSuppressionCounts.removeValue(forKey: pid)
            }
            cacheLock.unlock()
            DebugLogger.log("WindowCachePublish", details: "suppress end, PID: \(pid), depth: \(remainingCount)")
        }

        return try await operation()
    }

    func writeCache(pid: pid_t, windowSet: Set<WindowInfo>) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        let oldWindowSet = windowCache[pid] ?? []
        windowCache[pid] = windowSet

        let suppressionDepth = coordinatorNotificationSuppressionCounts[pid] ?? 0
        guard suppressionDepth == 0 else {
            if oldWindowSet != windowSet {
                logSuppressedCoordinatorPublish(
                    pid: pid,
                    reason: "write",
                    oldCount: oldWindowSet.count,
                    newCount: windowSet.count,
                    depth: suppressionDepth
                )
            }
            return
        }

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

        let suppressionDepth = coordinatorNotificationSuppressionCounts[pid] ?? 0
        guard suppressionDepth == 0 else {
            if oldWindowSet != currentWindowSet {
                logSuppressedCoordinatorPublish(
                    pid: pid,
                    reason: "update",
                    oldCount: oldWindowSet.count,
                    newCount: currentWindowSet.count,
                    depth: suppressionDepth
                )
            }
            return
        }

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
            let suppressionDepth = coordinatorNotificationSuppressionCounts[pid] ?? 0
            guard suppressionDepth == 0 else {
                logSuppressedCoordinatorPublish(
                    pid: pid,
                    reason: "remove",
                    oldCount: windowSet.count + 1,
                    newCount: windowSet.count,
                    depth: suppressionDepth
                )
                return
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
