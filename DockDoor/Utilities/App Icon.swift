//
//  App Icon.swift
//  DockDoor
//
//  Created by Ethan Bills on 6/18/24.
//

import AppKit

enum AppIconUtil {
    // MARK: - Properties

    private static var iconCache: [String: (image: NSImage, timestamp: Date)] = [:]
    private static let cacheExpiryInterval: TimeInterval = 3600 // 1 hour

    // MARK: - App Icons

    static func getIcon(file path: URL) -> NSImage? {
        let cacheKey = path.path
        removeExpiredCacheEntries()

        if let cachedEntry = iconCache[cacheKey], Date().timeIntervalSince(cachedEntry.timestamp) < cacheExpiryInterval {
            return cachedEntry.image
        }

        guard FileManager.default.fileExists(atPath: path.path) else {
            return nil
        }

        let icon = NSWorkspace.shared.icon(forFile: path.path)
        iconCache[cacheKey] = (image: icon, timestamp: Date())
        return icon
    }

    static func getIcon(bundleID: String) -> NSImage? {
        removeExpiredCacheEntries()

        if let cachedEntry = iconCache[bundleID], Date().timeIntervalSince(cachedEntry.timestamp) < cacheExpiryInterval {
            return cachedEntry.image
        }

        guard let path = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }

        let icon = getIcon(file: path)
        iconCache[bundleID] = (image: icon!, timestamp: Date())
        return icon
    }

    static func getIcon(application: String) -> NSImage? {
        getIcon(bundleID: application)
    }

    // MARK: - Bundles

    static func bundle(forBundleID: String) -> Bundle? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: forBundleID) else {
            return nil
        }

        return Bundle(url: url)
    }

    // MARK: - Cache Management

    static func clearCache() {
        iconCache.removeAll()
    }

    private static func removeExpiredCacheEntries() {
        let now = Date()
        iconCache = iconCache.filter { now.timeIntervalSince($0.value.timestamp) < cacheExpiryInterval }
    }
}
