import Defaults
import SwiftUI

struct SupportSettingsView: View {
    @ObservedObject var updaterState: UpdaterState
    @StateObject private var permissionsChecker = PermissionsChecker()

    init(updaterState: UpdaterState) {
        self.updaterState = updaterState
    }

    var body: some View {
        BaseSettingsView {
            VStack(alignment: .leading, spacing: 20) {
                permissionsSection
                updatesSection
                acknowledgmentsSection
            }
        }
    }

    // MARK: - Permissions Section

    private var permissionsSection: some View {
        SettingsGroup(header: "Permissions", compact: true) {
            VStack(alignment: .leading, spacing: 0) {
                PermissionRow(
                    title: "Accessibility",
                    description: "Required for dock hover detection and window switcher hotkeys",
                    icon: "accessibility",
                    isGranted: permissionsChecker.accessibilityPermission,
                    action: { SystemPreferencesHelper.openAccessibilityPreferences() }
                )

                Divider().padding(.leading, 40)

                PermissionRow(
                    title: "Screen Recording",
                    description: "Required for capturing window previews. Without this, only compact list view is available.",
                    icon: "record.circle",
                    isGranted: permissionsChecker.screenRecordingPermission,
                    action: { SystemPreferencesHelper.openScreenRecordingPreferences() }
                )
            }

            Text("Changes to permissions require an app restart to take effect.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
    }

    // MARK: - Updates Section

    private var updatesSection: some View {
        SettingsGroup(header: "Updates") {
            VStack(alignment: .leading, spacing: 12) {
                // Current version
                HStack(spacing: 12) {
                    SettingsIcon(systemName: "checkmark.seal.fill", color: .green)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Current Version")
                            .font(.body)
                        Text("Version \(updaterState.currentVersion)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    updateStatusBadge
                }

                Divider().padding(.leading, 40)

                // Update channel
                HStack(spacing: 12) {
                    SettingsIcon(systemName: "arrow.triangle.branch", color: .blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Update Channel")
                            .font(.body)
                        Text("Choose between stable releases and beta versions")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Picker("", selection: $updaterState.updateChannel) {
                        ForEach(UpdateChannel.allCases, id: \.self) { channel in
                            Text(channel.displayName).tag(channel)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 100)
                }

                Divider().padding(.leading, 40)

                // Check for updates
                HStack(spacing: 12) {
                    SettingsIcon(systemName: "arrow.triangle.2.circlepath", color: .orange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Check for Updates")
                            .font(.body)
                        Text(lastCheckDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button("Check Now") {
                        updaterState.checkForUpdates()
                    }
                    .buttonStyle(AccentButtonStyle(small: true))
                    .disabled(!updaterState.canCheckForUpdates)
                }

                Divider().padding(.leading, 40)

                // Automatic updates toggle
                HStack(spacing: 12) {
                    SettingsIcon(systemName: "clock.arrow.2.circlepath", color: .purple)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Automatic Updates")
                            .font(.body)
                        Text("Automatically check for updates in the background")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { updaterState.isAutomaticChecksEnabled },
                        set: { _ in updaterState.toggleAutomaticChecks() }
                    ))
                    .labelsHidden()
                }

                Divider().padding(.leading, 40)

                // Debug logging
                DebugLoggingRow()
            }
        }
    }

    private var lastCheckDescription: String {
        if let lastCheck = updaterState.lastUpdateCheckDate {
            "Last checked: \(lastCheck.formatted(date: .abbreviated, time: .shortened))"
        } else {
            "No recent checks"
        }
    }

    @ViewBuilder
    private var updateStatusBadge: some View {
        switch updaterState.updateStatus {
        case .noUpdates:
            Label("Up to date", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(.green)
        case .checking:
            ProgressView()
                .scaleEffect(0.7)
                .frame(width: 20, height: 20)
        case let .available(version, _, _):
            Label("v\(version) available", systemImage: "arrow.down.circle.fill")
                .font(.caption)
                .foregroundColor(.blue)
        case let .error(message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption2)
                .foregroundColor(.red)
                .lineLimit(1)
        }
    }

    // MARK: - Acknowledgments Section

    private var acknowledgmentsSection: some View {
        SettingsGroup(header: "Acknowledgments") {
            VStack(alignment: .leading, spacing: 12) {
                // Community Contributors
                Text("Community Contributors")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                ContributorRow(
                    name: "illavoluntas",
                    detail: "Website, documentation, Discord moderation",
                    icon: "person.fill"
                )

                Divider()

                // Translation Contributors
                Text("Translation Contributors")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                VStack(spacing: 2) {
                    TranslatorRow(name: "Rocco 'Roccobot' Casadei", language: "Italian", profile: "Roccobot")
                    TranslatorRow(name: "favorsjewelry5", language: "Chinese Traditional", profile: "favorsjewelry5")
                    TranslatorRow(name: "Денис Єгоров", language: "Ukrainian", profile: "makedonsky47")
                    TranslatorRow(name: "HuangxinDong", language: "Chinese Simplified", profile: "HuangxinDong")
                    TranslatorRow(name: "don.julien.7", language: "German", profile: "JuGro1332")
                    TranslatorRow(name: "awaustin", language: "Chinese Simplified", profile: "awaustin")
                    TranslatorRow(name: "illavoluntas", language: "French", profile: "illavoluntas")
                }
            }
        }
    }
}

// MARK: - Helper Views

private struct PermissionRow: View {
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    let icon: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            SettingsIcon(systemName: icon, color: isGranted ? .green : .orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(isGranted ? .green : .red)
                    .font(.callout)

                if !isGranted {
                    Button("Grant") {
                        action()
                    }
                    .buttonStyle(AccentButtonStyle(small: true))
                }
            }
        }
        .padding(.vertical, 2)
    }
}

private struct DebugLoggingRow: View {
    @Default(.debugMode) var debugMode

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                SettingsIcon(systemName: "ant.fill", color: .orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Debug Logging")
                        .font(.body)
                    Text("Capture performance metrics for troubleshooting")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Toggle("", isOn: $debugMode)
                    .labelsHidden()
            }

            if debugMode {
                HStack(spacing: 12) {
                    Button("Export Logs") {
                        if let url = DebugLogger.exportLogs() {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        }
                    }
                    .buttonStyle(AccentButtonStyle(small: true))

                    Button("Clear Logs") {
                        DebugLogger.clearLogs()
                    }
                    .buttonStyle(AccentButtonStyle(small: true))
                }
                .padding(.leading, 40)
            }
        }
    }
}

private struct ContributorRow: View {
    let name: String
    let detail: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 16)

            Text(name)
                .font(.body)

            Spacer()

            Text(detail)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }
}

private struct TranslatorRow: View {
    let name: String
    let language: String
    let profile: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "globe")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 16)

            Text(name)
                .font(.body)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(language)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)

            Link(destination: URL(string: "https://crowdin.com/profile/\(profile)")!) {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.vertical, 2)
    }
}
