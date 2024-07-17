//
//  SpaceWindowCacheManager.swift
//  DockDoor
//
//  Created by Ethan Bills on 7/17/24.
//

import Cocoa

class SpaceWindowCacheManager {
    private let queue = DispatchQueue(label: "com.dockdoor.cacheQueue", attributes: .concurrent)
    private var desktopSpaceWindowCache: [String: Set<WindowInfo>] = [:]
    
    func readCache(bundleId: String) -> Set<WindowInfo> {
        queue.sync {
            return desktopSpaceWindowCache[bundleId] ?? []
        }
    }
    
    func writeCache(bundleId: String, windowSet: Set<WindowInfo>) {
        queue.async(flags: .barrier) {
            self.desktopSpaceWindowCache[bundleId] = windowSet
        }
    }
    
    func updateCache(bundleId: String, update: @escaping (inout Set<WindowInfo>) -> Void) {
        queue.async(flags: .barrier) {
            var windowSet = self.desktopSpaceWindowCache[bundleId] ?? []
            update(&windowSet)
            self.desktopSpaceWindowCache[bundleId] = windowSet
        }
    }
    
    func removeFromCache(bundleId: String, windowId: CGWindowID) {
        queue.async(flags: .barrier) {
            if var windowSet = self.desktopSpaceWindowCache[bundleId] {
                if windowSet.isEmpty {
                    self.desktopSpaceWindowCache.removeValue(forKey: bundleId)
                } else {
                    windowSet.remove(windowSet.first(where: { $0.id == windowId })!)
                    self.desktopSpaceWindowCache[bundleId] = windowSet
                }
            }
        }
    }
    
    func getAllWindows() -> [WindowInfo] {
        queue.sync {
            let sortedWindows = desktopSpaceWindowCache.values.flatMap { $0 }.sorted(by: { $0.lastUsed > $1.lastUsed })
            
            // If there are at least two windows, swap the first and second
            if sortedWindows.count >= 2 {
                var modifiedWindows = sortedWindows
                modifiedWindows.swapAt(0, 1)
                return modifiedWindows
            } else {
                return sortedWindows
            }
        }
    }
}
