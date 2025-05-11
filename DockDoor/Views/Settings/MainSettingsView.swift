import AppKit
import Combine
import Defaults
import LaunchAtLogin
import Sparkle
import SwiftUI

final class UpdaterViewModel: ObservableObject {
    @Published var canCheckForUpdates = false
    @Published var lastUpdateCheckDate: Date?
    @Published var currentVersion: String
    @Published var isAutomaticChecksEnabled: Bool
    @Published var updateStatus: UpdateStatus = .noUpdates

    let updater: SPUUpdater

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

struct MainSettingsView: View {
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon: Bool = true
    @StateObject private var updaterViewModel: UpdaterViewModel
    @StateObject private var permissionsChecker = PermissionsChecker()

    init() {
        let updater = SPUStandardUpdaterController(updaterDelegate: nil, userDriverDelegate: nil).updater
        _updaterViewModel = StateObject(wrappedValue: UpdaterViewModel(updater: updater))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // App Icon and Title
                VStack(spacing: 8) {
                    Image("RawAppIcon")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .shadow(radius: 10)

                    Text("DockDoor")
                        .font(.system(size: 28, weight: .bold))
                }
                .frame(maxWidth: .infinity)

                // General section
                VStack(alignment: .leading, spacing: 8) {
                    Text("General").font(.headline)

                    // Launch at Login toggle
                    LaunchAtLogin.Toggle("Launch DockDoor at login")

                    // Show Menu Bar Icon toggle
                    Toggle("Show in Menu Bar", isOn: $showMenuBarIcon)
                        .onChange(of: showMenuBarIcon) { isOn in
                            let appDelegate = NSApplication.shared.delegate as! AppDelegate
                            if isOn {
                                appDelegate.setupMenuBar()
                            } else {
                                appDelegate.removeMenuBar()
                            }
                        }

                    // Reset and Quit buttons
                    Button("Reset all settings") {
                        showResetConfirmation()
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color(NSColor.windowBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.separator)
                )

                // Updates section
                VStack(alignment: .leading, spacing: 8) {
                    // First row: Updates heading left, Current Version right
                    HStack {
                        Text("Updates").font(.headline)
                        Spacer()
                        Text("Current version: \(updaterViewModel.currentVersion)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    // Second row: Check Now left, status right
                    HStack {
                        Button("Check now") {
                            updaterViewModel.checkForUpdates()
                        }
                        .disabled(!updaterViewModel.canCheckForUpdates)
                        Spacer()
                        Group {
                            switch updaterViewModel.updateStatus {
                            case .noUpdates:
                                Text("Up to date").foregroundColor(.green)
                            case .checking:
                                Text("Checking for updates...").foregroundColor(.secondary)
                            case let .available(version):
                                Text("Update available - Version \(version)").foregroundColor(.blue)
                            case let .error(message):
                                Text(message).foregroundColor(.red)
                            }
                        }
                        .font(.subheadline)
                    }
                    // Third row: Automatic updates left, last checked right
                    HStack {
                        Toggle("Automatic updates", isOn: $updaterViewModel.isAutomaticChecksEnabled)
                        Spacer()
                        Text(lastCheckDescription)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color(NSColor.windowBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.separator)
                )

                // Help and Support sections
                HStack(alignment: .top, spacing: 24) {
                    // Help section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Visit Us").font(.headline)
                        Button("Website") {
                            NSWorkspace.shared.open(URL(string: "https://dockdoor.net/")!)
                        }
                        .buttonStyle(.link)

                        Button("GitHub") {
                            NSWorkspace.shared.open(URL(string: "https://github.com/ejbills/DockDoor")!)
                        }
                        .buttonStyle(.link)
                        Button("Report an issue") {
                            NSWorkspace.shared.open(URL(string: "https://github.com/ejbills/DockDoor/issues")!)
                        }
                        .buttonStyle(.link)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Support section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Support Us").font(.headline)
                        Button("Buy Me a Coffee") {
                            NSWorkspace.shared.open(URL(string: "https://www.buymeacoffee.com/keplercafe")!)
                        }
                        .buttonStyle(.link)

                        Button("Contribute a translation") {
                            NSWorkspace.shared.open(URL(string: "https://crowdin.com/project/dockdoor/invite?h=895e3c085646d3c07fa36a97044668e02149115")!)
                        }
                        .buttonStyle(.link)

                        Button("Explore our other apps") {
                            NSWorkspace.shared.open(URL(string: "https://kepler.cafe/")!)
                        }
                        .buttonStyle(.link)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color(NSColor.windowBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.separator)
                )

                // Permissions section
                PermissionsView()
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        Color(NSColor.windowBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(.separator)
                    )
            }
            .padding(24)
        }
        .frame(minWidth: 500, maxWidth: 500, minHeight: 750, maxHeight: 750)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var lastCheckDescription: String {
        if let lastCheck = updaterViewModel.lastUpdateCheckDate {
            String(localized: "Last checked: \(lastCheck.formatted(date: .abbreviated, time: .shortened))")
        } else {
            String(localized: "No recent checks")
        }
    }

    private func showResetConfirmation() {
        MessageUtil.showAlert(
            title: String(localized: "Reset all settings"),
            message: String(localized: "Are you sure you want to reset all settings to their default values?"),
            actions: [.ok, .cancel]
        ) { action in
            switch action {
            case .ok:
                resetDefaultsToDefaultValues()
            case .cancel:
                // Do nothing
                break
            }
        }
    }
}
