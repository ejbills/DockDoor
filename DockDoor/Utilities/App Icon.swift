//
//  App Icon.swift
//  DockDoor
//
//  Created by Ethan Bills on 6/18/24.
//

import AppKit

// MARK: - App Icons

func getIcon(file path: URL) -> NSImage? {
    guard FileManager.default.fileExists(atPath: path.path) else {
        return nil
    }

    return NSWorkspace.shared.icon(forFile: path.path) // Use path.path for icon retrieval
}

func getIcon(bundleID: String) -> NSImage? {
    guard let path = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    else { return nil }
    
    return getIcon(file: path)
}

func getIcon(application: String) -> NSImage? {
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: application) else {
        return nil
    }

    return getIcon(file: url)
}

// MARK: - Bundles

/// Easily read Info.plist as a Dictionary from any bundle by accessing .infoDictionary on Bundle
func bundle(forBundleID: String) -> Bundle? {
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: forBundleID)
    else { return nil }
    
    return Bundle(url: url)
}
