import AppKit
import Defaults

@MainActor
final class WindowSnapDragTracker {
    private enum Axis {
        case vertical
        case horizontal
    }

    private struct Follower {
        let record: WindowSnapRegistry.Record
        let movesMinEdge: Bool
    }

    private final class FollowerValidity: @unchecked Sendable {
        var isValid: [CGWindowID: Bool] = [:]
    }

    private enum Drag {
        case unsnap(record: WindowSnapRegistry.Record, start: CGPoint)
        case resize(record: WindowSnapRegistry.Record, axis: Axis, draggedMaxEdge: Bool, followers: [Follower], validity: FollowerValidity)
    }

    private static let edgeTolerance: CGFloat = 6
    private static let lineTolerance: CGFloat = 8
    private static let titleBarHeight: CGFloat = 40
    private static let unsnapThreshold: CGFloat = 4
    private nonisolated static let minimumSize: CGFloat = 100

    private let registry = WindowSnapRegistry.shared
    private let queue = DispatchQueue(label: "com.ethanbills.DockDoor.windowGestures.drag", qos: .userInteractive)
    private var monitors: [Any] = []
    private var drag: Drag?
    private var resizeInFlight = false

    func start() {
        guard monitors.isEmpty else { return }
        let handlers: [(NSEvent.EventTypeMask, () -> Void)] = [
            (.leftMouseDown, { [weak self] in self?.mouseDown() }),
            (.leftMouseDragged, { [weak self] in self?.mouseDragged() }),
            (.leftMouseUp, { [weak self] in self?.mouseUp() }),
        ]
        monitors = handlers.compactMap { mask, handler in
            NSEvent.addGlobalMonitorForEvents(matching: mask) { _ in
                MainActor.assumeIsolated {
                    handler()
                }
            }
        }
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        drag = nil
    }

    private func mouseDown() {
        drag = nil
        let dragToUnsnap = Defaults[.windowGestureDragToUnsnap]
        let resizeAdjacent = Defaults[.windowGestureResizeAdjacent]
        guard dragToUnsnap || resizeAdjacent else { return }

        let point = NSEvent.mouseLocation
        let records = registry.allRecords()
        let candidates = records.filter {
            $0.snappedFrame.insetBy(dx: -Self.edgeTolerance, dy: -Self.edgeTolerance).contains(point)
        }
        guard !candidates.isEmpty, let window = topWindow(at: point),
              let record = candidates.first(where: { $0.windowID == window.id }),
              WindowSnapRegistry.matches(window.frame, record.snappedFrame)
        else { return }

        let frame = record.snappedFrame
        if resizeAdjacent, let edge = Self.edge(of: frame, near: point) {
            let followers = followers(of: record, among: records, axis: edge.axis, line: edge.line, draggedMaxEdge: edge.isMax)
            if !followers.isEmpty {
                drag = .resize(record: record, axis: edge.axis, draggedMaxEdge: edge.isMax, followers: followers, validity: FollowerValidity())
                return
            }
        }

        if dragToUnsnap, point.y >= frame.maxY - Self.titleBarHeight, point.y <= frame.maxY {
            drag = .unsnap(record: record, start: point)
        }
    }

    private func mouseDragged() {
        guard let drag else { return }
        let point = NSEvent.mouseLocation
        switch drag {
        case let .unsnap(record, start):
            guard hypot(point.x - start.x, point.y - start.y) >= Self.unsnapThreshold else { return }
            self.drag = nil
            registry.remove(record.windowID)
            let snapped = record.snappedFrame
            let size = record.restoreFrame.size
            let fraction = snapped.width > 0 ? (start.x - snapped.minX) / snapped.width : 0.5
            let topOffset = snapped.maxY - start.y
            var x = point.x - fraction * size.width
            if let visible = NSScreen.screens.first(where: { $0.frame.contains(point) })?.visibleFrame, size.width <= visible.width {
                x = min(max(x, visible.minX), visible.maxX - size.width)
            }
            let frame = CGRect(
                x: x.rounded(),
                y: (point.y + topOffset - size.height).rounded(),
                width: size.width,
                height: size.height
            )
            queue.async {
                record.target.setFrame(frame)
            }
        case .resize:
            updateFollowers(finishing: false)
        }
    }

    private func mouseUp() {
        guard case .resize = drag else {
            drag = nil
            return
        }
        updateFollowers(finishing: true)
        drag = nil
    }

    private func updateFollowers(finishing: Bool) {
        guard case let .resize(record, axis, draggedMaxEdge, followers, validity) = drag else { return }
        guard finishing || !resizeInFlight else { return }
        resizeInFlight = true
        let registry = registry
        let spacing = Defaults[.windowGestureGridSpacing]

        queue.async { [weak self] in
            defer {
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        self?.resizeInFlight = false
                    }
                }
            }
            guard let dragged = record.target.frame else { return }
            let line: CGFloat = switch (axis, draggedMaxEdge) {
            case (.vertical, true): dragged.maxX
            case (.vertical, false): dragged.minX
            case (.horizontal, true): dragged.maxY
            case (.horizontal, false): dragged.minY
            }

            for follower in followers {
                let id = follower.record.windowID
                if validity.isValid[id] == nil {
                    let live = follower.record.target.frame
                    validity.isValid[id] = live.map { WindowSnapRegistry.matches($0, follower.record.snappedFrame) } ?? false
                }
                guard validity.isValid[id] == true else { continue }

                let frame = Self.followerFrame(
                    follower.record.snappedFrame,
                    axis: axis,
                    movesMinEdge: follower.movesMinEdge,
                    edge: follower.movesMinEdge == !draggedMaxEdge ? line : (draggedMaxEdge ? line + spacing : line - spacing)
                )
                follower.record.target.setFrame(frame)
                if finishing {
                    var updated = follower.record
                    updated.snappedFrame = follower.record.target.frame ?? frame
                    registry.set(updated)
                }
            }

            if finishing {
                var updated = record
                updated.snappedFrame = dragged
                registry.set(updated)
            }
        }
    }

    private nonisolated static func followerFrame(_ frame: CGRect, axis: Axis, movesMinEdge: Bool, edge: CGFloat) -> CGRect {
        switch (axis, movesMinEdge) {
        case (.vertical, true):
            CGRect(x: edge, y: frame.minY, width: max(frame.maxX - edge, minimumSize), height: frame.height)
        case (.vertical, false):
            CGRect(x: frame.minX, y: frame.minY, width: max(edge - frame.minX, minimumSize), height: frame.height)
        case (.horizontal, true):
            CGRect(x: frame.minX, y: edge, width: frame.width, height: max(frame.maxY - edge, minimumSize))
        case (.horizontal, false):
            CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: max(edge - frame.minY, minimumSize))
        }
    }

    private func followers(of record: WindowSnapRegistry.Record, among records: [WindowSnapRegistry.Record], axis: Axis, line: CGFloat, draggedMaxEdge: Bool) -> [Follower] {
        let spacing = Defaults[.windowGestureGridSpacing]
        let across = draggedMaxEdge ? line + spacing : line - spacing
        return records.compactMap { other in
            guard other.windowID != record.windowID, other.screenIdentifier == record.screenIdentifier else { return nil }
            let frame = other.snappedFrame
            let (minEdge, maxEdge) = axis == .vertical ? (frame.minX, frame.maxX) : (frame.minY, frame.maxY)
            if draggedMaxEdge {
                if abs(minEdge - across) <= Self.lineTolerance { return Follower(record: other, movesMinEdge: true) }
                if abs(maxEdge - line) <= Self.lineTolerance { return Follower(record: other, movesMinEdge: false) }
            } else {
                if abs(maxEdge - across) <= Self.lineTolerance { return Follower(record: other, movesMinEdge: false) }
                if abs(minEdge - line) <= Self.lineTolerance { return Follower(record: other, movesMinEdge: true) }
            }
            return nil
        }
    }

    private static func edge(of frame: CGRect, near point: CGPoint) -> (axis: Axis, line: CGFloat, isMax: Bool)? {
        let withinY = point.y >= frame.minY - edgeTolerance && point.y <= frame.maxY + edgeTolerance
        let withinX = point.x >= frame.minX - edgeTolerance && point.x <= frame.maxX + edgeTolerance
        if withinY, abs(point.x - frame.maxX) <= edgeTolerance { return (.vertical, frame.maxX, true) }
        if withinY, abs(point.x - frame.minX) <= edgeTolerance { return (.vertical, frame.minX, false) }
        if withinX, abs(point.y - frame.minY) <= edgeTolerance { return (.horizontal, frame.minY, false) }
        if withinX, abs(point.y - frame.maxY) <= edgeTolerance { return (.horizontal, frame.maxY, true) }
        return nil
    }

    private func topWindow(at point: CGPoint) -> (id: CGWindowID, frame: CGRect)? {
        guard let primaryMaxY = NSScreen.screens.first?.frame.maxY else { return nil }
        let quartzPoint = CGPoint(x: point.x, y: primaryMaxY - point.y)
        guard let window = WindowGestureZoneResolver.topWindow(
            at: quartzPoint,
            in: WindowGestureZoneResolver.onScreenWindows(),
            tolerance: Self.edgeTolerance
        ),
            (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value != ProcessInfo.processInfo.processIdentifier,
            (window[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
            let id = (window[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
            let bounds = WindowGestureZoneResolver.bounds(of: window)
        else { return nil }
        let frame = CGRect(x: bounds.minX, y: primaryMaxY - bounds.maxY, width: bounds.width, height: bounds.height)
        return (CGWindowID(id), frame)
    }
}
