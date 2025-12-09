import SwiftUI

struct PermissionsView: View {
    var nextTab: (() -> Void)?
    var disableShine: Bool = false
    var showSkipOption: Bool = true
    @StateObject private var permissionsChecker = PermissionsChecker()

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            EnabledActionRowView(
                title: String(localized: "Accessibility"),
                description: String(localized: "Required for dock hover detection and window switcher hotkeys"),
                isGranted: permissionsChecker.accessibilityPermission,
                iconName: "accessibility",
                action: openAccessibilityPreferences,
                disableShine: disableShine
            )

            VStack(spacing: 8) {
                EnabledActionRowView(
                    title: String(localized: "Screen recording"),
                    description: String(localized: "Required for capturing window previews of other apps. Without this, only the compact list view will be available."),
                    isGranted: permissionsChecker.screenRecordingPermission,
                    iconName: "record.circle",
                    action: openScreenRecordingPreferences,
                    disableShine: disableShine
                )

                if showSkipOption, !permissionsChecker.screenRecordingPermission {
                    HStack {
                        Spacer()
                        Button(action: { nextTab?() }) {
                            Text("Skip (use list view only)")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                }
            }

            if let nextTab {
                VStack(alignment: .center, spacing: 12) {
                    SquiggleDivider()
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
