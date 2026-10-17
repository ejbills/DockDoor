import SwiftUI

enum PreviewMotion {
    static func hover(enabled: Bool) -> Animation? {
        enabled ? .snappy(duration: 0.175) : nil
    }

    static func content(enabled: Bool) -> Animation? {
        enabled ? .smooth(duration: 0.25) : nil
    }

    static func emphasis(enabled: Bool) -> Animation? {
        enabled ? .spring(response: 0.45, dampingFraction: 0.8) : nil
    }
}

enum PreviewTypography {
    static let appTitleSize: CGFloat = 13
    static let appTitle = Font.system(size: appTitleSize, weight: .medium)
    static let appTitleMeasureWeight: NSFont.Weight = .medium
}
