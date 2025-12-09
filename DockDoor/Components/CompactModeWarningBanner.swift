import SwiftUI

struct CompactModeWarningBanner: View {
    let hasScreenRecordingPermission: Bool
    let disableImagePreview: Bool

    private var showSettingsButton: Bool {
        !hasScreenRecordingPermission && !disableImagePreview
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .padding(8)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.orange, Color.yellow.opacity(0.8)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)

            VStack(alignment: .leading, spacing: 4) {
                Text("Compact List Mode Only (Window Previews are Disabled)")
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("Screen Recording permission is required to show window thumbnails.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Grant permission in System Settings to enable window previews.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if showSettingsButton {
                Button(action: {
                    SystemPreferencesHelper.openScreenRecordingPreferences()
                }) {
                    Text("Open Settings")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(AccentButtonStyle(small: true))
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.orange.opacity(0.5), Color.yellow.opacity(0.3)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
    }
}
