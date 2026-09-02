import Defaults
import SwiftUI

struct DockLockingSettingsView: View {
    @Default(.enableDockLocking) var enableDockLocking
    @Default(.lockedDockScreenIdentifier) var lockedDockScreenIdentifier
    @Default(.dockLockOverrideModifier) var dockLockOverrideModifier

    private var isLockedScreenDisconnected: Bool {
        !lockedDockScreenIdentifier.isEmpty
            && NSScreen.findScreen(byIdentifier: lockedDockScreenIdentifier) == nil
    }

    private var isLockedScreenEdgeCovered: Bool {
        guard NSScreen.screens.count > 1,
              let screen = NSScreen.findScreen(byIdentifier: lockedDockScreenIdentifier)
        else { return false }
        let dockPosition = DockUtils.getDockPosition()
        guard dockPosition == .bottom || dockPosition == .left || dockPosition == .right else { return false }
        return DockLockerGeometry.exposedIntervals(
            for: screen.cgFrame,
            dockPosition: dockPosition,
            allFrames: NSScreen.screens.map(\.cgFrame)
        ).isEmpty
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
                    lockedDockScreenIdentifier = NSScreen.systemMainDisplayIdentifier
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
                    Text("System Main Display").tag(NSScreen.systemMainDisplayIdentifier)
                    ForEach(NSScreen.screens, id: \.self) { screen in
                        Text(screen.displayName).tag(screen.uniqueIdentifier())
                    }
                    if isLockedScreenDisconnected {
                        Text("Disconnected Display").tag(lockedDockScreenIdentifier)
                    }
                }
                .pickerStyle(.menu)
                .settingsSearchTarget("dockLocking.screen")
                .onAppear { NSScreen.migrateScreenIdentifier(.lockedDockScreenIdentifier) }

                if isLockedScreenDisconnected {
                    Text("This display is currently disconnected. Dock locking will be disabled until it reconnects.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if isLockedScreenEdgeCovered {
                    Text("macOS can't place the Dock on this display because another display sits directly against its Dock edge. Rearrange your displays in System Settings → Displays so part of that edge is free.")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    Text("System Main Display follows whichever screen holds the menu bar. DockDoor moves the Dock to the locked screen automatically; you can also push the cursor against that screen's Dock edge.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

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
