
import AppKit
import Foundation

enum SharedHoverUtils {
    static func loadAppIcon(for bundleIdentifier: String) -> NSImage? {
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first,
           let icon = app.icon
        {
            return icon
        }
        return nil
    }
}
