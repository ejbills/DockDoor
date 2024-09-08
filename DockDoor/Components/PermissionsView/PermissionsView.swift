import SwiftUI

struct PermissionsView: View {
    var disableShine = false
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
                description: "Needed to capture window previews of other apps",
                isGranted: permissionsChecker.screenRecordingPermission,
                iconName: "video.fill",
                action: openScreenRecordingPreferences
            )

            VStack(alignment: .center, spacing: 12) {
                SquiggleDivider().opacity(0.5)

                Text("Changes to permissions require an application restart")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Button(action: restartApp) {
                    Text("Restart app")
                }
                .buttonStyle(AccentButtonStyle())
            }
        }
    }

    private func openAccessibilityPreferences() {
        SystemPreferencesHelper.openAccessibilityPreferences()
    }

    private func openScreenRecordingPreferences() {
        SystemPreferencesHelper.openScreenRecordingPreferences()
    }

    private func restartApp() {
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        appDelegate.restartApp()
    }
}

#Preview {
    PermissionsView()
}
