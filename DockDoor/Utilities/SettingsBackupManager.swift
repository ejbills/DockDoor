import AppKit
import Defaults
import Foundation
import UniformTypeIdentifiers

/// Manages exporting and importing DockDoor user settings as JSON files.
///
/// The backup format includes the app version at export time, allowing
/// forward/backward compatibility. On import, unknown keys are silently
/// skipped and missing keys retain their current values.
enum SettingsBackupManager {
    // MARK: - Backup Envelope

    /// The JSON wrapper that holds versioning metadata alongside the settings dictionary.
    private struct SettingsBackup: Codable {
        /// The app version (`CFBundleVersion`) at the time of export.
        let appVersion: String
        /// ISO-8601 timestamp of when the backup was created.
        let exportDate: String
        /// The raw UserDefaults key-value pairs for DockDoor settings.
        let settings: [String: AnyCodableValue]
    }

    // MARK: - Known Keys

    /// All UserDefaults keys that DockDoor owns.
    /// We enumerate them explicitly so system / third-party keys are never exported.
    private static let knownKeys: Set<String> = {
        var keys: Set<String> = []
        // Programmatically gather every key string defined in Defaults.Keys
        // by reading the current UserDefaults and intersecting with a prefix-free allowlist.
        // Instead we maintain an explicit list derived from consts.swift:
        let list: [String] = [
            // Window sizing & layout
            "previewWidth", "previewHeight", "lockAspectRatio", "bufferFromDock",
            "globalPaddingMultiplier",
            // Timing
            "openDelay", "useDelayOnlyForInitialOpen", "fadeOutDuration",
            "preventPreviewReentryDuringFadeOut", "inactivityTimeout", "tapEquivalentInterval",
            // Dock behavior
            "preventDockHide", "preventSwitcherHide", "requireShiftTabToGoBack",
            "shouldHideOnDockItemClick", "dockClickAction", "enableCmdRightClickQuit",
            "enableDockScrollGesture", "dockIconMediaScrollBehavior", "mediaWidgetScrollBehavior",
            "mediaWidgetScrollDirection",
            // Performance
            "screenCaptureCacheLifespan", "windowProcessingDebounceInterval",
            "windowPreviewImageScale", "windowImageCaptureQuality",
            // Live preview
            "enableLivePreview", "enableLivePreviewForDock", "enableLivePreviewForWindowSwitcher",
            "dockLivePreviewQuality", "dockLivePreviewFrameRate",
            "windowSwitcherLivePreviewQuality", "windowSwitcherLivePreviewFrameRate",
            "windowSwitcherLivePreviewScope", "livePreviewStreamKeepAlive",
            // Appearance
            "uniformCardRadius", "allowDynamicImageSizing", "previewHoverAction",
            "aeroShakeAction", "showSpecialAppControls", "useEmbeddedMediaControls",
            "useEmbeddedDockPreviewElements", "disableDockStyleTrafficLights",
            "disableDockStyleTitles", "showBigControlsWhenNoValidWindows",
            "enablePinning", "showAnimations", "gradientColorPalette",
            // Window switcher
            "enableWindowSwitcher", "instantWindowSwitcher", "enableDockPreviews",
            "showWindowsFromCurrentSpaceOnly", "windowPreviewSortOrder",
            "showWindowsFromCurrentSpaceOnlyInSwitcher", "windowSwitcherSortOrder",
            "showWindowsFromCurrentSpaceOnlyInCmdTab", "cmdTabSortOrder",
            "sortMinimizedToEnd", "enableCmdTabEnhancements", "cmdTabAutoSelectFirstWindow",
            "cmdTabCycleKey", "enableMouseHoverInSwitcher", "mouseHoverAutoScrollSpeed",
            "keepPreviewOnAppTerminate", "enableWindowSwitcherSearch", "searchTriggerKey",
            "searchFuzziness", "useClassicWindowOrdering",
            "includeHiddenWindowsInSwitcher", "includeHiddenWindowsInDockPreview",
            "includeHiddenWindowsInCmdTab", "ignoreAppsWithSingleWindow",
            "groupAppInstancesInDock", "useLiquidGlass",
            // UI
            "showMenuBarIcon", "raisedWindowLevel", "launched",
            "Int64maskCommand", "Int64maskControl", "Int64maskAlternate", "UserKeybind",
            "showAppName", "appNameStyle", "selectionOpacity", "unselectedContentOpacity",
            "hoverHighlightColor", "dockPreviewBackgroundOpacity",
            "hidePreviewCardBackground", "hideHoverContainerBackground",
            "hideWidgetContainerBackground", "showActiveWindowBorder",
            // Dock preview appearance
            "showWindowTitle", "showAppIconOnly", "windowTitleDisplayCondition",
            "windowTitleVisibility", "windowTitlePosition", "enableTitleMarquee",
            "trafficLightButtonsVisibility", "trafficLightButtonsPosition",
            "enabledTrafficLightButtons", "useMonochromeTrafficLights",
            "showMinimizedHiddenLabels",
            // Switcher appearance
            "switcherShowWindowTitle", "switcherWindowTitleVisibility",
            "switcherTrafficLightButtonsVisibility", "switcherEnabledTrafficLightButtons",
            "switcherUseMonochromeTrafficLights", "switcherDisableDockStyleTrafficLights",
            // Cmd+Tab appearance
            "cmdTabShowAppName", "cmdTabAppNameStyle", "cmdTabShowAppIconOnly",
            "cmdTabShowWindowTitle", "cmdTabWindowTitleVisibility", "cmdTabWindowTitlePosition",
            "cmdTabTrafficLightButtonsVisibility", "cmdTabTrafficLightButtonsPosition",
            "cmdTabEnabledTrafficLightButtons", "cmdTabUseMonochromeTrafficLights",
            "cmdTabControlPosition", "cmdTabUseEmbeddedDockPreviewElements",
            "cmdTabDisableDockStyleTrafficLights", "cmdTabDisableDockStyleTitles",
            // Grid / layout
            "previewMaxColumns", "previewMaxRows", "switcherMaxRows",
            "windowSwitcherScrollDirection",
            // Placement
            "windowSwitcherPlacementStrategy", "windowSwitcherControlPosition",
            "windowSwitcherHorizontalOffsetPercent", "windowSwitcherVerticalOffsetPercent",
            "windowSwitcherAnchorToTop", "enableShiftWindowSwitcherPlacement",
            "dockPreviewControlPosition", "pinnedScreenIdentifier",
            // Switcher filters
            "limitSwitcherToFrontmostApp", "fullscreenAppBlacklist",
            // Filters
            "appNameFilters", "windowTitleFilters", "groupedAppsInSwitcher",
            "customAppDirectories", "filteredCalendarIdentifiers",
            "hasSeenCmdTabFocusHint", "disableImagePreview", "debugMode",
            // Active app indicator
            "showActiveAppIndicator", "activeAppIndicatorColor",
            "activeAppIndicatorAutoSize", "activeAppIndicatorAutoLength",
            "activeAppIndicatorHeight", "activeAppIndicatorOffset",
            "activeAppIndicatorLength", "activeAppIndicatorShift",
            // Gestures
            "gestureSwipeThreshold", "enableDockPreviewGestures",
            "dockSwipeTowardsDockAction", "dockSwipeAwayFromDockAction",
            "enableWindowSwitcherGestures", "switcherSwipeUpAction", "switcherSwipeDownAction",
            // Middle click
            "middleClickAction",
            // Keyboard shortcuts
            "cmdShortcut1Key", "cmdShortcut1Action",
            "cmdShortcut2Key", "cmdShortcut2Action",
            "cmdShortcut3Key", "cmdShortcut3Action",
            // Alternate keybind
            "alternateKeybindKey", "alternateKeybindMode",
            // Compact mode
            "compactModeTitleFormat", "compactModeItemSize", "compactModeHideTrafficLights",
            "windowSwitcherCompactThreshold", "dockPreviewCompactThreshold", "cmdTabCompactThreshold",
            // Persisted state
            "persistedWindowOrder",
        ]
        for key in list { keys.insert(key) }
        return keys
    }()

    // MARK: - Export

    /// Presents a save panel and writes the current settings to a JSON file.
    static func exportSettings() {
        let panel = NSSavePanel()
        panel.title = String(localized: "Export DockDoor Settings")
        panel.nameFieldStringValue = "DockDoor-Settings.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let allDefaults = UserDefaults.standard.dictionaryRepresentation()
            var filtered: [String: Any] = [:]
            for (key, value) in allDefaults where knownKeys.contains(key) {
                filtered[key] = value
            }

            let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
            let dateFormatter = ISO8601DateFormatter()
            let exportDate = dateFormatter.string(from: Date())

            let wrapped: [String: Any] = [
                "appVersion": appVersion,
                "exportDate": exportDate,
                "settings": filtered,
            ]

            let jsonData = try JSONSerialization.data(withJSONObject: wrapped, options: [.prettyPrinted, .sortedKeys])
            try jsonData.write(to: url, options: .atomic)

            showSuccessAlert(
                title: String(localized: "Settings Exported"),
                message: String(localized: "Your settings have been saved to \(url.lastPathComponent).")
            )
        } catch {
            showErrorAlert(
                title: String(localized: "Export Failed"),
                message: error.localizedDescription
            )
        }
    }

    // MARK: - Import

    /// Presents an open panel, reads a JSON backup, and applies the settings.
    /// Keys present in the file but unknown to this version are silently skipped.
    /// Keys absent from the file keep their current values.
    static func importSettings() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "Import DockDoor Settings")
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try Data(contentsOf: url)

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                showErrorAlert(
                    title: String(localized: "Import Failed"),
                    message: String(localized: "The selected file does not contain valid DockDoor settings.")
                )
                return
            }

            // Validate structure
            guard let settings = json["settings"] as? [String: Any] else {
                showErrorAlert(
                    title: String(localized: "Import Failed"),
                    message: String(localized: "The selected file is missing the settings payload.")
                )
                return
            }

            let backupVersion = json["appVersion"] as? String ?? String(localized: "Unknown")
            let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"

            // Count how many keys we will actually apply vs skip
            let applicableKeys = settings.keys.filter { knownKeys.contains($0) }
            let skippedKeys = settings.keys.filter { !knownKeys.contains($0) }

            var confirmMessage = String(localized: "This will overwrite \(applicableKeys.count) setting(s) with values from the backup.")
            if !skippedKeys.isEmpty {
                confirmMessage += "\n" + String(localized: "\(skippedKeys.count) unrecognized key(s) will be skipped.")
            }
            if backupVersion != currentVersion {
                confirmMessage += "\n" + String(localized: "Note: This backup was created with app version \(backupVersion) (current: \(currentVersion)). Some settings may not apply.")
            }

            // Confirm before applying
            MessageUtil.showAlert(
                title: String(localized: "Import Settings?"),
                message: confirmMessage,
                actions: [.ok, .cancel]
            ) { action in
                guard action == .ok else { return }

                for (key, value) in settings where knownKeys.contains(key) {
                    UserDefaults.standard.set(value, forKey: key)
                }

                askUserToRestartApplication()
            }
        } catch {
            showErrorAlert(
                title: String(localized: "Import Failed"),
                message: error.localizedDescription
            )
        }
    }

    // MARK: - Alerts

    private static func showSuccessAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: String(localized: "OK"))
        alert.runModal()
    }

    private static func showErrorAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: String(localized: "OK"))
        alert.runModal()
    }
}

// MARK: - AnyCodableValue

/// A type-erased wrapper so arbitrary plist values survive `Codable` round-trips.
/// This is used only for the export envelope structure when using `Codable`; the actual
/// import/export uses `JSONSerialization` for maximum fidelity with UserDefaults types.
enum AnyCodableValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([AnyCodableValue])
    case dictionary([String: AnyCodableValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Bool.self) { self = .bool(v) }
        else if let v = try? container.decode(Int.self) { self = .int(v) }
        else if let v = try? container.decode(Double.self) { self = .double(v) }
        else if let v = try? container.decode(String.self) { self = .string(v) }
        else if let v = try? container.decode([AnyCodableValue].self) { self = .array(v) }
        else if let v = try? container.decode([String: AnyCodableValue].self) { self = .dictionary(v) }
        else { self = .null }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(v): try container.encode(v)
        case let .int(v): try container.encode(v)
        case let .double(v): try container.encode(v)
        case let .bool(v): try container.encode(v)
        case let .array(v): try container.encode(v)
        case let .dictionary(v): try container.encode(v)
        case .null: try container.encodeNil()
        }
    }
}
