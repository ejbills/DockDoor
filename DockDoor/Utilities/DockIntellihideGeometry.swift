import ApplicationServices
import Cocoa

struct DockIntellihideWindowSample: Equatable {
    let pid: pid_t
    let windowID: CGWindowID?
    let frame: CGRect
    let isFullscreen: Bool
}

struct DockIntellihideContext {
    let screen: NSScreen
    let dockRegion: CGRect
    let releaseRegion: CGRect
}

/// Resolves the window and Dock geometry that the intellihide policy needs.
final class DockIntellihideGeometry {
    private let fallbackDockThickness: CGFloat = 72
    private let releasePadding: CGFloat = 2
    private let bottomDockVisualPadding: CGFloat = 2
    private let sideDockVisualPadding: CGFloat = 2
    // Dock AX geometry is expensive to read and changes rarely, so keep a short
    // live refresh interval instead of walking the Dock tree on every poll.
    private let liveDockFrameRefreshInterval: TimeInterval = 0.35

    private var cachedDockThickness: [String: CGFloat] = [:]
    private var cachedDockFrame: CGRect?
    private var lastLiveDockFrameRefreshAt: Date?

    // MARK: - Window Sampling

    func sample(for app: NSRunningApplication) -> DockIntellihideWindowSample? {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        guard let window = try? appElement.focusedWindow(),
              let position = try? window.position(),
              let size = try? window.size()
        else {
            return nil
        }

        let frame = CGRect(origin: position, size: size)
        guard !frame.isNull, !frame.isEmpty else { return nil }

        return DockIntellihideWindowSample(
            pid: app.processIdentifier,
            windowID: try? window.cgWindowId(),
            frame: frame,
            isFullscreen: (try? window.isFullscreen()) ?? false
        )
    }

    // MARK: - Transition Detection

    func shouldForceHideTransition(from oldSample: DockIntellihideWindowSample?, to newSample: DockIntellihideWindowSample, dockInfluenceRegion: CGRect, minimumFrameDeltaToDetectTransition: CGFloat) -> Bool {
        guard let oldSample else { return false }
        guard oldSample.pid == newSample.pid else { return false }

        if let oldWindowID = oldSample.windowID, let newWindowID = newSample.windowID, oldWindowID != newWindowID {
            return false
        }

        if oldSample.isFullscreen != newSample.isFullscreen {
            return true
        }

        let deltaX = abs(oldSample.frame.origin.x - newSample.frame.origin.x)
        let deltaY = abs(oldSample.frame.origin.y - newSample.frame.origin.y)
        let deltaWidth = abs(oldSample.frame.size.width - newSample.frame.size.width)
        let deltaHeight = abs(oldSample.frame.size.height - newSample.frame.size.height)

        let hasMeaningfulFrameChange = deltaX > minimumFrameDeltaToDetectTransition ||
            deltaY > minimumFrameDeltaToDetectTransition ||
            deltaWidth > minimumFrameDeltaToDetectTransition ||
            deltaHeight > minimumFrameDeltaToDetectTransition

        guard hasMeaningfulFrameChange else { return false }
        return oldSample.frame.intersects(dockInfluenceRegion) || newSample.frame.intersects(dockInfluenceRegion)
    }

    // MARK: - Screen and Dock Resolution

    func screen(for frame: CGRect) -> NSScreen? {
        let screenFrames = axScreenFrames()

        if let containingScreen = screenFrames.first(where: { $0.frame.contains(frame.center) })?.screen {
            return containingScreen
        }

        return screenFrames.max { lhs, rhs in
            lhs.frame.intersection(frame).area < rhs.frame.intersection(frame).area
        }?.screen
    }

    func dockContext(preferCached: Bool) -> DockIntellihideContext? {
        guard let screen = dockScreen(preferCached: preferCached) else { return nil }

        let position = DockUtils.getDockPosition()
        let dockFrame = resolvedDockFrame(preferCached: preferCached)
        // We keep separate enter/leave regions so the Dock does not flicker when a
        // window edge sits right on the boundary.
        let dockRegion = stabilizedDockRegion(for: screen, position: position, dockFrame: dockFrame)
        let releaseRegion = releaseRegion(for: dockRegion, position: position)
        return DockIntellihideContext(screen: screen, dockRegion: dockRegion, releaseRegion: releaseRegion)
    }

    /// AX window frames use the same global, top-left-origin coordinate space as
    /// CG event taps. Checking against only the top slice lets the manager hide
    /// immediately for title-bar double-click zoom/fullscreen without reacting to
    /// ordinary double-clicks inside the content area.
    func titleBarRegion(for frame: CGRect, detectionHeight: CGFloat) -> CGRect {
        let height = min(detectionHeight, frame.height)
        return CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: height)
    }

    private func dockScreen(preferCached: Bool) -> NSScreen? {
        if let dockFrame = resolvedDockFrame(preferCached: preferCached) {
            return screen(for: dockFrame)
        }

        let position = DockUtils.getDockPosition()
        let screenWithInset = NSScreen.screens.max { lhs, rhs in
            measuredDockThickness(for: lhs, position: position) < measuredDockThickness(for: rhs, position: position)
        }

        if let screenWithInset, measuredDockThickness(for: screenWithInset, position: position) > 0 {
            return screenWithInset
        }

        return NSScreen.main
    }

    private func currentDockFrame() -> CGRect? {
        DockAccessibility.currentDockFrame()
    }

    private func stabilizedDockRegion(for screen: NSScreen, position: DockPosition, dockFrame: CGRect?) -> CGRect {
        if let dockFrame {
            return stabilizedDockRegion(for: screen, position: position, dockFrame: dockFrame)
        }

        let measuredThickness = measuredDockThickness(for: screen, position: position)
        let cacheKey = "\(screen.uniqueIdentifier())-\(position.storageKey)"
        let thickness = resolvedDockThickness(measuredThickness: measuredThickness, cacheKey: cacheKey) + visualPadding(for: position)
        let screenFrame = axScreenFrame(for: screen)

        switch position {
        case .left:
            return CGRect(x: screenFrame.minX, y: screenFrame.minY, width: thickness, height: screenFrame.height)
        case .right:
            return CGRect(x: screenFrame.maxX - thickness, y: screenFrame.minY, width: thickness, height: screenFrame.height)
        case .top:
            return CGRect(x: screenFrame.minX, y: screenFrame.minY, width: screenFrame.width, height: thickness)
        case .bottom, .unknown, .cmdTab, .cli:
            return CGRect(x: screenFrame.minX, y: screenFrame.maxY - thickness, width: screenFrame.width, height: thickness)
        }
    }

    private func stabilizedDockRegion(for screen: NSScreen, position: DockPosition, dockFrame: CGRect) -> CGRect {
        let screenFrame = axScreenFrame(for: screen)
        let padding = visualPadding(for: position)

        switch position {
        case .left:
            return CGRect(
                x: screenFrame.minX,
                y: screenFrame.minY,
                width: max(dockFrame.maxX - screenFrame.minX + padding, fallbackDockThickness),
                height: screenFrame.height
            )
        case .right:
            let minX = max(dockFrame.minX - padding, screenFrame.minX)
            return CGRect(
                x: minX,
                y: screenFrame.minY,
                width: max(screenFrame.maxX - minX, fallbackDockThickness),
                height: screenFrame.height
            )
        case .top:
            return CGRect(
                x: screenFrame.minX,
                y: screenFrame.minY,
                width: screenFrame.width,
                height: max(dockFrame.maxY - screenFrame.minY + padding, fallbackDockThickness)
            )
        case .bottom, .unknown, .cmdTab, .cli:
            let minY = max(dockFrame.minY - padding, screenFrame.minY)
            return CGRect(
                x: screenFrame.minX,
                y: minY,
                width: screenFrame.width,
                height: max(screenFrame.maxY - minY, fallbackDockThickness)
            )
        }
    }

    private func measuredDockThickness(for screen: NSScreen, position: DockPosition) -> CGFloat {
        switch position {
        case .left:
            screen.visibleFrame.minX - screen.frame.minX
        case .right:
            screen.frame.maxX - screen.visibleFrame.maxX
        case .top:
            screen.frame.maxY - screen.visibleFrame.maxY
        case .bottom, .unknown, .cmdTab, .cli:
            screen.visibleFrame.minY - screen.frame.minY
        }
    }

    private func resolvedDockFrame(preferCached: Bool) -> CGRect? {
        if preferCached, let cachedDockFrame {
            return cachedDockFrame
        }

        if let cachedDockFrame,
           let lastLiveDockFrameRefreshAt,
           Date().timeIntervalSince(lastLiveDockFrameRefreshAt) < liveDockFrameRefreshInterval
        {
            return cachedDockFrame
        }

        if let liveDockFrame = currentDockFrame() {
            cachedDockFrame = liveDockFrame
            lastLiveDockFrameRefreshAt = Date()
            return liveDockFrame
        }

        return cachedDockFrame
    }

    private func resolvedDockThickness(measuredThickness: CGFloat, cacheKey: String) -> CGFloat {
        if measuredThickness > 0 {
            cachedDockThickness[cacheKey] = measuredThickness
            return measuredThickness
        }

        if let cachedThickness = cachedDockThickness[cacheKey] {
            return cachedThickness
        }

        return fallbackDockThickness
    }

    private func releaseRegion(for dockRegion: CGRect, position: DockPosition) -> CGRect {
        switch position {
        case .left, .right:
            dockRegion.insetBy(dx: -releasePadding, dy: 0)
        case .top, .bottom, .unknown, .cmdTab, .cli:
            dockRegion.insetBy(dx: 0, dy: -releasePadding)
        }
    }

    private func visualPadding(for position: DockPosition) -> CGFloat {
        switch position {
        case .left, .right:
            sideDockVisualPadding
        case .top, .bottom, .unknown, .cmdTab, .cli:
            bottomDockVisualPadding
        }
    }

    // AppKit screen frames use a bottom-left origin while AX window frames and Dock
    // item frames use a top-left origin, so convert screen bounds once here.
    private func axScreenFrames() -> [(screen: NSScreen, frame: CGRect)] {
        let screens = NSScreen.screens
        let globalMaxY = screens.map(\.frame.maxY).max() ?? NSScreen.main?.frame.maxY ?? 0

        return screens.map { screen in
            (
                screen,
                CGRect(
                    x: screen.frame.minX,
                    y: globalMaxY - screen.frame.maxY,
                    width: screen.frame.width,
                    height: screen.frame.height
                )
            )
        }
    }

    private func axScreenFrame(for screen: NSScreen) -> CGRect {
        axScreenFrames().first(where: { $0.screen.uniqueIdentifier() == screen.uniqueIdentifier() })?.frame ?? screen.frame
    }
}

private extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }

    var area: CGFloat {
        width * height
    }
}

private extension DockPosition {
    var storageKey: String {
        switch self {
        case .top:
            "top"
        case .bottom:
            "bottom"
        case .left:
            "left"
        case .right:
            "right"
        case .cmdTab:
            "cmdTab"
        case .cli:
            "cli"
        case .unknown:
            "unknown"
        }
    }
}
