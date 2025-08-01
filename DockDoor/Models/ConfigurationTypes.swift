import Cocoa
import Defaults
import Foundation
import ScreenCaptureKit
import SwiftUI

// MARK: - Orphaned Window Association Types

struct OrphanedWindowAssociation: Codable, Defaults.Serializable, Hashable {
    let windowID: CGWindowID // For immediate matching (may become stale)
    let windowTitle: String // Primary matching criterion
    let bundleIdentifier: String // Target app to associate with
    let processID: pid_t // Original PID (may become stale)

    // Additional matching criteria for robustness
    let windowSize: CGSize? // Window dimensions (optional for migration)
    let windowLayer: Int? // Window layer (optional for migration)
    let originalBundleID: String? // Original owning app bundle ID (optional for migration)

    init(windowID: CGWindowID, windowTitle: String, bundleIdentifier: String, processID: pid_t, windowSize: CGSize? = nil, windowLayer: Int? = nil, originalBundleID: String? = nil) {
        self.windowID = windowID
        self.windowTitle = windowTitle
        self.bundleIdentifier = bundleIdentifier
        self.processID = processID
        self.windowSize = windowSize
        self.windowLayer = windowLayer
        self.originalBundleID = originalBundleID
    }

    /// Check if a window matches this association using multiple criteria
    func matches(window: SCWindow) -> Bool {
        // Exact ID match (if still valid) - fastest check
        if window.windowID == windowID {
            return true
        }

        // For legacy associations without enhanced data, fall back to title match
        guard let originalBundleID,
              let windowSize,
              let windowLayer
        else {
            // Legacy matching: just title (less reliable but better than nothing)
            return window.title == windowTitle
        }

        // Enhanced matching with multiple criteria
        let titleMatches = window.title == windowTitle
        let bundleMatches = window.owningApplication?.bundleIdentifier == originalBundleID

        // Secondary matches for robustness (with tolerance)
        let sizeMatches = abs(window.frame.size.width - windowSize.width) < 50 &&
            abs(window.frame.size.height - windowSize.height) < 50
        let layerMatches = window.windowLayer == windowLayer

        // Strong match: title + bundle ID + (size OR layer)
        return titleMatches && bundleMatches && (sizeMatches || layerMatches)
    }
}

/// Information about an orphaned window
struct OrphanedWindowInfo: Identifiable, Hashable {
    let id = UUID()
    let windowID: CGWindowID
    let windowTitle: String
    let scAppBundleID: String
    let scAppPID: pid_t
    let frame: CGRect
    let windowLayer: Int

    func hash(into hasher: inout Hasher) {
        hasher.combine(windowID)
        hasher.combine(scAppPID)
    }

    static func == (lhs: OrphanedWindowInfo, rhs: OrphanedWindowInfo) -> Bool {
        lhs.windowID == rhs.windowID && lhs.scAppPID == rhs.scAppPID
    }
}

/// Information about a potential app to associate with
struct PotentialAssociationApp: Identifiable, Hashable {
    let id = UUID()
    let bundleIdentifier: String
    let processID: pid_t
    let localizedName: String
    let icon: NSImage

    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleIdentifier)
        hasher.combine(processID)
    }

    static func == (lhs: PotentialAssociationApp, rhs: PotentialAssociationApp) -> Bool {
        lhs.bundleIdentifier == rhs.bundleIdentifier && lhs.processID == rhs.processID
    }
}

// MARK: - Display Configuration Types

enum WindowTitleDisplayCondition: String, CaseIterable, Defaults.Serializable {
    case all
    case dockPreviewsOnly
    case windowSwitcherOnly

    var localizedName: String {
        switch self {
        case .all:
            String(localized: "Dock Previews & Window Switcher", comment: "Preview window title display condition option")
        case .dockPreviewsOnly:
            String(localized: "Dock Previews only", comment: "Preview window title condition display option")
        case .windowSwitcherOnly:
            String(localized: "Window Switcher only", comment: "Preview window title condition display option")
        }
    }
}

enum WindowTitlePosition: String, CaseIterable, Defaults.Serializable {
    case bottomLeft
    case bottomRight
    case topRight
    case topLeft

    var localizedName: String {
        switch self {
        case .bottomLeft:
            String(localized: "Bottom Left", comment: "Preview window title position option")
        case .bottomRight:
            String(localized: "Bottom Right", comment: "Preview window title position option")
        case .topRight:
            String(localized: "Top Right", comment: "Preview window title position option")
        case .topLeft:
            String(localized: "Top Left", comment: "Preview window title position option")
        }
    }
}

enum AppNameStyle: String, CaseIterable, Defaults.Serializable {
    case `default`
    case shadowed
    case popover

    var localizedName: String {
        switch self {
        case .default:
            String(localized: "Default", comment: "Preview title style option")
        case .shadowed:
            String(localized: "Shadowed", comment: "Preview title style option")
        case .popover:
            String(localized: "Popover", comment: "Preview title style option")
        }
    }
}

enum WindowTitleVisibility: String, CaseIterable, Defaults.Serializable {
    case whenHoveringPreview
    case alwaysVisible

    var localizedName: String {
        switch self {
        case .whenHoveringPreview:
            String(localized: "When hovering over the preview", comment: "Window title visibility option")
        case .alwaysVisible:
            String(localized: "Always visible", comment: "Window title visibility option")
        }
    }
}

enum TrafficLightButtonsVisibility: String, CaseIterable, Defaults.Serializable {
    case never
    case dimmedOnPreviewHover
    case fullOpacityOnPreviewHover
    case alwaysVisible

    var localizedName: String {
        switch self {
        case .never:
            String(localized: "Never visible", comment: "Traffic light buttons visibility option")
        case .dimmedOnPreviewHover:
            String(localized: "On window hover; Dimmed until button hover", comment: "Traffic light buttons visibility option")
        case .fullOpacityOnPreviewHover:
            String(localized: "On window hover; Full opacity", comment: "Traffic light buttons visibility option")
        case .alwaysVisible:
            String(localized: "Always visible; Full opacity", comment: "Traffic light buttons visibility option")
        }
    }
}

enum TrafficLightButtonsPosition: String, CaseIterable, Defaults.Serializable {
    case topLeft
    case topRight
    case bottomRight
    case bottomLeft

    var localizedName: String {
        switch self {
        case .topLeft:
            String(localized: "Top Left", comment: "Traffic light buttons position option")
        case .topRight:
            String(localized: "Top Right", comment: "Traffic light buttons position option")
        case .bottomRight:
            String(localized: "Bottom Right", comment: "Traffic light buttons position option")
        case .bottomLeft:
            String(localized: "Bottom Left", comment: "Traffic light buttons position option")
        }
    }
}

enum WindowSwitcherPlacementStrategy: String, CaseIterable, Defaults.Serializable {
    case screenWithMouse
    case screenWithLastActiveWindow
    case pinnedToScreen

    var localizedName: String {
        switch self {
        case .screenWithMouse:
            String(localized: "Screen with mouse", comment: "Window switcher placement option")
        case .screenWithLastActiveWindow:
            String(localized: "Screen with last active window", comment: "Window switcher placement option")
        case .pinnedToScreen:
            String(localized: "Pinned to screen", comment: "Window switcher placement option")
        }
    }
}

enum WindowSwitcherControlPosition: String, CaseIterable, Defaults.Serializable {
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing

    var localizedName: String {
        switch self {
        case .topLeading:
            String(localized: "At top - Title on left, controls on right")
        case .topTrailing:
            String(localized: "At top - Controls on left, title on right")
        case .bottomLeading:
            String(localized: "At bottom - Title on left, controls on right")
        case .bottomTrailing:
            String(localized: "At bottom - Controls on left, title on right")
        }
    }
}

// MARK: - Action Configuration Types

enum PreviewHoverAction: String, CaseIterable, Defaults.Serializable {
    case none
    case tap
    case previewFullSize

    var localizedName: String {
        switch self {
        case .none:
            String(localized: "No action", comment: "Window popup hover action option")
        case .tap:
            String(localized: "Simulate a click (open the window)", comment: "Window popup hover action option")
        case .previewFullSize:
            String(localized: "Present a full size preview of the window", comment: "Window popup hover action option")
        }
    }
}

enum AeroShakeAction: String, CaseIterable, Defaults.Serializable {
    case none
    case all
    case except

    var localizedName: String {
        switch self {
        case .none:
            String(localized: "No action", comment: "Aero shake action option")
        case .all:
            String(localized: "Minimize all windows", comment: "Aero shake action option")
        case .except:
            String(localized: "Minimize all windows except the current one", comment: "Aero shake action option")
        }
    }
}

enum DockClickAction: String, CaseIterable, Defaults.Serializable {
    case minimize
    case hide

    var localizedName: String {
        switch self {
        case .minimize:
            String(localized: "Minimize windows", comment: "Dock click action option")
        case .hide:
            String(localized: "Hide application", comment: "Dock click action option")
        }
    }
}
