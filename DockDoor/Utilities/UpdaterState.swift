import Combine
import Sparkle
import SwiftUI

enum UpdateChannel: String, CaseIterable {
    case stable
    case beta

    var displayName: String {
        switch self {
        case .stable:
            String(localized: "Stable")
        case .beta:
            String(localized: "Beta")
        }
    }
}

final class UpdaterState: NSObject, SPUUpdaterDelegate, ObservableObject {
    @Published var canCheckForUpdates: Bool = false
    @Published var lastUpdateCheckDate: Date?
    @Published var currentVersion: String
    @Published var isAutomaticChecksEnabled: Bool = false
    @Published var updateChannel: UpdateChannel = .stable {
        didSet {
            if updateChannel != oldValue {
                switchUpdateChannel(to: updateChannel)
            }
        }
    }

    @Published var updateStatus: UpdateStatus = .noUpdates {
        didSet {
            print("UpdaterState: updateStatus changed to: \(updateStatus)")
        }
    }

    var updater: SPUUpdater? {
        didSet {
            bindUpdaterProperties()
            if let updater {
                isAutomaticChecksEnabled = updater.automaticallyChecksForUpdates
                print("UpdaterState: Initialized with \(updateChannel.displayName) channel")
            }
        }
    }

    private var cancellables = Set<AnyCancellable>()

    enum UpdateStatus {
        case noUpdates
        case checking
        case available(version: String, publishedDate: Date?, releaseNotes: String?)
        case error(String)

        static func == (lhs: UpdateStatus, rhs: UpdateStatus) -> Bool {
            switch (lhs, rhs) {
            case (.noUpdates, .noUpdates): true
            case (.checking, .checking): true
            case let (.available(lVersion, _, _), .available(rVersion, _, _)): lVersion == rVersion
            case let (.error(lMsg), .error(rMsg)): lMsg == rMsg
            default: false
            }
        }
    }

    var anUpdateIsAvailable: Bool {
        if case .available = updateStatus {
            return true
        }
        return false
    }

    override init() {
        currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"

        // Load saved update channel preference
        if let savedChannelRaw = UserDefaults.standard.string(forKey: "updateChannel"),
           let savedChannel = UpdateChannel(rawValue: savedChannelRaw)
        {
            updateChannel = savedChannel
        }

        super.init()
    }

    private func bindUpdaterProperties() {
        guard let updater else { return }
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()

        updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .assign(to: \.canCheckForUpdates, on: self)
            .store(in: &cancellables)

        updater.publisher(for: \.lastUpdateCheckDate)
            .receive(on: DispatchQueue.main)
            .assign(to: \.lastUpdateCheckDate, on: self)
            .store(in: &cancellables)
    }

    func checkForUpdates() {
        guard let updater else {
            updateStatus = .error(String(localized: "Updater not configured."))
            return
        }
        updateStatus = .checking
        updater.checkForUpdates()
    }

    func toggleAutomaticChecks() {
        guard let updater else { return }
        updater.automaticallyChecksForUpdates.toggle()
        isAutomaticChecksEnabled = updater.automaticallyChecksForUpdates
    }

    private func switchUpdateChannel(to channel: UpdateChannel) {
        // Save the channel preference
        UserDefaults.standard.set(channel.rawValue, forKey: "updateChannel")

        // Reset update status when switching channels
        updateStatus = .noUpdates

        print("UpdaterState: Switched to \(channel.displayName) channel")
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        DispatchQueue.main.async {
            self.updateStatus = .available(version: item.versionString, publishedDate: item.date, releaseNotes: item.itemDescription)
        }
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        DispatchQueue.main.async {
            if case .checking = self.updateStatus {
                self.updateStatus = .noUpdates
            } else if case .available = self.updateStatus {
                self.updateStatus = .noUpdates
            }
        }
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        DispatchQueue.main.async {
            self.updateStatus = .error(String(localized: "Update aborted: \(error.localizedDescription)"))
        }
    }

    func updater(_ updater: SPUUpdater, failedToDownloadUpdate item: SUAppcastItem, error: Error) {
        DispatchQueue.main.async {
            self.updateStatus = .error(String(localized: "Failed to download v\(item.versionString): \(error.localizedDescription)"))
        }
    }

    func updaterDidFinishSetup(_ updater: SPUUpdater) {}

    func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        switch updateChannel {
        case .stable:
            return Set() // Empty set means default channel only
        case .beta:
            return Set(["beta"])
        }
    }

    func updater(_ updater: SPUUpdater, willShowModalAlert alert: NSAlert) {
        print("UpdaterState (SPUUpdaterDelegate): updater:willShowModalAlert. Alert: \(alert.messageText)")
    }
}
