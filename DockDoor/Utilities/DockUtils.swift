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
    
    private let dockDefaults: UserDefaults? // Store a single instance
    
    private init() {
        dockDefaults = UserDefaults(suiteName: "com.apple.dock")
    }
    
    private func tileSize() -> CGFloat {
        return dockDefaults?.object(forKey: "tilesize") as? CGFloat ?? 0
    }
    
    func isMagnificationEnabled() -> Bool {
        return dockDefaults?.bool(forKey: "magnification") ?? false
    }
    
    func countIcons() -> (Int, Int) {
        let persistentAppsCount = dockDefaults?.array(forKey: "persistent-apps")?.count ?? 0
        let recentAppsCount = dockDefaults?.array(forKey: "recent-apps")?.count ?? 0
        return (persistentAppsCount + recentAppsCount, (persistentAppsCount > 0 && recentAppsCount > 0) ? 1 : 0)
    }
    
    func calculateDockWidth() -> CGFloat {
        let countIcons = countIcons()
        let iconCount = countIcons.0
        let numberOfDividers = countIcons.1
        let tileSize = tileSize()
        
        let baseWidth = tileSize * CGFloat(iconCount)
        let dividerWidth: CGFloat = 10.0
        let totalDividerWidth = CGFloat(numberOfDividers) * dividerWidth
        
        if self.isMagnificationEnabled(),
           let largeSize = dockDefaults?.object(forKey: "largesize") as? CGFloat {
            let extraWidth = (largeSize - tileSize) * CGFloat(iconCount) * 0.5
            return baseWidth + extraWidth + totalDividerWidth
        }
        
        return baseWidth + totalDividerWidth
    }
    
    func calculateDockHeight() -> CGFloat {
        return dockDefaults?.double(forKey: "tilesize") ?? 0
    }
    
    func getDockPosition() -> DockPosition {
        guard let orientation = dockDefaults?.string(forKey: "orientation")?.lowercased() else {
            return .unknown
        }
        switch orientation {
        case "left":   return .left
        case "bottom": return .bottom
        case "right":  return .right
        default:       return .unknown
        }
    }
}
