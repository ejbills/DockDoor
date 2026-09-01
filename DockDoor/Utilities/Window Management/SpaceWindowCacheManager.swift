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

    private var pendingRemoved: [WindowInfo] = []
    private var pendingAdded: [WindowInfo] = []
    private var pendingUpdated: [WindowInfo] = []
    private var flushScheduled = false

    private func enqueueCoordinatorChanges(removed: Set<WindowInfo> = [], added: Set<WindowInfo> = [], updated: [WindowInfo] = []) {
        guard !removed.isEmpty || !added.isEmpty || !updated.isEmpty else { return }
        pendingRemoved.append(contentsOf: removed)
        pendingAdded.append(contentsOf: added)
        pendingUpdated.append(contentsOf: updated)
        guard !flushScheduled else { return }
        flushScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.flushCoordinatorChanges()
        }
    }

    private func takePendingCoordinatorChanges() -> (removed: [WindowInfo], added: [WindowInfo], updated: [WindowInfo]) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        let batch = (pendingRemoved, pendingAdded, pendingUpdated)
        pendingRemoved.removeAll()
        pendingAdded.removeAll()
        pendingUpdated.removeAll()
        flushScheduled = false
        return batch
    }

    private func flushCoordinatorChanges() {
        let batch = takePendingCoordinatorChanges()
        guard let coordinator = SharedPreviewWindowCoordinator.activeInstance?.windowSwitcherCoordinator else { return }
        MainActor.assumeIsolated {
            coordinator.applyCacheChanges(removed: batch.removed, added: batch.added, updated: batch.updated)
        }
    }

    private func notifyCoordinatorOfRemovedWindows(_ removedWindows: Set<WindowInfo>) {
        enqueueCoordinatorChanges(removed: removedWindows)
    }

    private func notifyCoordinatorOfAddedWindows(_ addedWindows: Set<WindowInfo>) {
        enqueueCoordinatorChanges(added: addedWindows)
    }

    private func notifyCoordinatorOfUpdatedWindows(_ updatedWindows: [WindowInfo]) {
        enqueueCoordinatorChanges(updated: updatedWindows)
    }

    func readCache(pid: pid_t) -> Set<WindowInfo> {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return windowCache[pid] ?? []
    }

    private func beginSuppression(for pid: pid_t) -> Int {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        let depth = coordinatorNotificationSuppressionCounts[pid, default: 0] + 1
        coordinatorNotificationSuppressionCounts[pid] = depth
        return depth
    }

    private func endSuppression(for pid: pid_t) -> Int {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        let remainingCount = (coordinatorNotificationSuppressionCounts[pid] ?? 1) - 1
        if remainingCount > 0 {
            coordinatorNotificationSuppressionCounts[pid] = remainingCount
        } else {
            coordinatorNotificationSuppressionCounts.removeValue(forKey: pid)
        }
        return remainingCount
    }

    func withCoordinatorNotificationsSuppressed<T>(
        for pid: pid_t,
        operation: () async throws -> T
    ) async throws -> T {
        let depth = beginSuppression(for: pid)
        DebugLogger.log("WindowCachePublish", details: "suppress begin, PID: \(pid), depth: \(depth)")

        defer {
            let remainingCount = endSuppression(for: pid)
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
               oldWindow != newWindow || oldWindow.viewSnapshot != newWindow.viewSnapshot
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
               oldWindow != newWindow || oldWindow.viewSnapshot != newWindow.viewSnapshot
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

    func cachedPIDs() -> [pid_t] {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return windowCache.keys.filter { !(windowCache[$0]?.isEmpty ?? true) }
    }

    func purgeAll() {
        for pid in cachedPIDs() {
            writeCache(pid: pid, windowSet: [])
        }
    }

    func getAllWindows() -> [WindowInfo] {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return Array(windowCache.values.flatMap { $0 }).sorted(by: { $0.lastAccessedTime > $1.lastAccessedTime })
    }
}
