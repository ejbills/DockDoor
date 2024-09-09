import SwiftUI

struct PermissionsView: View {
    var nextTab: (() -> Void)? = nil
    var disableShine: Bool = false
    @StateObject private var permissionsChecker = PermissionsChecker()

    var body: some View {
        VStack(alignment: .center, spacing: 24) {
            PermissionRowView(
                title: String(localized: "Accessibility"),
                description: String(localized: "Required for dock hover detection and window switcher hotkeys"),
                isGranted: permissionsChecker.accessibilityPermission,
                iconName: "accessibility",
                action: openAccessibilityPreferences,
                disableShine: disableShine
            )

            PermissionRowView(
                title: String(localized: "Screen recording"),
                description: String(localized: "Required for capturing window previews of other apps"),
                isGranted: permissionsChecker.screenRecordingPermission,
                iconName: "video.fill",
                action: openScreenRecordingPreferences,
                disableShine: disableShine
            )

            if let nextTab {
                VStack(alignment: .center, spacing: 12) {
                    SquiggleDivider().opacity(0.5)

                    Button(action: nextTab) {
                        Text("Next page")
                    }
                    .buttonStyle(AccentButtonStyle())
                }
            }
        }
    }

    private func openAccessibilityPreferences() {
        SystemPreferencesHelper.openAccessibilityPreferences()
    }

    private func openScreenRecordingPreferences() {
        SystemPreferencesHelper.openScreenRecordingPreferences()
    }
}

#Preview {
    PermissionsView()
}
