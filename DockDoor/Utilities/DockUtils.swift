import Cocoa

enum DockPosition {
    case top
    case bottom
    case left
    case right
    case cmdTab
    case cli
    case unknown

    var isHorizontalFlow: Bool {
        switch self {
        case .top, .bottom, .cmdTab, .cli:
            true
        case .left, .right:
            false
        case .unknown:
            true
        }
    }
}

class DockUtils {
    static var runningDock: NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: dockAppIdentifier).first
    }

    static func getDockPosition() -> DockPosition {
        var orientation: Int32 = 0
        var pinning: Int32 = 0
        CoreDockGetOrientationAndPinning(&orientation, &pinning)
        switch orientation {
        case 1: return .top
        case 2: return .bottom
        case 3: return .left
        case 4: return .right
        default: return .unknown
        }
    }

    private static func dockListFrame(pid: pid_t) -> CGRect? {
        guard let list = try? AXUIElementCreateApplication(pid).children()?
            .first(where: { (try? $0.role()) == kAXListRole }),
            let position = try? list.position(),
            let size = try? list.size()
        else { return nil }
        return CGRect(origin: position, size: size)
    }

    static func dockScreen() -> NSScreen? {
        guard let dockApp = DockUtils.runningDock,
              let listFrame = dockListFrame(pid: dockApp.processIdentifier)
        else { return nil }

        let screens = NSScreen.screens
        guard let index = DockLockerGeometry.screenIndexHoldingDock(
            dockRect: listFrame,
            screenFrames: screens.map(\.cgFrame),
            dockPosition: getDockPosition()
        ) else { return nil }
        return screens[index]
    }

    static let mouseExitedEventType = CGEventType(rawValue: UInt32(NSEvent.EventType.mouseExited.rawValue))!

    static func dockRevealTarget() -> (pid: pid_t, revealPoint: CGPoint, dockRegion: CGRect)? {
        guard let dockApp = runningDock,
              let list = dockListFrame(pid: dockApp.processIdentifier)
        else { return nil }

        let position = getDockPosition()
        let screens = NSScreen.screens.map(\.cgFrame)
        guard let index = DockLockerGeometry.screenIndexHoldingDock(dockRect: list, screenFrames: screens, dockPosition: position) else { return nil }
        let screen = screens[index]
        let pid = dockApp.processIdentifier

        switch position {
        case .bottom:
            let x = min(max((screen.minX + list.minX) / 2, screen.minX + 32), list.minX)
            let region = CGRect(x: list.minX, y: list.minY, width: list.width, height: max(0, screen.maxY - list.minY))
            return (pid, CGPoint(x: x, y: screen.maxY - 1), region)
        case .left:
            let y = min(max((screen.minY + list.minY) / 2, screen.minY + 32), list.minY)
            let region = CGRect(x: screen.minX, y: list.minY, width: max(0, list.maxX - screen.minX), height: list.height)
            return (pid, CGPoint(x: screen.minX, y: y), region)
        case .right:
            let y = min(max((screen.minY + list.minY) / 2, screen.minY + 32), list.minY)
            let region = CGRect(x: list.minX, y: list.minY, width: max(0, screen.maxX - list.minX), height: list.height)
            return (pid, CGPoint(x: screen.maxX - 1, y: y), region)
        case .top, .cmdTab, .cli, .unknown:
            return nil
        }
    }

    static func postMouseEvent(_ type: CGEventType, at point: CGPoint, toDock pid: pid_t) {
        guard let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left) else { return }
        event.type = type
        event.postToPid(pid)
    }

    /// Returns the dock size in points based on the screen's visible frame.
    static func getDockSize(on screen: NSScreen? = nil) -> CGFloat {
        let dockPosition = getDockPosition()

        if let screen {
            return dockSize(on: screen, dockPosition: dockPosition)
        }

        return NSScreen.screens
            .map { dockSize(on: $0, dockPosition: dockPosition) }
            .max() ?? 0
    }

    private static func dockSize(on screen: NSScreen, dockPosition: DockPosition) -> CGFloat {
        switch dockPosition {
        case .right:
            screen.frame.maxX - screen.visibleFrame.maxX
        case .left:
            screen.visibleFrame.minX - screen.frame.minX
        case .bottom:
            screen.visibleFrame.minY - screen.frame.minY
        case .top:
            screen.frame.maxY - screen.visibleFrame.maxY
        case .cmdTab, .cli, .unknown:
            0
        }
    }
}
