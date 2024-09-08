import SwiftUI

struct PermissionsView: View {
    var nextTab: (() -> Void)? = nil
    @StateObject private var permissionsChecker = PermissionsChecker()

    var body: some View {
        VStack(alignment: .center, spacing: 24) {
            PermissionRowView(
                title: "Accessibility",
                description: "Required for dock hover detection and window switcher hotkeys",
                isGranted: permissionsChecker.accessibilityPermission,
                iconName: "accessibility",
                action: openAccessibilityPreferences
            )

            PermissionRowView(
                title: "Screen recording",
                description: "Required for capturing window previews of other apps",
                isGranted: permissionsChecker.screenRecordingPermission,
                iconName: "video.fill",
                action: openScreenRecordingPreferences
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
