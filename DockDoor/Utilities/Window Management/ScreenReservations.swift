import AppKit
import Defaults

enum ScreenReservationEdge: String, CaseIterable, Identifiable, Defaults.Serializable {
    case none
    case bottom
    case left
    case right
    case top

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .none: String(localized: "Off", comment: "Reserved screen edge option")
        case .bottom: String(localized: "Bottom", comment: "Reserved screen edge option")
        case .left: String(localized: "Left", comment: "Reserved screen edge option")
        case .right: String(localized: "Right", comment: "Reserved screen edge option")
        case .top: String(localized: "Top", comment: "Reserved screen edge option")
        }
    }
}

struct ScreenReservation: Equatable {
    static let allDisplays = ""
    static let maximumFraction: CGFloat = 0.4

    let edge: ScreenReservationEdge
    let thickness: CGFloat
    let display: String

    func applies(to screen: NSScreen) -> Bool {
        switch display {
        case Self.allDisplays:
            true
        case NSScreen.systemMainDisplayIdentifier, "main":
            screen == NSScreen.systemMain
        default:
            screen.uniqueIdentifier().caseInsensitiveCompare(display) == .orderedSame
                || screen.displayID.map { String($0) } == display
        }
    }

    static func usableFrame(visibleFrame: CGRect, screenFrame: CGRect, reservations: [ScreenReservation]) -> CGRect {
        var frame = visibleFrame
        for reservation in reservations where reservation.edge != .none && reservation.thickness > 0 {
            switch reservation.edge {
            case .bottom:
                let edge = screenFrame.minY + min(reservation.thickness, screenFrame.height * maximumFraction)
                if frame.minY < edge {
                    frame.size.height -= edge - frame.minY
                    frame.origin.y = edge
                }
            case .top:
                let edge = visibleFrame.maxY - min(reservation.thickness, screenFrame.height * maximumFraction)
                if frame.maxY > edge {
                    frame.size.height = edge - frame.minY
                }
            case .left:
                let edge = screenFrame.minX + min(reservation.thickness, screenFrame.width * maximumFraction)
                if frame.minX < edge {
                    frame.size.width -= edge - frame.minX
                    frame.origin.x = edge
                }
            case .right:
                let edge = screenFrame.maxX - min(reservation.thickness, screenFrame.width * maximumFraction)
                if frame.maxX > edge {
                    frame.size.width = edge - frame.minX
                }
            case .none:
                break
            }
        }
        guard frame.width > 0, frame.height > 0 else { return visibleFrame }
        return frame
    }

    static func parse(edge: String?, thickness: Double?, display: String?) -> ScreenReservation? {
        guard let edgeName = edge?.lowercased(), let reservedEdge = ScreenReservationEdge(rawValue: edgeName) else { return nil }
        let value = CGFloat(thickness ?? 0)
        guard value.isFinite, value >= 0 else { return nil }
        return ScreenReservation(edge: reservedEdge, thickness: value, display: display ?? allDisplays)
    }
}

final class ScreenReservations: @unchecked Sendable {
    struct Report: Equatable {
        let source: String
        let reservation: ScreenReservation
    }

    static let shared = ScreenReservations()
    static let reportNotification = Notification.Name("com.ethanbills.DockDoor.reserveScreenEdge")
    static let requestNotification = Notification.Name("com.ethanbills.DockDoor.requestScreenReservations")
    static let reportsDidChange = Notification.Name("com.ethanbills.DockDoor.screenReservationsDidChange")

    private let lock = NSLock()
    private var reported: [String: ScreenReservation] = [:]
    private var observers: [NSObjectProtocol] = []

    @MainActor
    func start() {
        guard observers.isEmpty else { return }
        observers.append(DistributedNotificationCenter.default().addObserver(
            forName: Self.reportNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handle(notification)
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bundleIdentifier = app.bundleIdentifier
            else { return }
            self?.remove(source: bundleIdentifier)
        })
        DistributedNotificationCenter.default().postNotificationName(Self.requestNotification, object: nil, userInfo: nil, deliverImmediately: true)
    }

    var reports: [Report] {
        lock.lock()
        defer { lock.unlock() }
        return reported.map { Report(source: $0.key, reservation: $0.value) }.sorted { $0.source < $1.source }
    }

    func report(_ reservation: ScreenReservation, from source: String) {
        lock.lock()
        if reservation.edge == .none || reservation.thickness <= 0 {
            reported.removeValue(forKey: source)
        } else {
            reported[source] = reservation
        }
        lock.unlock()
        DebugLogger.log("ScreenReservations", details: "\(source) reported \(reservation.edge.rawValue) \(reservation.thickness) on \(reservation.display.isEmpty ? "all displays" : reservation.display)")
        notifyChange()
    }

    func remove(source: String) {
        lock.lock()
        let removed = reported.removeValue(forKey: source) != nil
        lock.unlock()
        if removed {
            notifyChange()
        }
    }

    func usableFrame(for screen: NSScreen) -> CGRect {
        var reservations = reports.map(\.reservation)
        let manual = ScreenReservation(
            edge: Defaults[.customDockReservationEdge],
            thickness: Defaults[.customDockReservationThickness],
            display: ScreenReservation.allDisplays
        )
        reservations.append(manual)
        return ScreenReservation.usableFrame(
            visibleFrame: screen.visibleFrame,
            screenFrame: screen.frame,
            reservations: reservations.filter { $0.applies(to: screen) }
        )
    }

    private func handle(_ notification: Notification) {
        let info = notification.userInfo
        var edge = info?["edge"] as? String
        var thickness = (info?["thickness"] as? NSNumber)?.doubleValue ?? (info?["height"] as? NSNumber)?.doubleValue
        var display = info?["display"] as? String
        var source = info?["source"] as? String

        if info == nil, let payload = notification.object as? String {
            let parts = payload.split(separator: ",", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
            edge = parts.first
            thickness = parts.count > 1 ? Double(parts[1]) : nil
            source = parts.count > 2 && !parts[2].isEmpty ? parts[2] : nil
            display = parts.count > 3 && !parts[3].isEmpty ? parts[3] : nil
        }

        guard let reservation = ScreenReservation.parse(edge: edge, thickness: thickness, display: display) else {
            DebugLogger.log("ScreenReservations", details: "ignored malformed report: \(String(describing: info ?? [:])) \(String(describing: notification.object))")
            return
        }
        report(reservation, from: source ?? "unknown")
    }

    private func notifyChange() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.reportsDidChange, object: nil)
        }
    }
}

extension NSScreen {
    var snappingFrame: CGRect {
        ScreenReservations.shared.usableFrame(for: self)
    }
}
