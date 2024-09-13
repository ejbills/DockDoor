import Cocoa
import Defaults
import ScreenCaptureKit

class SpaceWindowCacheManager {
    private let queue = DispatchQueue(label: "com.dockdoor.cacheQueue", attributes: .concurrent)
    private var desktopSpaceWindowCache: [pid_t: Set<WindowInfo>] = [:]

    func readCache(pid: pid_t) -> Set<WindowInfo> {
        queue.sync {
            desktopSpaceWindowCache[pid] ?? []
        }
    }

    func writeCache(pid: pid_t, windowSet: Set<WindowInfo>) {
        queue.async(flags: .barrier) {
            self.desktopSpaceWindowCache[pid] = windowSet
        }
    }

    func updateCache(pid: pid_t, update: @escaping (inout Set<WindowInfo>) -> Void) {
        queue.async(flags: .barrier) {
            var windowSet = self.desktopSpaceWindowCache[pid] ?? []
            update(&windowSet)
            self.desktopSpaceWindowCache[pid] = windowSet
        }
    }

    func removeFromCache(pid: pid_t, windowId: CGWindowID) {
        queue.async(flags: .barrier) {
            if var windowSet = self.desktopSpaceWindowCache[pid] {
                windowSet.remove(windowSet.first(where: { $0.id == windowId })!)
                if windowSet.isEmpty {
                    self.desktopSpaceWindowCache.removeValue(forKey: pid)
                } else {
                    self.desktopSpaceWindowCache[pid] = windowSet
                }
            }
        }
    }

    func getAllWindows() -> [WindowInfo] {
        queue.sync {
            self.desktopSpaceWindowCache.values.flatMap { $0 }.sorted(by: { $0.date > $1.date })
        }
    }
}
