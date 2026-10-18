import Defaults
import SwiftUI

struct SupportSettingsView: View {
    @ObservedObject var updaterState: UpdaterState
    @StateObject private var permissionsChecker = PermissionsChecker()

    init(updaterState: UpdaterState) {
        self.updaterState = updaterState
    }

    var body: some View {
        SettingsFormView {
            DockDoorProBanner()
            permissionsSection
            updatesSection
            supportLinksSection
            acknowledgmentsSection
        }
    }

    // MARK: - Permissions Section

    private var permissionsSection: some View {
        SettingsSection("Permissions", footer: "Changes to permissions require an app restart to take effect.") {
            PermissionRow(
                title: "Accessibility",
                description: "Required for dock hover detection and window switcher hotkeys",
                icon: "accessibility",
                isGranted: permissionsChecker.accessibilityPermission,
                action: { SystemPreferencesHelper.openAccessibilityPreferences() }
            )
            .settingsSearchTarget("support.accessibility")

            PermissionRow(
                title: "Screen Recording",
                description: "Required for capturing window previews. Without this, only compact list view is available.",
                icon: "record.circle",
                isGranted: permissionsChecker.screenRecordingPermission,
                action: { SystemPreferencesHelper.openScreenRecordingPreferences() }
            )
            .settingsSearchTarget("support.screenRecording")
        }
    }

    // MARK: - Updates Section

    private var updatesSection: some View {
        SettingsSection("Updates") {
            // Current version
            HStack(spacing: 12) {
                SettingsIcon(systemName: "checkmark.seal.fill", color: .green)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Current version")
                        .font(.body)
                    Text("Version \(updaterState.currentVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                updateStatusBadge
            }

            // Update channel
            HStack(spacing: 12) {
                SettingsIcon(systemName: "arrow.triangle.branch", color: .blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Update channel")
                        .font(.body)
                    Text("Choose between stable releases and beta versions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
            .settingsSearchTarget("support.updateChannel")

            // Check for updates
            HStack(spacing: 12) {
                SettingsIcon(systemName: "arrow.triangle.2.circlepath", color: .orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Check for updates")
                        .font(.body)
                    Text(lastCheckDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Check Now") {
                    updaterState.checkForUpdates()
                }
                .buttonStyle(.settings)
                .disabled(!updaterState.canCheckForUpdates)
            }
            .settingsSearchTarget("support.checkForUpdates")

            // Automatic updates toggle
            HStack(spacing: 12) {
                SettingsIcon(systemName: "clock.arrow.2.circlepath", color: .purple)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Automatic updates")
                        .font(.body)
                    Text("Automatically check for updates in the background")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { updaterState.isAutomaticChecksEnabled },
                    set: { _ in updaterState.toggleAutomaticChecks() }
                ))
                .labelsHidden()
            }
            .settingsSearchTarget("support.automaticUpdates")

            // Debug logging
            DebugLoggingRow()
                .settingsSearchTarget("support.debugLogging")
        }
    }

    private var lastCheckDescription: String {
        if let lastCheck = updaterState.lastUpdateCheckDate {
            let formatted = lastCheck.formatted(date: .abbreviated, time: .shortened)
            return String(localized: "Last checked: \(formatted)")
        } else {
            return String(localized: "No recent checks")
        }
    }

    @ViewBuilder
    private var updateStatusBadge: some View {
        switch updaterState.updateStatus {
        case .noUpdates:
            Label("Up to date", systemImage: "checkmark.circle.fill")
                .font(.callout)
                .foregroundStyle(.green)
        case .checking:
            ProgressView()
                .scaleEffect(0.7)
                .frame(width: 20, height: 20)
        case let .available(version, _, _):
            Label("v\(version) available", systemImage: "arrow.down.circle.fill")
                .font(.callout)
                .foregroundStyle(.blue)
        case let .error(message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.callout)
                .foregroundStyle(.red)
                .lineLimit(1)
        }
    }

    // MARK: - Support & Contributions

    private var supportLinksSection: some View {
        SettingsSection("Support & contributions") {
            SupportLinksSection()
        }
    }

    // MARK: - Acknowledgments Section

    @ViewBuilder
    private var acknowledgmentsSection: some View {
        SettingsSection("Contributors") {
            CreditRow(name: "illavoluntas", detail: "Website, documentation, Discord moderation", icon: "person")
        }

        SettingsSection("Translations") {
            ForEach(Self.translators, id: \.profile) { translator in
                CreditRow(
                    name: translator.name,
                    detail: translator.language,
                    icon: "globe",
                    url: URL(string: "https://crowdin.com/profile/\(translator.profile)")
                )
            }
        }

        SettingsSection("Sounds") {
            CreditRow(
                name: "Magic Glow",
                detail: "IENBA · CC0",
                icon: "speaker.wave.2",
                url: URL(string: "https://freesound.org/s/752274/")
            )
        }
    }

    private static let translators: [(name: String, language: String, profile: String)] = [
        ("Rocco 'Roccobot' Casadei", "Italian", "Roccobot"),
        ("favorsjewelry5", "Chinese Traditional", "favorsjewelry5"),
        ("Денис Єгоров", "Ukrainian", "makedonsky47"),
        ("HuangxinDong", "Chinese Simplified", "HuangxinDong"),
        ("don.julien.7", "German", "JuGro1332"),
        ("awaustin", "Chinese Simplified", "awaustin"),
        ("illavoluntas", "French", "illavoluntas"),
        ("Diamant", "French", "Diamant"),
    ]
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
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(isGranted ? .green : .red)
                    .font(.callout)

                if !isGranted {
                    Button("Grant") {
                        action()
                    }
                    .buttonStyle(.settings)
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
                    Text("Debug logging")
                        .font(.body)
                    Text("Capture performance metrics for troubleshooting")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                    .buttonStyle(.settings)

                    Button("Clear Logs") {
                        DebugLogger.clearLogs()
                    }
                    .buttonStyle(.settings)
                }
                .padding(.leading, 40)
            }
        }
    }
}

private struct CreditRow: View {
    let name: String
    let detail: String
    let icon: String
    var url: URL?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: name)
                    .lineLimit(1)
                Text(verbatim: detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if let url {
                Link(destination: url) {
                    Image(systemName: "arrow.up.right")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(url.host() ?? url.absoluteString)
                .accessibilityLabel("Open \(name)")
            }
        }
    }
}
