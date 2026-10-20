import AppKit
import ApplicationServices

final class WindowSnapRegistry: @unchecked Sendable {
    struct Record {
        let window: WindowInfo
        var snappedFrame: CGRect
        let restoreFrame: CGRect
        let screenIdentifier: String?
    }

    static let shared = WindowSnapRegistry()
    private static let tolerance: CGFloat = 6
    private static let adjacencyTolerance: CGFloat = 8
    private static let minimumSize: CGFloat = 100

    private let queue = DispatchQueue(label: "com.ethanbills.DockDoor.windowGestures.snapRegistry", qos: .userInteractive)
    private let lock = NSLock()
    private var records: [CGWindowID: Record] = [:]
    private var pendingChanges: Set<CGWindowID> = []

    func record(for windowID: CGWindowID?) -> Record? {
        guard let windowID else { return nil }
        return lock.withLock { records[windowID] }
    }

    func snapped(_ window: WindowInfo, restoreFrame: CGRect) {
        guard let frame = window.currentWindowFrame() else { return }
        let record = Record(
            window: window,
            snappedFrame: frame,
            restoreFrame: restoreFrame,
            screenIdentifier: NSScreen.screen(containing: frame)?.uniqueIdentifier()
        )
        lock.withLock { records[window.id] = record }
    }

    @discardableResult
    func remove(_ windowID: CGWindowID) -> Record? {
        lock.withLock { records.removeValue(forKey: windowID) }
    }

    func liveRecord(for window: WindowInfo) -> Record? {
        guard let record = record(for: window.id) else { return nil }
        guard let frame = window.currentWindowFrame(), Self.matches(frame, record.snappedFrame) else {
            remove(window.id)
            return nil
        }
        return record
    }

    func windowFrameChanged(_ element: AXUIElement) {
        guard !lock.withLock({ records.isEmpty }), let windowID = try? element.cgWindowId() else { return }
        let shouldSchedule = lock.withLock {
            records[windowID] != nil && pendingChanges.insert(windowID).inserted
        }
        guard shouldSchedule else { return }
        queue.async { [self] in
            lock.withLock { _ = pendingChanges.remove(windowID) }
            handleFrameChange(of: windowID)
        }
    }

    private func handleFrameChange(of windowID: CGWindowID) {
        guard let record = record(for: windowID),
              let frame = record.window.currentWindowFrame(),
              !Self.matches(frame, record.snappedFrame)
        else { return }

        guard CGEventSource.buttonState(.combinedSessionState, button: .left) else {
            replace(record, with: nil)
            return
        }

        if Self.matches(frame.size, record.snappedFrame.size) {
            unsnap(record, draggedTo: frame)
        } else {
            resizeNeighbors(of: record, to: frame)
        }
    }

    private func unsnap(_ record: Record, draggedTo frame: CGRect) {
        replace(record, with: nil)
        let size = record.restoreFrame.size
        let cursorX = DockObserver.getMousePosition().x
        let fraction = frame.width > 0 ? (cursorX - frame.minX) / frame.width : 0.5
        var x = cursorX - fraction * size.width
        if let visible = NSScreen.screen(containing: frame)?.visibleFrame, size.width <= visible.width {
            x = min(max(x, visible.minX), visible.maxX - size.width)
        }
        record.window.applyFrame(CGRect(x: x.rounded(), y: frame.maxY - size.height, width: size.width, height: size.height))
    }

    private func resizeNeighbors(of record: Record, to frame: CGRect) {
        let neighbors = lock.withLock {
            records.values.filter { $0.window.id != record.window.id && $0.screenIdentifier == record.screenIdentifier }
        }
        for neighbor in neighbors {
            guard let target = Self.neighborFrame(neighbor.snappedFrame, following: record.snappedFrame, to: frame) else { continue }
            neighbor.window.applyFrame(target)
            var updated = neighbor
            updated.snappedFrame = neighbor.window.currentWindowFrame() ?? target
            replace(neighbor, with: updated)
        }
        var updated = record
        updated.snappedFrame = frame
        replace(record, with: updated)
    }

    private func replace(_ record: Record, with updated: Record?) {
        lock.withLock {
            guard records[record.window.id]?.snappedFrame == record.snappedFrame else { return }
            records[record.window.id] = updated
        }
    }

    private static func neighborFrame(_ neighbor: CGRect, following old: CGRect, to new: CGRect) -> CGRect? {
        var result = neighbor
        var moved = false
        for (oldLine, newLine) in [(old.minX, new.minX), (old.maxX, new.maxX)] where abs(oldLine - newLine) > 0.5 {
            if abs(result.minX - oldLine) <= adjacencyTolerance {
                result = CGRect(x: newLine, y: result.minY, width: max(result.maxX - newLine, minimumSize), height: result.height)
                moved = true
            } else if abs(result.maxX - oldLine) <= adjacencyTolerance {
                result.size.width = max(newLine - result.minX, minimumSize)
                moved = true
            }
        }
        for (oldLine, newLine) in [(old.minY, new.minY), (old.maxY, new.maxY)] where abs(oldLine - newLine) > 0.5 {
            if abs(result.minY - oldLine) <= adjacencyTolerance {
                result = CGRect(x: result.minX, y: newLine, width: result.width, height: max(result.maxY - newLine, minimumSize))
                moved = true
            } else if abs(result.maxY - oldLine) <= adjacencyTolerance {
                result.size.height = max(newLine - result.minY, minimumSize)
                moved = true
            }
        }
        return moved ? result : nil
    }

    private static func matches(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        abs(lhs.minX - rhs.minX) <= tolerance && abs(lhs.minY - rhs.minY) <= tolerance && matches(lhs.size, rhs.size)
    }

    private static func matches(_ lhs: CGSize, _ rhs: CGSize) -> Bool {
        abs(lhs.width - rhs.width) <= tolerance && abs(lhs.height - rhs.height) <= tolerance
    }
}
