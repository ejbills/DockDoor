import SwiftUI

enum PreviewMotion {
    static func hover(enabled: Bool) -> Animation? {
        animates(enabled) ? .snappy(duration: 0.175) : nil
    }

    static func content(enabled: Bool) -> Animation? {
        animates(enabled) ? .smooth(duration: 0.25) : nil
    }

    static func emphasis(enabled: Bool) -> Animation? {
        animates(enabled) ? .spring(response: 0.45, dampingFraction: 0.8) : nil
    }

    private static func animates(_ enabled: Bool) -> Bool {
        enabled && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
}

enum PreviewTypography {
    static let appTitleSize: CGFloat = 13
    static let appTitle = Font.system(size: appTitleSize, weight: .medium)
    static let appTitleMeasureWeight: NSFont.Weight = .medium
    static let itemTitle = Font.system(size: 13, weight: .medium)
    static let toolbarIcon = Font.system(size: 13, weight: .semibold)
    static let searchIcon = Font.system(size: 14, weight: .medium)
    static let emptyStateIcon = Font.system(size: 48, weight: .light)
}

/// Fixed radii for hover chrome that doesn't follow the user's card radius.
enum PreviewRadius {
    static let xs: CGFloat = 3
    static let sm: CGFloat = 6
    static let md: CGFloat = 8
    static let lg: CGFloat = 12
    static let xl: CGFloat = 16
}
