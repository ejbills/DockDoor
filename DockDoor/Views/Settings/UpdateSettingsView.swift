import SwiftUI

struct UpdateSettingsView: View {
    @ObservedObject var updaterState: UpdaterState

    init(updaterState: UpdaterState) {
        self.updaterState = updaterState
    }

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            EnabledActionRowView(
                title: String(localized: "Current Version"),
                description: String(localized: "Your app is on version \(updaterState.currentVersion)"),
                isGranted: true,
                iconName: "checkmark.seal",
                action: nil,
                disableShine: false,
                statusText: String(localized: "Up to Date"),
                customStatusView: AnyView(updateStatusView)
            )

            EnabledActionRowView(
                title: String(localized: "Check for Updates"),
                description: lastCheckDescription,
                isGranted: updaterState.canCheckForUpdates,
                iconName: "arrow.triangle.2.circlepath",
                action: updaterState.checkForUpdates,
                disableShine: true,
                buttonText: String(localized: "Check for Updates"),
                hideStatus: true
            )

            EnabledActionRowView(
                title: String(localized: "Automatic Updates"),
                description: String(localized: "Enable automatic checking for updates"),
                isGranted: updaterState.isAutomaticChecksEnabled,
                iconName: "clock.arrow.2.circlepath",
                action: updaterState.toggleAutomaticChecks,
                disableShine: true,
                buttonText: String(localized: "Toggle"),
                statusText: String(localized: "Enabled")
            )
        }
    }

    private var lastCheckDescription: String {
        if let lastCheck = updaterState.lastUpdateCheckDate {
            String(localized: "Last checked: \(lastCheck.formatted(date: .abbreviated, time: .shortened))")
        } else {
            String(localized: "No recent checks")
        }
    }

    @ViewBuilder
    private var updateStatusView: some View {
        Group {
            switch updaterState.updateStatus {
            case .noUpdates:
                Label(String(localized: "Up to date"), systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .checking:
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 20, height: 20)
            case let .available(version, publishedDate, _):
                VStack(alignment: .trailing, spacing: 2) {
                    Label(String(localized: "Update v\(version) available"), systemImage: "arrow.down.circle.fill")
                        .foregroundColor(.blue)
                    if let date = publishedDate {
                        Text(date.formatted(date: .numeric, time: .omitted))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            case let .error(message):
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .lineLimit(2)
                    .font(.caption2)
            }
        }
        .font(.caption)
    }
}
