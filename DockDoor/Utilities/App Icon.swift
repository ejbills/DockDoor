//
//  App Icon.swift
//  DockDoor
//
//  Created by Ethan Bills on 6/18/24.
//

import AppKit

struct AppIconUtil {
    // MARK: - Properties
    
    private static var iconCache: [String: NSImage] = [:]
    
    // MARK: - App Icons
    
    static func getIcon(file path: URL) -> NSImage? {
        let cacheKey = path.path
        
        if let cachedIcon = iconCache[cacheKey] {
            return cachedIcon
        }
        
        guard FileManager.default.fileExists(atPath: path.path) else {
            return nil
        }
        
        let icon = NSWorkspace.shared.icon(forFile: path.path)
        iconCache[cacheKey] = icon
        return icon
    }
    
    static func getIcon(bundleID: String) -> NSImage? {
        if let cachedIcon = iconCache[bundleID] {
            return cachedIcon
        }
        
        guard let path = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        
        let icon = getIcon(file: path)
        iconCache[bundleID] = icon
        return icon
    }
    
    static func getIcon(application: String) -> NSImage? {
        return getIcon(bundleID: application)
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
}
