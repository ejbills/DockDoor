import AppKit

/// Handles dockdoor-cli:// URL scheme commands
enum URLCommandHandler {
    static func handle(_ url: URL) {
        guard url.scheme == "dockdoor-cli" else { return }

        let command = url.host ?? ""
        let params = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let paramDict = Dictionary(uniqueKeysWithValues: params.compactMap { item in
            item.value.map { (item.name, $0) }
        })

        // Parse optional position
        let position: NSPoint? = {
            guard let xStr = paramDict["x"], let yStr = paramDict["y"],
                  let x = Double(xStr), let y = Double(yStr) else { return nil }
            return NSPoint(x: x, y: y)
        }()

        switch command {
        // Preview commands
        case "show-preview":
            if let app = paramDict["app"] {
                showPreview(appName: app, at: position)
            } else if let pid = paramDict["pid"].flatMap(Int32.init) {
                showPreview(pid: pid, at: position)
            } else if let bundleId = paramDict["bundle"] {
                showPreview(bundleId: bundleId, at: position)
            }
        case "hide-preview":
            hidePreview()
        case "trigger-switcher":
            triggerWindowSwitcher()
        // Window actions
        case "focus":
            if let id = paramDict["window"].flatMap(UInt32.init) {
                performWindowAction(.focus, windowId: id)
            }
        case "minimize":
            if let id = paramDict["window"].flatMap(UInt32.init) {
                performWindowAction(.minimize, windowId: id)
            }
        case "close":
            if let id = paramDict["window"].flatMap(UInt32.init) {
                performWindowAction(.close, windowId: id)
            }
        case "maximize":
            if let id = paramDict["window"].flatMap(UInt32.init) {
                performWindowAction(.maximize, windowId: id)
            }
        case "hide":
            if let id = paramDict["window"].flatMap(UInt32.init) {
                performWindowAction(.hide, windowId: id)
            }
        case "fullscreen":
            if let id = paramDict["window"].flatMap(UInt32.init) {
                performWindowAction(.toggleFullScreen, windowId: id)
            }
        case "center":
            if let id = paramDict["window"].flatMap(UInt32.init) {
                performWindowAction(.center, windowId: id)
            }
        // Window positioning
        case "fill-left":
            if let id = paramDict["window"].flatMap(UInt32.init) {
                performWindowAction(.fillLeftHalf, windowId: id)
            }
        case "fill-right":
            if let id = paramDict["window"].flatMap(UInt32.init) {
                performWindowAction(.fillRightHalf, windowId: id)
            }
        case "fill-top":
            if let id = paramDict["window"].flatMap(UInt32.init) {
                performWindowAction(.fillTopHalf, windowId: id)
            }
        case "fill-bottom":
            if let id = paramDict["window"].flatMap(UInt32.init) {
                performWindowAction(.fillBottomHalf, windowId: id)
            }
        case "fill-top-left":
            if let id = paramDict["window"].flatMap(UInt32.init) {
                performWindowAction(.fillTopLeftQuarter, windowId: id)
            }
        case "fill-top-right":
            if let id = paramDict["window"].flatMap(UInt32.init) {
                performWindowAction(.fillTopRightQuarter, windowId: id)
            }
        case "fill-bottom-left":
            if let id = paramDict["window"].flatMap(UInt32.init) {
                performWindowAction(.fillBottomLeftQuarter, windowId: id)
            }
        case "fill-bottom-right":
            if let id = paramDict["window"].flatMap(UInt32.init) {
                performWindowAction(.fillBottomRightQuarter, windowId: id)
            }
        default:
            print("URLCommandHandler: Unknown command '\(command)'")
        }
    }

    // MARK: - Preview Commands

    private static func showPreview(appName: String, at position: NSPoint?) {
        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.localizedName?.lowercased() == appName.lowercased()
        }) else { return }
        showPreview(for: app, at: position)
    }

    private static func showPreview(pid: Int32, at position: NSPoint?) {
        guard let app = NSRunningApplication(processIdentifier: pid) else { return }
        showPreview(for: app, at: position)
    }

    private static func showPreview(bundleId: String, at position: NSPoint?) {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first else { return }
        showPreview(for: app, at: position)
    }

    private static func showPreview(for app: NSRunningApplication, at position: NSPoint?) {
        guard let coordinator = SharedPreviewWindowCoordinator.activeInstance else { return }

        Task { @MainActor in
            guard let windows = try? await WindowUtil.getActiveWindows(of: app, context: .dockPreview) else { return }
            let mouseLocation = position ?? NSEvent.mouseLocation
            let screen = NSScreen.screenContainingMouse(mouseLocation)

            coordinator.showWindow(
                appName: app.localizedName ?? "Unknown",
                windows: windows,
                mouseLocation: mouseLocation,
                mouseScreen: screen,
                dockItemElement: nil,
                overrideDelay: true,
                onWindowTap: nil,
                bundleIdentifier: app.bundleIdentifier,
                bypassDockMouseValidation: true,
                dockPositionOverride: .cli
            )
        }
    }

    private static func hidePreview() {
        SharedPreviewWindowCoordinator.activeInstance?.hideWindow()
    }

    private static func triggerWindowSwitcher() {
        guard let coordinator = SharedPreviewWindowCoordinator.activeInstance else { return }

        Task { @MainActor in
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

    // MARK: - Window Actions

    private enum SimpleAction {
        case focus, minimize, close, maximize, hide, toggleFullScreen, center
        case fillLeftHalf, fillRightHalf, fillTopHalf, fillBottomHalf
        case fillTopLeftQuarter, fillTopRightQuarter, fillBottomLeftQuarter, fillBottomRightQuarter
    }

    private static func performWindowAction(_ action: SimpleAction, windowId: UInt32) {
        let allWindows = WindowUtil.getAllWindowsOfAllApps()
        guard var window = allWindows.first(where: { $0.id == CGWindowID(windowId) }) else { return }

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
        case .toggleFullScreen:
            window.toggleFullScreen()
        case .center:
            window.centerWindow()
        case .fillLeftHalf:
            window.fillLeftHalf()
        case .fillRightHalf:
            window.fillRightHalf()
        case .fillTopHalf:
            window.fillTopHalf()
        case .fillBottomHalf:
            window.fillBottomHalf()
        case .fillTopLeftQuarter:
            window.fillTopLeftQuarter()
        case .fillTopRightQuarter:
            window.fillTopRightQuarter()
        case .fillBottomLeftQuarter:
            window.fillBottomLeftQuarter()
        case .fillBottomRightQuarter:
            window.fillBottomRightQuarter()
        }
    }
}
