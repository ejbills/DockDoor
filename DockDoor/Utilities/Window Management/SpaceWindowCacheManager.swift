import Cocoa
import Defaults
import ScreenCaptureKit

class SpaceWindowCacheManager {
    private var windowCache: [pid_t: Set<WindowInfo>] = [:]
    private let cacheLock = NSLock()

    func readCache(pid: pid_t) -> Set<WindowInfo> {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return windowCache[pid] ?? []
    }

    func writeCache(pid: pid_t, windowSet: Set<WindowInfo>) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        windowCache[pid] = windowSet
    }

    func updateCache(pid: pid_t, update: (inout Set<WindowInfo>) -> Void) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        var windowSet = windowCache[pid] ?? []
        update(&windowSet)
        windowCache[pid] = windowSet
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
        }
    }

    func getAllWindows() -> [WindowInfo] {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return Array(windowCache.values.flatMap { $0 }).sorted(by: { $0.date > $1.date })
    }
}
