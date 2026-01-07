import AppKit
import Foundation

// MARK: - Shared Command Logic

/// Shared logic for DockDoor commands, used by AppleScript handlers
enum DockDoorCommands {
    enum AppIdentifierType: String {
        case name
        case bundle
        case pid
    }

    /// Parses position strings from AppleScript commands into WindowAction
    static func parsePositionAction(_ positionString: String) -> WindowAction? {
        let normalized = positionString.lowercased().replacingOccurrences(of: "fill-", with: "")
        switch normalized {
        case "left": return .fillLeftHalf
        case "right": return .fillRightHalf
        case "top": return .fillTopHalf
        case "bottom": return .fillBottomHalf
        case "top-left", "topleft": return .fillTopLeftQuarter
        case "top-right", "topright": return .fillTopRightQuarter
        case "bottom-left", "bottomleft": return .fillBottomLeftQuarter
        case "bottom-right", "bottomright": return .fillBottomRightQuarter
        default: return nil
        }
    }

    enum CommandError: Error, LocalizedError {
        case appNotFound(String)
        case windowNotFound(String)
        case noActiveWindow
        case coordinatorNotAvailable
        case invalidPosition(String)
        case invalidParameter(String)

        var errorDescription: String? {
            switch self {
            case let .appNotFound(identifier):
                "Application not found: \(identifier)"
            case let .windowNotFound(id):
                "Window not found: \(id)"
            case .noActiveWindow:
                "No active window found"
            case .coordinatorNotAvailable:
                "DockDoor coordinator not available"
            case let .invalidPosition(pos):
                "Invalid position: \(pos). Use: left, right, top, bottom, top-left, top-right, bottom-left, bottom-right"
            case let .invalidParameter(param):
                "Invalid parameter: \(param)"
            }
        }
    }

    // MARK: - App Resolution

    static func findApp(identifier: String, type: AppIdentifierType) -> NSRunningApplication? {
        switch type {
        case .name:
            return NSWorkspace.shared.runningApplications.first {
                $0.localizedName?.lowercased() == identifier.lowercased()
            }
        case .bundle:
            return NSRunningApplication.runningApplications(withBundleIdentifier: identifier).first
        case .pid:
            guard let pid = Int32(identifier) else { return nil }
            return NSRunningApplication(processIdentifier: pid)
        }
    }

    // MARK: - Window Resolution

    static func resolveWindowId(_ windowIdString: String) -> Result<(WindowInfo, UInt32), CommandError> {
        if windowIdString.lowercased() == "active" {
            guard let activeWindow = getActiveWindowInfo() else {
                return .failure(.noActiveWindow)
            }
            return .success((activeWindow, UInt32(activeWindow.id)))
        }

        guard let windowId = UInt32(windowIdString) else {
            return .failure(.invalidParameter("Window ID must be a number or 'active'"))
        }

        let allWindows = WindowUtil.getAllWindowsOfAllApps()
        guard let window = allWindows.first(where: { $0.id == CGWindowID(windowId) }) else {
            return .failure(.windowNotFound(windowIdString))
        }

        return .success((window, windowId))
    }

    static func getActiveWindowInfo() -> WindowInfo? {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let allWindows = WindowUtil.getAllWindowsOfAllApps()
        let appWindows = allWindows
            .filter { $0.app.processIdentifier == frontmostApp.processIdentifier }
            .sorted { $0.lastAccessedTime > $1.lastAccessedTime }

        return appWindows.first
    }

    // MARK: - Preview Commands

    static func showPreviewAsync(
        identifier: String,
        type: AppIdentifierType,
        position: NSPoint?,
        dockItemFrame: CGRect? = nil,
        useDelay: Bool = false
    ) {
        guard let app = findApp(identifier: identifier, type: type) else { return }

        Task { @MainActor in
            guard let coordinator = SharedPreviewWindowCoordinator.activeInstance else { return }
            guard let windows = try? await WindowUtil.getActiveWindows(of: app, context: .dockPreview) else { return }

            let mouseLocation = position ?? NSEvent.mouseLocation
            let screen = NSScreen.screenContainingMouse(mouseLocation)

            coordinator.showWindow(
                appName: app.localizedName ?? "Unknown",
                windows: windows,
                mouseLocation: mouseLocation,
                mouseScreen: screen,
                dockItemElement: nil,
                overrideDelay: dockItemFrame != nil ? !useDelay : true,
                onWindowTap: nil,
                bundleIdentifier: app.bundleIdentifier,
                bypassDockMouseValidation: true,
                dockPositionOverride: .cli,
                dockItemFrameOverride: dockItemFrame
            )
        }
    }

    static func hidePreviewAsync() {
        DispatchQueue.main.async {
            guard let coordinator = SharedPreviewWindowCoordinator.activeInstance else { return }

            // Don't hide if mouse is within the preview window - user is interacting with it
            if coordinator.mouseIsWithinPreviewWindow {
                return
            }

            coordinator.hideWindow()
        }
    }

    static func showSwitcherAsync() {
        Task { @MainActor in
            guard let coordinator = SharedPreviewWindowCoordinator.activeInstance else { return }

            let windows = WindowUtil.getAllWindowsOfAllApps()
            guard !windows.isEmpty else { return }

            let screen = NSScreen.main ?? NSScreen.screens.first!

            let wsCoordinator = coordinator.windowSwitcherCoordinator

            wsCoordinator.initializeForWindowSwitcher(
                with: windows,
                dockPosition: DockUtils.getDockPosition(),
                bestGuessMonitor: screen
            )
            wsCoordinator.activateKeybindSession()

            coordinator.showWindow(
                appName: "Window Switcher",
                windows: windows,
                mouseLocation: nil,
                mouseScreen: screen,
                dockItemElement: nil,
                overrideDelay: true,
                centeredHoverWindowState: .windowSwitcher,
                onWindowTap: nil
            )
        }
    }

    // MARK: - Query Commands

    private static let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static func encodeJSON(_ value: some Encodable) throws -> String {
        let data = try jsonEncoder.encode(value)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    static func listWindows(appIdentifier: String? = nil, type: AppIdentifierType = .name) throws -> String {
        var windows = WindowUtil.getAllWindowsOfAllApps()

        if let identifier = appIdentifier, !identifier.isEmpty {
            guard let app = findApp(identifier: identifier, type: type) else {
                throw CommandError.appNotFound(identifier)
            }
            windows = windows.filter { $0.app.processIdentifier == app.processIdentifier }
        }

        let sorted = WindowUtil.sortWindowsForSwitcher(windows)

        var appWindowCounts: [pid_t: Int] = [:]
        let result = sorted.enumerated().map { index, window -> [String: Any] in
            let appIndex = appWindowCounts[window.app.processIdentifier] ?? 0
            appWindowCounts[window.app.processIdentifier] = appIndex + 1
            return window.toJSON(index: index, appIndex: appIndex)
        }

        return try encodeJSON(result.map { JSONDictionary($0) })
    }

    static func listApps() throws -> String {
        let windows = WindowUtil.getAllWindowsOfAllApps()

        let grouped = Dictionary(grouping: windows) { $0.app.processIdentifier }
        let apps = grouped.values.compactMap { windows -> [String: Any]? in
            guard let first = windows.first else { return nil }
            return [
                "name": first.app.localizedName ?? "Unknown",
                "bundleId": first.app.bundleIdentifier as Any,
                "pid": first.app.processIdentifier,
                "windowCount": windows.count,
            ]
        }.sorted { ($0["name"] as? String ?? "").lowercased() < ($1["name"] as? String ?? "").lowercased() }

        return try encodeJSON(apps.map { JSONDictionary($0) })
    }

    static func getActiveWindow() throws -> String {
        guard let window = getActiveWindowInfo() else {
            throw CommandError.noActiveWindow
        }
        return try encodeJSON(JSONDictionary(window.toJSON()))
    }

    // MARK: - Window Data Commands (with images)

    /// Returns window info with cached image as base64 PNG
    static func getWindow(windowIdString: String) throws -> String {
        let (windowInfo, _) = try resolveWindowId(windowIdString).get()
        return try encodeJSON(JSONDictionary(windowInfo.toJSON(includeImage: true)))
    }

    /// Returns all windows with cached images as base64 PNG
    static func getWindows(appIdentifier: String? = nil, type: AppIdentifierType = .name) throws -> String {
        var windows = WindowUtil.getAllWindowsOfAllApps()

        if let identifier = appIdentifier, !identifier.isEmpty {
            guard let app = findApp(identifier: identifier, type: type) else {
                throw CommandError.appNotFound(identifier)
            }
            windows = windows.filter { $0.app.processIdentifier == app.processIdentifier }
        }

        let sorted = WindowUtil.sortWindowsForSwitcher(windows)

        var appWindowCounts: [pid_t: Int] = [:]
        let results = sorted.enumerated().map { index, window -> [String: Any] in
            let appIndex = appWindowCounts[window.app.processIdentifier] ?? 0
            appWindowCounts[window.app.processIdentifier] = appIndex + 1
            return window.toJSON(index: index, appIndex: appIndex, includeImage: true)
        }

        return try encodeJSON(results.map { JSONDictionary($0) })
    }

    /// Wrapper to make [String: Any] Encodable
    private struct JSONDictionary: Encodable {
        let dict: [String: Any]
        init(_ dict: [String: Any]) { self.dict = dict }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            for (key, value) in dict.sorted(by: { $0.key < $1.key }) {
                let codingKey = CodingKeys(stringValue: key)!
                switch value {
                case let v as String: try container.encode(v, forKey: codingKey)
                case let v as Int: try container.encode(v, forKey: codingKey)
                case let v as Int32: try container.encode(v, forKey: codingKey)
                case let v as UInt32: try container.encode(v, forKey: codingKey)
                case let v as Double: try container.encode(v, forKey: codingKey)
                case let v as Bool: try container.encode(v, forKey: codingKey)
                case let v as [String: Any]: try container.encode(JSONDictionary(v), forKey: codingKey)
                case Optional<Any>.none: try container.encodeNil(forKey: codingKey)
                default: break
                }
            }
        }

        struct CodingKeys: CodingKey {
            var stringValue: String
            init?(stringValue: String) { self.stringValue = stringValue }
            var intValue: Int? { nil }
            init?(intValue: Int) { nil }
        }
    }

    // MARK: - Help

    static func getHelp() -> String {
        // Auto-generate help from the .sdef file
        guard let sdefURL = Bundle.main.url(forResource: "DockDoor", withExtension: "sdef"),
              let sdefData = try? Data(contentsOf: sdefURL),
              let xml = try? XMLDocument(data: sdefData)
        else {
            return "Error: Could not load command definitions"
        }

        var lines: [String] = ["DockDoor AppleScript Commands", ""]

        // Find all commands in the DockDoor Suite
        guard let commands = try? xml.nodes(forXPath: "//suite[@name='DockDoor Suite']/command") else {
            return "Error: Could not parse command definitions"
        }

        for case let command as XMLElement in commands {
            guard let name = command.attribute(forName: "name")?.stringValue,
                  let description = command.attribute(forName: "description")?.stringValue
            else { continue }

            // Build command signature
            var signature = name

            // Add direct parameter if present
            if let directParam = try? command.nodes(forXPath: "direct-parameter").first as? XMLElement {
                let optional = directParam.attribute(forName: "optional")?.stringValue == "yes"
                let paramDesc = directParam.attribute(forName: "description")?.stringValue ?? "value"
                let placeholder = paramDesc.contains("Window ID") ? "<id>" : "<value>"
                signature += optional ? " [\(placeholder)]" : " \(placeholder)"
            }

            // Add named parameters
            if let params = try? command.nodes(forXPath: "parameter") {
                for case let param as XMLElement in params {
                    guard let paramName = param.attribute(forName: "name")?.stringValue else { continue }
                    let optional = param.attribute(forName: "optional")?.stringValue == "yes"
                    let paramPart = "\(paramName) <value>"
                    signature += optional ? " [\(paramPart)]" : " \(paramPart)"
                }
            }

            lines.append("  \(signature)")
            lines.append("      \(description)")
            lines.append("")
        }

        lines.append("EXAMPLES")
        lines.append("")
        lines.append("  -- Window actions (use window ID or \"active\")")
        lines.append("  focus window \"active\"")
        lines.append("  focus window \"12345\"")
        lines.append("  minimize window \"active\"")
        lines.append("  position window \"active\" to \"left\"")
        lines.append("  position window \"12345\" to \"top-right\"")
        lines.append("")
        lines.append("  -- App lookup by name (default)")
        lines.append("  show preview \"Safari\"")
        lines.append("  list windows \"Finder\"")
        lines.append("")
        lines.append("  -- App lookup by bundle ID")
        lines.append("  show preview \"com.apple.Safari\" by \"bundle\"")
        lines.append("  list windows \"com.apple.finder\" by \"bundle\"")
        lines.append("")
        lines.append("  -- App lookup by process ID")
        lines.append("  show preview \"1234\" by \"pid\"")
        lines.append("")
        lines.append("  -- Positions: left, right, top, bottom,")
        lines.append("  --            top-left, top-right, bottom-left, bottom-right")
        lines.append("")
        lines.append("USAGE: tell application \"DockDoor\" to <command>")

        return lines.joined(separator: "\n")
    }

    // MARK: - Window Actions

    /// Maps AppleScript command names to WindowAction
    static func actionFromCommandName(_ commandName: String) -> WindowAction? {
        switch commandName {
        case "minimize window": .minimize
        case "close window": .close
        case "maximize window": .maximize
        case "hide window": .hide
        case "toggle fullscreen": .toggleFullScreen
        case "center window": .center
        default: nil
        }
    }

    static func performWindowAction(_ action: WindowAction, windowIdString: String) throws {
        let windowInfo = try resolveWindowId(windowIdString).get().0
        _ = action.perform(on: windowInfo)
    }

    static func focusWindow(_ windowIdString: String) throws {
        var windowInfo = try resolveWindowId(windowIdString).get().0
        windowInfo.bringToFront()
    }

    static func positionWindow(_ windowIdString: String, positionString: String) throws {
        guard let action = parsePositionAction(positionString) else {
            throw CommandError.invalidPosition(positionString)
        }
        let windowInfo = try resolveWindowId(windowIdString).get().0
        _ = action.perform(on: windowInfo)
    }
}

// MARK: - AppleScript Command Handlers

@objc(ShowPreviewCommand)
class ShowPreviewCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        let identifier = directParameter as? String ?? ""
        let identifierType = DockDoorCommands.AppIdentifierType(
            rawValue: (evaluatedArguments?["identifierType"] as? String ?? "name").lowercased()
        ) ?? .name

        var position: NSPoint?
        if let posString = evaluatedArguments?["position"] as? String {
            let parts = posString.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            if parts.count == 2 {
                position = NSPoint(x: parts[0], y: parts[1])
            }
        }

        var dockItemFrame: CGRect?
        if let frameString = evaluatedArguments?["dockFrame"] as? String {
            let parts = frameString.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            if parts.count == 4 {
                dockItemFrame = CGRect(x: parts[0], y: parts[1], width: parts[2], height: parts[3])
            }
        }

        let useDelay = evaluatedArguments?["withDelay"] as? Bool ?? false

        DockDoorCommands.showPreviewAsync(
            identifier: identifier,
            type: identifierType,
            position: position,
            dockItemFrame: dockItemFrame,
            useDelay: useDelay
        )
        return "ok"
    }
}

@objc(HidePreviewCommand)
class HidePreviewCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        DockDoorCommands.hidePreviewAsync()
        return "ok"
    }
}

@objc(ShowSwitcherCommand)
class ShowSwitcherCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        DockDoorCommands.showSwitcherAsync()
        return "ok"
    }
}

@objc(ListWindowsCommand)
class ListWindowsCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        let appIdentifier = directParameter as? String
        let identifierType = DockDoorCommands.AppIdentifierType(
            rawValue: (evaluatedArguments?["identifierType"] as? String ?? "name").lowercased()
        ) ?? .name

        do {
            return try DockDoorCommands.listWindows(appIdentifier: appIdentifier, type: identifierType)
        } catch {
            return "error: \(error.localizedDescription)"
        }
    }
}

@objc(ListAppsCommand)
class ListAppsCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        do {
            return try DockDoorCommands.listApps()
        } catch {
            return "error: \(error.localizedDescription)"
        }
    }
}

@objc(GetActiveWindowCommand)
class GetActiveWindowCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        do {
            return try DockDoorCommands.getActiveWindow()
        } catch {
            return "error: \(error.localizedDescription)"
        }
    }
}

@objc(WindowActionCommand)
class WindowActionCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        guard let windowId = directParameter as? String else {
            return "error: Window ID required"
        }

        do {
            // Focus is handled separately since it's not in WindowAction
            if commandDescription.commandName == "focus window" {
                try DockDoorCommands.focusWindow(windowId)
            } else if let action = DockDoorCommands.actionFromCommandName(commandDescription.commandName) {
                try DockDoorCommands.performWindowAction(action, windowIdString: windowId)
            } else {
                return "error: Unknown action: \(String(describing: commandDescription.commandName))"
            }
            return "ok"
        } catch {
            return "error: \(error.localizedDescription)"
        }
    }
}

@objc(PositionWindowCommand)
class PositionWindowCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        guard let windowId = directParameter as? String else {
            return "error: Window ID required"
        }

        guard let positionString = evaluatedArguments?["position"] as? String else {
            return "error: Position required. Use: left, right, top, bottom, top-left, top-right, bottom-left, bottom-right"
        }

        do {
            try DockDoorCommands.positionWindow(windowId, positionString: positionString)
            return "ok"
        } catch {
            return "error: \(error.localizedDescription)"
        }
    }
}

@objc(GetHelpCommand)
class GetHelpCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        DockDoorCommands.getHelp()
    }
}

@objc(GetWindowCommand)
class GetWindowCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        guard let windowId = directParameter as? String else {
            return "error: Window ID required"
        }

        do {
            return try DockDoorCommands.getWindow(windowIdString: windowId)
        } catch {
            return "error: \(error.localizedDescription)"
        }
    }
}

@objc(GetWindowsCommand)
class GetWindowsCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        let appIdentifier = directParameter as? String
        let identifierType = DockDoorCommands.AppIdentifierType(
            rawValue: (evaluatedArguments?["identifierType"] as? String ?? "name").lowercased()
        ) ?? .name

        do {
            return try DockDoorCommands.getWindows(appIdentifier: appIdentifier, type: identifierType)
        } catch {
            return "error: \(error.localizedDescription)"
        }
    }
}

// MARK: - WindowInfo JSON Extension

private let iso8601Formatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
}()

extension WindowInfo {
    /// Convert to JSON dictionary for script commands
    func toJSON(index: Int? = nil, appIndex: Int? = nil, includeImage: Bool = false) -> [String: Any] {
        var dict: [String: Any] = [
            "windowId": UInt32(id),
            "windowName": windowName as Any,
            "appName": app.localizedName ?? "Unknown",
            "bundleId": app.bundleIdentifier as Any,
            "pid": app.processIdentifier,
            "frame": [
                "x": frame.origin.x,
                "y": frame.origin.y,
                "width": frame.size.width,
                "height": frame.size.height,
            ],
            "spaceId": spaceID as Any,
            "isMinimized": isMinimized,
            "isHidden": isHidden,
            "createdAt": iso8601Formatter.string(from: creationTime),
            "lastUsedAt": iso8601Formatter.string(from: lastAccessedTime),
        ]

        if let index {
            dict["index"] = index
            dict["appIndex"] = appIndex ?? 0
        }

        if includeImage {
            dict["imageCapturedAt"] = iso8601Formatter.string(from: imageCapturedTime)
            if let cgImage = image {
                let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
                if let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                    dict["image"] = pngData.base64EncodedString()
                    dict["imageWidth"] = cgImage.width
                    dict["imageHeight"] = cgImage.height
                }
            }
        }

        return dict
    }
}
