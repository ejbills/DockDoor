//
//  SettingsBackupManager.swift
//  DockDoor
//

import AppKit
import Defaults
import Foundation
import UniformTypeIdentifiers

/// Handles exporting and importing DockDoor settings via the UserDefaults persistent domain.
///
/// This approach is inherently resilient to changes in settings keys — new keys are
/// simply missing from older backups (and use their defaults), while removed keys in
/// newer versions are silently ignored on import.
enum SettingsBackupManager {
    // MARK: - Export

    /// Presents a save panel and exports all current settings to a JSON file.
    @MainActor
    static func exportSettings() {
        guard let bundleID = Bundle.main.bundleIdentifier,
              let defaults = UserDefaults.standard.persistentDomain(forName: bundleID)
        else {
            MessageUtil.showAlert(
                title: String(localized: "Export Failed"),
                message: String(localized: "Could not read current settings.")
            )
            return
        }

        let panel = NSSavePanel()
        panel.title = String(localized: "Export DockDoor Settings")
        panel.nameFieldStringValue = "DockDoor-Settings.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try JSONSerialization.data(
                withJSONObject: defaults,
                options: [.prettyPrinted, .sortedKeys]
            )
            try data.write(to: url, options: .atomic)
        } catch {
            MessageUtil.showAlert(
                title: String(localized: "Export Failed"),
                message: error.localizedDescription
            )
        }
    }

    // MARK: - Import

    /// Presents an open panel and imports settings from a JSON file.
    @MainActor
    static func importSettings() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "Import DockDoor Settings")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.json]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try Data(contentsOf: url)
            guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                MessageUtil.showAlert(
                    title: String(localized: "Import Failed"),
                    message: String(localized: "The selected file does not contain valid settings.")
                )
                return
            }

            MessageUtil.showAlert(
                title: String(localized: "Import Settings"),
                message: String(localized: "This will replace all current settings with the imported values. DockDoor will restart to apply changes."),
                actions: [.ok, .cancel]
            ) { action in
                guard action == .ok else { return }

                guard let bundleID = Bundle.main.bundleIdentifier else { return }

                // Replace the entire persistent domain with the imported values.
                UserDefaults.standard.setPersistentDomain(dict, forName: bundleID)
                UserDefaults.standard.synchronize()

                askUserToRestartApplication()
            }
        } catch {
            MessageUtil.showAlert(
                title: String(localized: "Import Failed"),
                message: error.localizedDescription
            )
        }
    }
}
