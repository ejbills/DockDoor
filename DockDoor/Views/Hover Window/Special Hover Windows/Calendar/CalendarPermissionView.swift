
import SwiftUI

struct CalendarPermissionView: View {
    let isEmbedded: Bool

    @Environment(\.openURL) private var openURL

    var body: some View {
        if isEmbedded {
            embeddedPermissionView()
        } else {
            fullPermissionView()
        }
    }

    @ViewBuilder
    private func embeddedPermissionView() -> some View {
        VStack(spacing: 6) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.title3)
                .foregroundStyle(.orange)

            Text("Calendar Access Needed")
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)

            Button("Grant Access") {
                openPrivacySettings()
            }
            .buttonStyle(AccentButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private func fullPermissionView() -> some View {
        VStack(spacing: 8) {
            Label {
                Text(" ")
            } icon: {
                Image(systemName: "calendar.badge.exclamationmark")
            }
            .labelStyle(.iconOnly)
            .font(.largeTitle)
            .fontWeight(.light)
            .imageScale(.large)
            .foregroundStyle(.orange)

            Text("Calendar Access Needed")
                .font(.title2)
                .fontWeight(.medium)
            Text("DockDoor needs permission to access your calendar.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Open System Privacy Settings") {
                openPrivacySettings()
            }
            .buttonStyle(AccentButtonStyle())
        }
    }

    private func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            openURL(url)
        }
    }
}
