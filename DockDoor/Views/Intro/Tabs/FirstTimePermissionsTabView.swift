import SwiftUI

struct FirstTimePermissionsTabView: View {
    var nextTab: () -> Void
    @StateObject private var permissionsChecker = PermissionsChecker()

    var body: some View {
        VStack(spacing: 12) {
            Text("Let's set things up")
                .font(.title)
                .fontWeight(.bold)

            VStack(spacing: 4) {
                Text("Click each button below to open System Settings.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("No data ever leaves your device.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("When macOS asks to quit, click \"Later\" — we'll restart at the end")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            VStack(spacing: 10) {
                EnabledActionRowView(
                    title: String(localized: "Accessibility"),
                    description: String(localized: "For dock hover and window switching"),
                    isGranted: permissionsChecker.accessibilityPermission,
                    iconName: "accessibility",
                    action: { SystemPreferencesHelper.openAccessibilityPreferences() },
                    disableShine: false
                )

                EnabledActionRowView(
                    title: String(localized: "Screen Recording"),
                    description: String(localized: "Optional — for window preview images"),
                    isGranted: permissionsChecker.screenRecordingPermission,
                    iconName: "record.circle",
                    action: { SystemPreferencesHelper.openScreenRecordingPreferences() },
                    disableShine: false
                )
            }

            Spacer().frame(height: 4)

            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text("Permission changes may not appear here until the app restarts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Button(action: nextTab) {
                    HStack {
                        Text("Continue")
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(AccentButtonStyle())
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
    }
}

#Preview {
    FirstTimePermissionsTabView(nextTab: {})
}
