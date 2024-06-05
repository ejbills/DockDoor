//
//  DockUtils.swift
//  DockDoor
//
//

import Cocoa

enum DockPosition {
    case bottom
    case left
    case right
    case unknown
}

class DockUtils {
    static let shared = DockUtils()

    private init() {}
    
    private func getDockDefaults() -> UserDefaults? {
        if let defaults = UserDefaults(suiteName: "com.apple.dock") {
            return defaults
        }
        
        return nil
    }
    
    private func tileSize() -> CGFloat {
        guard let defaults = getDockDefaults(), let tileSize = defaults.object(forKey: "tilesize") as? CGFloat else {
            return 0
        }
        
        return tileSize
    }
    
    func countIcons() -> (Int, Int) {
        guard let defaults = getDockDefaults() else { return (0, 0) }
        let persistentAppsCount = defaults.array(forKey: "persistent-apps")?.count ?? 0
        let recentAppsCount = defaults.array(forKey: "recent-apps")?.count ?? 0
        return (persistentAppsCount + recentAppsCount, (persistentAppsCount > 0 && recentAppsCount > 0) ? 1 : 0)
    }

    func calculateDockWidth() -> CGFloat {
        let countIcons = countIcons()
        
        let iconCount = countIcons.0
        let numberOfDividers = countIcons.1
        let tileSize = tileSize()
        
        let baseWidth = tileSize * CGFloat(iconCount)
        
        // Estimate the width of dividers
        let dividerWidth: CGFloat = 10.0
        let totalDividerWidth = CGFloat(numberOfDividers) * dividerWidth

        // Consider magnification only if enabled
        if let defaults = getDockDefaults(), defaults.bool(forKey: "magnification"),
           let largeSize = defaults.object(forKey: "largesize") as? CGFloat {
            let extraWidth = (largeSize - tileSize) * CGFloat(iconCount) * 0.5 // Assume half of the icons might be magnified at any time
            return baseWidth + extraWidth + totalDividerWidth
        }
        
        return baseWidth + totalDividerWidth
    }

    func calculateDockHeight() -> CGFloat {
        guard let screen = NSScreen.main else { return 0 }
        let dockPosition = getDockPosition()

        switch dockPosition {
        case .right, .left:
            // Subtracting the visible width from the total width to get the thickness of the dock
            let dockThickness = abs(screen.frame.width - screen.visibleFrame.width)
            return dockThickness
        case .bottom:
            // Subtracting the visible height from the total height to get the height of the dock
            let statusBarHeight = NSStatusBar.system.thickness // Consider status bar height if it might affect calculation
            let dockHeight = abs(screen.frame.height - screen.visibleFrame.height) - statusBarHeight
            return dockHeight
        case .unknown:
            return 0
        }
    }
    
    func getDockPosition() -> DockPosition {
        guard let screen = NSScreen.main else { return .bottom }
        if screen.visibleFrame.origin.y == 0 {
            return screen.visibleFrame.origin.x == 0 ? .right : .left
        } else {
            return .bottom
        }
    }
}
