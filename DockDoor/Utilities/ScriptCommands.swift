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

    enum WindowPosition: String, CaseIterable {
        case left
        case right
        case top
        case bottom
        case topLeft = "top-left"
        case topRight = "top-right"
        case bottomLeft = "bottom-left"
        case bottomRight = "bottom-right"

        // Also accept fill- prefix for backwards compatibility
        init?(rawValue: String) {
            let normalized = rawValue.lowercased().replacingOccurrences(of: "fill-", with: "")
            switch normalized {
            case "left": self = .left
            case "right": self = .right
            case "top": self = .top
            case "bottom": self = .bottom
            case "top-left", "topleft": self = .topLeft
            case "top-right", "topright": self = .topRight
            case "bottom-left", "bottomleft": self = .bottomLeft
            case "bottom-right", "bottomright": self = .bottomRight
            default: return nil
            }
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

    struct WindowData: Codable {
        let windowId: UInt32
        let windowName: String?
        let appName: String
        let bundleId: String?
        let pid: Int32
        let index: Int
        let appIndex: Int
        let frame: FrameData
        let spaceId: Int?
        let isMinimized: Bool
        let isHidden: Bool
        let createdAt: String
        let lastUsedAt: String
    }

    struct FrameData: Codable {
        let x: Double
        let y: Double
        let width: Double
        let height: Double
    }

    struct AppData: Codable {
        let name: String
        let bundleId: String?
        let pid: Int32
        let windowCount: Int
    }

    struct ActiveWindowData: Codable {
        let windowId: UInt32
        let windowName: String?
        let appName: String
        let bundleId: String?
        let pid: Int32
    }

    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func listWindows(appIdentifier: String? = nil, type: AppIdentifierType = .name) throws -> String {
        var allWindows = WindowUtil.getAllWindowsOfAllApps()

        // Filter by app if specified
        if let identifier = appIdentifier, !identifier.isEmpty {
            guard let app = findApp(identifier: identifier, type: type) else {
                throw CommandError.appNotFound(identifier)
            }
            allWindows = allWindows.filter { $0.app.processIdentifier == app.processIdentifier }
        }

        // Sort by last accessed time
        allWindows.sort { $0.lastAccessedTime > $1.lastAccessedTime }

        // Track app-specific indices
        var appWindowCounts: [pid_t: Int] = [:]

        let windowDataList: [WindowData] = allWindows.enumerated().map { index, window in
            let appIndex = appWindowCounts[window.app.processIdentifier] ?? 0
            appWindowCounts[window.app.processIdentifier] = appIndex + 1

            return WindowData(
                windowId: UInt32(window.id),
                windowName: window.windowName,
                appName: window.app.localizedName ?? "Unknown",
                bundleId: window.app.bundleIdentifier,
                pid: window.app.processIdentifier,
                index: index,
                appIndex: appIndex,
                frame: FrameData(
                    x: window.frame.origin.x,
                    y: window.frame.origin.y,
                    width: window.frame.size.width,
                    height: window.frame.size.height
                ),
                spaceId: window.spaceID,
                isMinimized: window.isMinimized,
                isHidden: window.isHidden,
                createdAt: dateFormatter.string(from: window.creationTime),
                lastUsedAt: dateFormatter.string(from: window.lastAccessedTime)
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(windowDataList)
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    static func listApps() throws -> String {
        let allWindows = WindowUtil.getAllWindowsOfAllApps()

        // Group windows by app
        var appWindows: [pid_t: (app: NSRunningApplication, count: Int)] = [:]
        for window in allWindows {
            let pid = window.app.processIdentifier
            if let existing = appWindows[pid] {
                appWindows[pid] = (existing.app, existing.count + 1)
            } else {
                appWindows[pid] = (window.app, 1)
            }
        }

        let appDataList: [AppData] = appWindows.values
            .map { app, count in
                AppData(
                    name: app.localizedName ?? "Unknown",
                    bundleId: app.bundleIdentifier,
                    pid: app.processIdentifier,
                    windowCount: count
                )
            }
            .sorted { $0.name.lowercased() < $1.name.lowercased() }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(appDataList)
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    static func getActiveWindow() throws -> String {
        guard let window = getActiveWindowInfo() else {
            throw CommandError.noActiveWindow
        }

        let activeData = ActiveWindowData(
            windowId: UInt32(window.id),
            windowName: window.windowName,
            appName: window.app.localizedName ?? "Unknown",
            bundleId: window.app.bundleIdentifier,
            pid: window.app.processIdentifier
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(activeData)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    // MARK: - Window Actions

    enum WindowActionType: String {
        case focus
        case minimize
        case close
        case maximize
        case hide
        case fullscreen
        case center
    }

    static func performWindowAction(_ action: WindowActionType, windowIdString: String) throws {
        let result = resolveWindowId(windowIdString)

        switch result {
        case let .failure(error):
            throw error
        case let .success((windowInfo, _)):
            var window = windowInfo

            switch action {
            case .focus:
                window.bringToFront()
            case .minimize:
                window.toggleMinimize()
            case .close:
                window.close()
            case .maximize:
                window.zoom()
            case .hide:
                window.toggleHidden()
            case .fullscreen:
                window.toggleFullScreen()
            case .center:
                window.centerWindow()
            }
        }
    }

    static func positionWindow(_ windowIdString: String, position: WindowPosition) throws {
        let result = resolveWindowId(windowIdString)

        switch result {
        case let .failure(error):
            throw error
        case let .success((windowInfo, _)):
            switch position {
            case .left:
                windowInfo.fillLeftHalf()
            case .right:
                windowInfo.fillRightHalf()
            case .top:
                windowInfo.fillTopHalf()
            case .bottom:
                windowInfo.fillBottomHalf()
            case .topLeft:
                windowInfo.fillTopLeftQuarter()
            case .topRight:
                windowInfo.fillTopRightQuarter()
            case .bottomLeft:
                windowInfo.fillBottomLeftQuarter()
            case .bottomRight:
                windowInfo.fillBottomRightQuarter()
            }
        }
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

        let action: DockDoorCommands.WindowActionType
        switch commandDescription.commandName {
        case "focus window":
            action = .focus
        case "minimize window":
            action = .minimize
        case "close window":
            action = .close
        case "maximize window":
            action = .maximize
        case "hide window":
            action = .hide
        case "toggle fullscreen":
            action = .fullscreen
        case "center window":
            action = .center
        default:
            return "error: Unknown action: \(String(describing: commandDescription.commandName))"
        }

        do {
            try DockDoorCommands.performWindowAction(action, windowIdString: windowId)
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

        guard let positionString = evaluatedArguments?["position"] as? String,
              let position = DockDoorCommands.WindowPosition(rawValue: positionString)
        else {
            return "error: Position required. Use: left, right, top, bottom, top-left, top-right, bottom-left, bottom-right"
        }

        do {
            try DockDoorCommands.positionWindow(windowId, position: position)
            return "ok"
        } catch {
            return "error: \(error.localizedDescription)"
        }
    }
}
