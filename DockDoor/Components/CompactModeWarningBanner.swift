import SwiftUI

struct CompactModeWarningBanner: View {
    let hasScreenRecordingPermission: Bool
    let disableImagePreview: Bool

    private var showSettingsButton: Bool {
        !hasScreenRecordingPermission && !disableImagePreview
    }

    var body: some View {
        SettingsCallout(
            tone: .warning,
            icon: "list.bullet.rectangle",
            title: Text("Compact List Mode Only (Window Previews are Disabled)"),
            message: Text("Screen Recording permission is required to show window thumbnails.") + Text(verbatim: " ") + Text("Grant permission in System Settings to enable window previews."),
            actionTitle: showSettingsButton ? "Open Settings" : nil,
            action: showSettingsButton ? { SystemPreferencesHelper.openScreenRecordingPreferences() } : nil
        )
    }
}
