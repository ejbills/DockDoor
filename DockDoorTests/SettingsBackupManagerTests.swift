@testable import DockDoor
import Foundation
import Testing

struct SettingsBackupManagerTests {
    private let suiteName = "com.ethanbills.DockDoorTests.SettingsBackup"

    @Test func roundTripPreservesPropertyListTypes() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let domain: [String: Any] = [
            "previewWidth": 300.5,
            "showAppName": true,
            "switcherMaxRows": 8,
            "appNameFilters": ["Finder", "Safari"],
            "UserKeybind": "{\"keyCode\":48,\"modifierFlags\":524576}",
            "hoverHighlightColor": Data([0, 1, 2, 255]),
            "SULastCheckTime": date,
            "nested": ["blob": Data([9, 8]), "when": date, "list": [1, "two", false]],
        ]

        let backup = try SettingsBackupManager.decode(SettingsBackupManager.encode(domain: domain))

        #expect(backup.settings.count == domain.count)
        #expect(backup.settings["previewWidth"] as? Double == 300.5)
        #expect(backup.settings["showAppName"] as? Bool == true)
        #expect(backup.settings["switcherMaxRows"] as? Int == 8)
        #expect(backup.settings["appNameFilters"] as? [String] == ["Finder", "Safari"])
        #expect(backup.settings["UserKeybind"] as? String == "{\"keyCode\":48,\"modifierFlags\":524576}")
        #expect(backup.settings["hoverHighlightColor"] as? Data == Data([0, 1, 2, 255]))
        #expect(backup.settings["SULastCheckTime"] as? Date == date)

        let nested = try #require(backup.settings["nested"] as? [String: Any])
        #expect(nested["blob"] as? Data == Data([9, 8]))
        #expect(nested["when"] as? Date == date)
        let list = try #require(nested["list"] as? [Any])
        #expect(list.count == 3)
        #expect(list[0] as? Int == 1)
        #expect(list[1] as? String == "two")
        #expect(list[2] as? Bool == false)
    }

    @Test func encodeWritesEnvelopeMetadata() throws {
        let exportedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let data = try SettingsBackupManager.encode(domain: ["showAppName": true], appVersion: "1.2.3", exportedAt: exportedAt)
        let object = try JSONSerialization.jsonObject(with: data)
        let envelope = try #require(object as? [String: Any])

        #expect(envelope["app"] as? String == "DockDoor")
        #expect(envelope["appVersion"] as? String == "1.2.3")
        #expect(envelope["formatVersion"] as? Int == SettingsBackupManager.formatVersion)
        #expect(envelope["exportedAt"] as? String == "2023-11-14T22:13:20Z")

        let backup = try SettingsBackupManager.decode(data)
        #expect(backup.appVersion == "1.2.3")
        #expect(backup.exportedAt == exportedAt)
    }

    @Test func decodeRejectsForeignJSON() {
        let notABackup = Data("{\"settings\": {\"showAppName\": true}}".utf8)
        #expect(throws: SettingsBackupManager.BackupError.self) {
            try SettingsBackupManager.decode(notABackup)
        }

        let garbage = Data("not json".utf8)
        #expect(throws: SettingsBackupManager.BackupError.self) {
            try SettingsBackupManager.decode(garbage)
        }
    }

    @Test func applyOverwritesWholeDomain() throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(false, forKey: "showAppName")
        defaults.set(2, forKey: "previewMaxColumns")

        SettingsBackupManager.apply(["showAppName": true, "switcherMaxRows": 4], to: defaults, domainName: suiteName)

        #expect(defaults.bool(forKey: "showAppName") == true)
        #expect(defaults.integer(forKey: "switcherMaxRows") == 4)
        #expect(defaults.object(forKey: "previewMaxColumns") == nil)
        #expect(defaults.persistentDomain(forName: suiteName)?.count == 2)

        defaults.removePersistentDomain(forName: suiteName)
    }
}
