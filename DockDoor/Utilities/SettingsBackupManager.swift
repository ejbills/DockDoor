import AppKit
import UniformTypeIdentifiers

enum SettingsBackupManager {
    static let formatVersion = 1

    struct Backup {
        let appVersion: String?
        let exportedAt: Date?
        let settings: [String: Any]
    }

    enum BackupError: LocalizedError {
        case invalidFormat
        case unreadable(Error)
        case unwritable(Error)

        var errorDescription: String? {
            switch self {
            case .invalidFormat:
                String(localized: "The selected file is not a DockDoor settings backup.")
            case let .unreadable(error):
                String(localized: "The backup could not be read: \(error.localizedDescription)")
            case let .unwritable(error):
                String(localized: "The backup could not be saved: \(error.localizedDescription)")
            }
        }
    }

    private static let dataTag = "$data"
    private static let dateTag = "$date"

    static var domainName: String { Bundle.main.bundleIdentifier ?? "" }

    // MARK: - UI entry points

    static func exportSettings() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = defaultFileName()
        panel.title = String(localized: "Export DockDoor Settings")

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let domain = UserDefaults.standard.persistentDomain(forName: domainName) ?? [:]
            try encode(domain: domain).write(to: url, options: .atomic)
        } catch {
            showError(error)
        }
    }

    static func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = String(localized: "Import DockDoor Settings")

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let backup: Backup
        do {
            backup = try decode(Data(contentsOf: url))
        } catch {
            showError(error)
            return
        }

        var message = String(localized: "This will replace all current DockDoor settings with the \(backup.settings.count) settings in the backup. DockDoor will restart to apply them.")
        if let appVersion = backup.appVersion, appVersion != currentAppVersion {
            message += "\n\n" + String(localized: "The backup was created with DockDoor \(appVersion). Settings that no longer exist are ignored, and any new settings keep their defaults.")
        }

        MessageUtil.showAlert(title: String(localized: "Import Settings"), message: message, actions: [.ok, .cancel]) { action in
            guard action == .ok else { return }
            apply(backup.settings)
            askUserToRestartApplication()
        }
    }

    // MARK: - Encoding

    static func encode(domain: [String: Any], appVersion: String? = SettingsBackupManager.currentAppVersion, exportedAt: Date = Date()) throws -> Data {
        let settings = domain.mapValues(jsonValue(fromPlist:))
        var envelope: [String: Any] = [
            "app": "DockDoor",
            "formatVersion": formatVersion,
            "exportedAt": ISO8601DateFormatter().string(from: exportedAt),
            "settings": settings,
        ]
        if let appVersion {
            envelope["appVersion"] = appVersion
        }

        do {
            return try JSONSerialization.data(withJSONObject: envelope, options: [.prettyPrinted, .sortedKeys])
        } catch {
            throw BackupError.unwritable(error)
        }
    }

    static func decode(_ data: Data) throws -> Backup {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw BackupError.unreadable(error)
        }

        guard let envelope = object as? [String: Any],
              envelope["app"] as? String == "DockDoor",
              let rawSettings = envelope["settings"] as? [String: Any]
        else {
            throw BackupError.invalidFormat
        }

        let settings = rawSettings.mapValues(plistValue(fromJSON:))
        let exportedAt = (envelope["exportedAt"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) }
        return Backup(appVersion: envelope["appVersion"] as? String, exportedAt: exportedAt, settings: settings)
    }

    static func apply(_ settings: [String: Any], to defaults: UserDefaults = .standard, domainName: String = SettingsBackupManager.domainName) {
        defaults.setPersistentDomain(settings, forName: domainName)
    }

    // MARK: - Value conversion

    static func jsonValue(fromPlist value: Any) -> Any {
        // Property list values that JSON cannot represent are wrapped in single-key tagged dictionaries
        switch value {
        case let data as Data:
            [dataTag: data.base64EncodedString()]
        case let date as Date:
            [dateTag: ISO8601DateFormatter().string(from: date)]
        case let array as [Any]:
            array.map(jsonValue(fromPlist:))
        case let dictionary as [String: Any]:
            dictionary.mapValues(jsonValue(fromPlist:))
        default:
            value
        }
    }

    static func plistValue(fromJSON value: Any) -> Any {
        switch value {
        case let array as [Any]:
            return array.map(plistValue(fromJSON:))
        case let dictionary as [String: Any]:
            if dictionary.count == 1, let base64 = dictionary[dataTag] as? String, let data = Data(base64Encoded: base64) {
                return data
            }
            if dictionary.count == 1, let iso = dictionary[dateTag] as? String, let date = ISO8601DateFormatter().date(from: iso) {
                return date
            }
            return dictionary.mapValues(plistValue(fromJSON:))
        default:
            return value
        }
    }

    // MARK: - Helpers

    static var currentAppVersion: String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }

    private static func defaultFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "DockDoor Settings \(formatter.string(from: Date())).json"
    }

    private static func showError(_ error: Error) {
        MessageUtil.showAlert(title: String(localized: "Settings Backup Failed"), message: error.localizedDescription, actions: [.ok])
    }
}
