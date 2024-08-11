//
//  SpaceWindowCacheManager.swift
//  DockDoor
//
//  Created by Ethan Bills on 7/17/24.
//

import Cocoa
import ScreenCaptureKit

class SpaceWindowCacheManager {
    private let queue = DispatchQueue(label: "com.dockdoor.cacheQueue", attributes: .concurrent)
    private var desktopSpaceWindowCache: [String: Set<WindowInfo>] = [:]
    private var appNameBundleIdTracker: [String: String] = [:]

    func readCache(bundleId: String) -> Set<WindowInfo> {
        queue.sync {
            desktopSpaceWindowCache[bundleId] ?? []
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
                    if let windowToRemove = windowSet.first(where: { $0.id == windowId }) {
                        windowSet.remove(windowToRemove)
                        self.desktopSpaceWindowCache[bundleId] = windowSet
                    } else {
                        return
                    }
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

    // New functions for appNameBundleIdTracker

    func updateAppNameBundleIdTracker(app: SCRunningApplication, nonLocalName: String) {
        queue.async(flags: .barrier) {
            self.appNameBundleIdTracker[app.applicationName] = app.bundleIdentifier
            self.appNameBundleIdTracker[nonLocalName] = app.bundleIdentifier
        }
    }

    func addToBundleIDTracker(applicationName: String, bundleID: String) {
        queue.async(flags: .barrier) {
            if !self.appNameBundleIdTracker.contains(where: { $0.key == applicationName }) {
                self.appNameBundleIdTracker[applicationName] = bundleID
            }
        }
    }

    func findBundleID(for applicationName: String) -> String? {
        queue.sync {
            // First, try to get the bundle ID directly from the tracker
            if let bundleID = self.appNameBundleIdTracker[applicationName] {
                return bundleID
            }

            // If not found, try to find a matching application
            for (appName, bundleId) in self.appNameBundleIdTracker {
                if applicationName.contains(appName) || appName.contains(applicationName) {
                    return bundleId
                }

                // Check non-localized name
                if let nonLocalizedName = self.getNonLocalizedAppName(forBundleIdentifier: bundleId),
                   applicationName.contains(nonLocalizedName) || nonLocalizedName.contains(applicationName)
                {
                    return bundleId
                }
            }

            return nil
        }
    }

    private func getNonLocalizedAppName(forBundleIdentifier bundleIdentifier: String) -> String? {
        guard let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return nil
        }

        let bundle = Bundle(url: bundleURL)
        return bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
    }
}
