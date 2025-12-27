import SwiftUI

struct FirstTimePermissionsTabView: View {
    var nextTab: () -> Void
    @StateObject private var permissionsChecker = PermissionsChecker()

    private var bothPermissionsGranted: Bool {
        permissionsChecker.accessibilityPermission && permissionsChecker.screenRecordingPermission
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("Let's set things up")
                .font(.title)
                .fontWeight(.bold)

            // Instructions
            VStack(spacing: 4) {
                Text("Click each button below to open System Settings")
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

            // Permission rows
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
                    description: String(localized: "For window preview images"),
                    isGranted: permissionsChecker.screenRecordingPermission,
                    iconName: "record.circle",
                    action: { SystemPreferencesHelper.openScreenRecordingPreferences() },
                    disableShine: false
                )
            }

            Spacer().frame(height: 4)

            // Next button - only enabled when both granted
            VStack(spacing: 8) {
                Button(action: nextTab) {
                    HStack {
                        Text(bothPermissionsGranted ? "Continue" : "Grant both permissions to continue")
                        if bothPermissionsGranted {
                            Image(systemName: "arrow.right")
                        }
                    }
                }
                .buttonStyle(AccentButtonStyle())
                .disabled(!bothPermissionsGranted)
                .opacity(bothPermissionsGranted ? 1 : 0.5)

                if !bothPermissionsGranted {
                    Text("Toggle both permissions in System Settings, then return here")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
    }
}

#Preview {
    FirstTimePermissionsTabView(nextTab: {})
}
