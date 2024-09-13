import Sparkle
import SwiftUI

final class UpdaterViewModel: ObservableObject {
    @Published var canCheckForUpdates = false
    @Published var lastUpdateCheckDate: Date?
    @Published var currentVersion: String
    @Published var isAutomaticChecksEnabled: Bool
    @Published var updateStatus: UpdateStatus = .noUpdates

    private let updater: SPUUpdater

    enum UpdateStatus {
        case noUpdates
        case checking
        case available(version: String)
        case error(String)
    }

    init(updater: SPUUpdater) {
        self.updater = updater
        currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        isAutomaticChecksEnabled = updater.automaticallyChecksForUpdates

        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)

        updater.publisher(for: \.lastUpdateCheckDate)
            .assign(to: &$lastUpdateCheckDate)
    }

    func checkForUpdates() {
        updateStatus = .checking
        updater.checkForUpdates()
    }

    func toggleAutomaticChecks() {
        isAutomaticChecksEnabled.toggle()
        updater.automaticallyChecksForUpdates = isAutomaticChecksEnabled
    }
}

struct UpdateSettingsView: View {
    @StateObject private var viewModel: UpdaterViewModel
    var disableShine: Bool = false

    init(updater: SPUUpdater) {
        _viewModel = StateObject(wrappedValue: UpdaterViewModel(updater: updater))
    }

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            EnabledActionRowView(
                title: String(localized: "Current Version"),
                description: String(localized: "Your app is on version \(viewModel.currentVersion)"),
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
                isGranted: viewModel.canCheckForUpdates,
                iconName: "arrow.triangle.2.circlepath",
                action: viewModel.checkForUpdates,
                disableShine: true,
                buttonText: String(localized: "Check for Updates"),
                hideStatus: true
            )

            EnabledActionRowView(
                title: String(localized: "Automatic Updates"),
                description: String(localized: "Enable automatic checking for updates"),
                isGranted: viewModel.isAutomaticChecksEnabled,
                iconName: "clock.arrow.2.circlepath",
                action: viewModel.toggleAutomaticChecks,
                disableShine: true,
                buttonText: String(localized: "Toggle"),
                statusText: String(localized: "Enabled")
            )
        }
        .padding(20)
        .frame(minWidth: 650)
    }

    private var lastCheckDescription: String {
        if let lastCheck = viewModel.lastUpdateCheckDate {
            String(localized: "Last checked: \(lastCheck.formatted(date: .abbreviated, time: .shortened))")
        } else {
            String(localized: "No recent checks")
        }
    }

    private var updateStatusView: some View {
        Group {
            switch viewModel.updateStatus {
            case .noUpdates:
                Label(String(localized: "Up to date"), systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .checking:
                ProgressView()
                    .scaleEffect(0.7)
            case let .available(version):
                VStack(alignment: .trailing) {
                    Label(String(localized: "Update available"), systemImage: "arrow.down.circle.fill")
                        .foregroundColor(.blue)
                    Text(String(localized: "Version \(version)"))
                        .font(.caption)
                }
            case let .error(message):
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
            }
        }
        .font(.caption)
    }
}
