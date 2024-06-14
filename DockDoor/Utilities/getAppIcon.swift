//
//  getAppIcon.swift
//  DockDoor
//
//  Created by Igor Marcossi on 14/06/24.
//

import Foundation
import AppKit

func getAppIcon(byName appName: String) -> NSImage? {
    let workspace = NSWorkspace.shared
    let apps = workspace.runningApplications
    
    for app in apps {
        if let appLocalizedName = app.localizedName, appLocalizedName.caseInsensitiveCompare(appName) == .orderedSame {
            return workspace.icon(forFile: app.bundleURL!.path)
        }
    }
    
    return nil
}
