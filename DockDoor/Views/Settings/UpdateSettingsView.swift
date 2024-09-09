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

    init(updater: SPUUpdater) {
        _viewModel = StateObject(wrappedValue: UpdaterViewModel(updater: updater))
    }

    var body: some View {
        VStack(alignment: .center) {
            updateStatusView.bold().padding(1)

            HStack(alignment: .center) {
                VStack(alignment: .center) {
                    HStack(alignment: .center) {
                        Text("Current Version: \(viewModel.currentVersion)").foregroundStyle(.gray)
                    }
                    if let lastCheck = viewModel.lastUpdateCheckDate {
                        HStack(alignment: .center) {
                            Text("Last checked: \(lastCheck, formatter: dateFormatter)").foregroundStyle(.gray)
                        }
                    }
                }
            }

            Button(action: viewModel.checkForUpdates) {
                Label("Check for Updates", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(!viewModel.canCheckForUpdates)

            Toggle("Automatically check for updates", isOn: $viewModel.isAutomaticChecksEnabled)
                .onChange(of: viewModel.isAutomaticChecksEnabled) { _ in
                    viewModel.toggleAutomaticChecks()
                }
        }
        .padding(20)
        .frame(minWidth: 650)
    }

    private var updateStatusView: some View {
        Group {
            switch viewModel.updateStatus {
            case .noUpdates:
                Label("Up to date", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .checking:
                ProgressView()
                    .scaleEffect(0.7)
            case let .available(version):
                VStack {
                    Label("Update available", systemImage: "arrow.down.circle.fill")
                        .foregroundColor(.blue)
                    Text("Version \(version)")
                        .font(.caption)
                }
            case let .error(message):
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
            }
        }
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
