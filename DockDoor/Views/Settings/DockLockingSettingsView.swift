import Defaults
import SwiftUI

struct DockLockingSettingsView: View {
    @Default(.enableDockLocking) var enableDockLocking
    @Default(.lockedDockScreenIdentifier) var lockedDockScreenIdentifier
    @Default(.dockLockOverrideModifier) var dockLockOverrideModifier

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
            .onChange(of: enableDockLocking) { isOn in
                if isOn, lockedDockScreenIdentifier.isEmpty {
                    lockedDockScreenIdentifier = NSScreen.main?.uniqueIdentifier() ?? ""
                }
            }
        }
    }

    // MARK: - Configuration

    private var configurationSection: some View {
        SettingsGroup(header: "Configuration") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Lock Dock to", selection: $lockedDockScreenIdentifier) {
                    ForEach(NSScreen.screens, id: \.self) { screen in
                        Text(screenDisplayName(screen)).tag(screen.uniqueIdentifier())
                    }
                    if !lockedDockScreenIdentifier.isEmpty,
                       !NSScreen.screens.contains(where: { $0.uniqueIdentifier() == lockedDockScreenIdentifier })
                    {
                        Text("Disconnected Display").tag(lockedDockScreenIdentifier)
                    }
                }
                .pickerStyle(.menu)

                if !lockedDockScreenIdentifier.isEmpty,
                   !NSScreen.screens.contains(where: { $0.uniqueIdentifier() == lockedDockScreenIdentifier })
                {
                    Text("This display is currently disconnected. Dock locking will be disabled until it reconnects.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 20)
                }

                Picker("Bypass modifier key", selection: $dockLockOverrideModifier) {
                    ForEach(DockLockModifier.allCases, id: \.rawValue) { modifier in
                        Text(modifier.localizedName).tag(modifier.rawValue)
                    }
                }
                .pickerStyle(.menu)

                Text("Hold this key to temporarily allow the Dock to move freely.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)
            }
        }
    }

    // MARK: - Note

    private var noteSection: some View {
        SettingsNote(
            icon: "info.circle",
            text: "Dock Locking is useful when \"Displays have separate Spaces\" is enabled in System Settings > Desktop & Dock. This prevents the Dock from jumping between monitors."
        )
    }

    // MARK: - Helpers

    private func screenDisplayName(_ screen: NSScreen) -> String {
        let isMain = screen == NSScreen.main
        var name = screen.localizedName
        if name.isEmpty {
            if let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
                name = String(format: NSLocalizedString("Display %u", comment: "Generic display name with CGDirectDisplayID"), displayID)
            } else {
                name = String(localized: "Unknown Display")
            }
        }
        return name + (isMain ? " (Main)" : "")
    }
}
