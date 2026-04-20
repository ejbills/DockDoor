import Defaults
import SwiftUI

struct DockLockingSettingsView: View {
    @Default(.enableDockLocking) var enableDockLocking
    @Default(.lockedDockScreenIdentifier) var lockedDockScreenIdentifier
    @Default(.dockLockOverrideModifier) var dockLockOverrideModifier

    private var isLockedScreenDisconnected: Bool {
        !lockedDockScreenIdentifier.isEmpty
            && !NSScreen.screens.contains { $0.uniqueIdentifier() == lockedDockScreenIdentifier }
    }

    var body: some View {
        BaseSettingsView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection

                if enableDockLocking {
                    configurationSection
                    noteSection
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        SettingsGroup {
            SettingsIllustratedToggle(
                isOn: $enableDockLocking,
                title: "Lock Dock to Screen"
            ) {
                Text("Prevent the Dock from jumping to other monitors when your cursor reaches the screen edge.")
            }
            .settingsSearchTarget("dockLocking.enable")
            .onChange(of: enableDockLocking) { isOn in
                if isOn, lockedDockScreenIdentifier.isEmpty {
                    lockedDockScreenIdentifier = NSScreen.main?.uniqueIdentifier() ?? ""
                }
                askUserToRestartApplication()
            }
        }
    }

    // MARK: - Configuration

    private var configurationSection: some View {
        SettingsGroup(header: "Configuration") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Lock Dock to", selection: $lockedDockScreenIdentifier) {
                    ForEach(NSScreen.screens, id: \.self) { screen in
                        Text(screen.displayName).tag(screen.uniqueIdentifier())
                    }
                    if isLockedScreenDisconnected {
                        Text("Disconnected Display").tag(lockedDockScreenIdentifier)
                    }
                }
                .pickerStyle(.menu)
                .settingsSearchTarget("dockLocking.screen")

                if isLockedScreenDisconnected {
                    Text("This display is currently disconnected. Dock locking will be disabled until it reconnects.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text("After changing the locked screen, move your cursor to the bottom of that screen to relocate the Dock.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker("Bypass modifier key", selection: $dockLockOverrideModifier) {
                    ForEach(DockLockModifier.allCases, id: \.rawValue) { modifier in
                        Text(modifier.localizedName).tag(modifier.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .settingsSearchTarget("dockLocking.bypass")

                Text("Hold this key to temporarily allow the Dock to move freely.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Note

    private var noteSection: some View {
        SettingsNote(
            icon: "info.circle",
            text: "Dock Locking works best with a bottom-positioned Dock in a multi-monitor setup where \"Displays have separate Spaces\" is enabled in System Settings → Desktop & Dock → Mission Control. The Dock won't jump to another monitor while this feature is enabled."
        )
    }
}
