import ApplicationServices
import Cocoa
import Defaults

// MARK: - Geometry Types

struct TriggerZone: Equatable {
    let rect: CGRect
    let nudgeVector: CGVector
}

struct EdgeInterval: Equatable {
    let start: CGFloat
    let end: CGFloat

    var length: CGFloat { end - start }

    static func merge(_ intervals: [EdgeInterval]) -> [EdgeInterval] {
        guard !intervals.isEmpty else { return [] }
        let sorted = intervals.sorted { $0.start < $1.start }
        var merged: [EdgeInterval] = [sorted[0]]
        for interval in sorted.dropFirst() {
            if interval.start <= merged.last!.end + 0.5 {
                merged[merged.count - 1] = EdgeInterval(
                    start: merged.last!.start,
                    end: max(merged.last!.end, interval.end)
                )
            } else {
                merged.append(interval)
            }
        }
        return merged
    }

    static func subtract(from full: EdgeInterval, removing covered: [EdgeInterval]) -> [EdgeInterval] {
        let merged = merge(covered)
        var result: [EdgeInterval] = []
        var cursor = full.start

        for interval in merged {
            if interval.start > cursor {
                let gap = EdgeInterval(start: cursor, end: min(interval.start, full.end))
                if gap.length > 0.5 { result.append(gap) }
            }
            cursor = max(cursor, interval.end)
        }

        if cursor < full.end {
            let remaining = EdgeInterval(start: cursor, end: full.end)
            if remaining.length > 0.5 { result.append(remaining) }
        }

        return result
    }
}

// MARK: - Trigger Zone Calculation

enum DockLockerGeometry {
    private static let triggerDepth: CGFloat = 7
    private static let adjacencyTolerance: CGFloat = 2

    /// Calculate trigger zones for all non-locked screens.
    /// All frames must be in CG global coordinates (origin top-left, Y increases downward).
    static func calculateTriggerZones(
        screenFrames: [CGRect],
        lockedScreenIndex: Int,
        dockPosition: DockPosition
    ) -> [TriggerZone] {
        guard screenFrames.count > 1,
              lockedScreenIndex >= 0,
              lockedScreenIndex < screenFrames.count
        else { return [] }

        guard dockPosition == .bottom || dockPosition == .left || dockPosition == .right else {
            return []
        }

        var zones: [TriggerZone] = []

        for (index, frame) in screenFrames.enumerated() {
            guard index != lockedScreenIndex else { continue }

            let exposedIntervals = Self.exposedIntervals(
                for: frame,
                dockPosition: dockPosition,
                allFrames: screenFrames
            )

            for interval in exposedIntervals {
                if let zone = Self.triggerZone(
                    for: frame,
                    interval: interval,
                    dockPosition: dockPosition
                ) {
                    zones.append(zone)
                }
            }
        }

        return zones
    }

    static func exposedIntervals(
        for frame: CGRect,
        dockPosition: DockPosition,
        allFrames: [CGRect]
    ) -> [EdgeInterval] {
        let (edgePosition, fullInterval) = edgeInfo(for: frame, dockPosition: dockPosition)

        var coveredIntervals: [EdgeInterval] = []

        for other in allFrames {
            guard other != frame else { continue }

            guard isAdjacent(other, to: frame, at: dockPosition, edgePosition: edgePosition) else { continue }

            let otherInterval = perpendicularInterval(of: other, dockPosition: dockPosition)
            let overlapStart = max(fullInterval.start, otherInterval.start)
            let overlapEnd = min(fullInterval.end, otherInterval.end)

            if overlapEnd - overlapStart > 0.5 {
                coveredIntervals.append(EdgeInterval(start: overlapStart, end: overlapEnd))
            }
        }

        return EdgeInterval.subtract(from: fullInterval, removing: coveredIntervals)
    }

    // MARK: - Private Helpers

    private static func edgeInfo(
        for frame: CGRect,
        dockPosition: DockPosition
    ) -> (edgePosition: CGFloat, interval: EdgeInterval) {
        switch dockPosition {
        case .bottom:
            (frame.maxY, EdgeInterval(start: frame.minX, end: frame.maxX))
        case .left:
            (frame.minX, EdgeInterval(start: frame.minY, end: frame.maxY))
        case .right:
            (frame.maxX, EdgeInterval(start: frame.minY, end: frame.maxY))
        default:
            (frame.maxY, EdgeInterval(start: frame.minX, end: frame.maxX))
        }
    }

    private static func isAdjacent(
        _ other: CGRect,
        to frame: CGRect,
        at dockPosition: DockPosition,
        edgePosition: CGFloat
    ) -> Bool {
        switch dockPosition {
        case .bottom:
            abs(other.minY - edgePosition) <= adjacencyTolerance
        case .left:
            abs(other.maxX - edgePosition) <= adjacencyTolerance
        case .right:
            abs(other.minX - edgePosition) <= adjacencyTolerance
        default:
            abs(other.minY - edgePosition) <= adjacencyTolerance
        }
    }

    private static func perpendicularInterval(
        of frame: CGRect,
        dockPosition: DockPosition
    ) -> EdgeInterval {
        switch dockPosition {
        case .bottom:
            EdgeInterval(start: frame.minX, end: frame.maxX)
        case .left, .right:
            EdgeInterval(start: frame.minY, end: frame.maxY)
        default:
            EdgeInterval(start: frame.minX, end: frame.maxX)
        }
    }

    private static func triggerZone(
        for frame: CGRect,
        interval: EdgeInterval,
        dockPosition: DockPosition
    ) -> TriggerZone? {
        let depth = triggerDepth
        let rect: CGRect
        let nudge: CGVector

        switch dockPosition {
        case .bottom:
            rect = CGRect(x: interval.start, y: frame.maxY - depth, width: interval.length, height: depth)
            nudge = CGVector(dx: 0, dy: -depth)
        case .left:
            rect = CGRect(x: frame.minX, y: interval.start, width: depth, height: interval.length)
            nudge = CGVector(dx: depth, dy: 0)
        case .right:
            rect = CGRect(x: frame.maxX - depth, y: interval.start, width: depth, height: interval.length)
            nudge = CGVector(dx: -depth, dy: 0)
        default:
            return nil
        }

        return TriggerZone(rect: rect, nudgeVector: nudge)
    }
}

// MARK: - DockLocker

final class DockLocker {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var cachedTriggerZones: [TriggerZone] = []
    private var settingsObserver: Defaults.Observation?
    private var screenObserver: Any?

    init() {
        refreshTriggerZones()
        if !cachedTriggerZones.isEmpty {
            setupEventTap()
        }
        observeSettings()
        observeScreenChanges()
    }

    deinit {
        removeEventTap()
        settingsObserver?.invalidate()
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }

    func reset() {
        removeEventTap()
        refreshTriggerZones()
        if !cachedTriggerZones.isEmpty {
            setupEventTap()
        }
    }

    // MARK: - Event Tap

    private func setupEventTap() {
        let eventMask: CGEventMask =
            (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.rightMouseDragged.rawValue) |
            (1 << CGEventType.otherMouseDragged.rawValue)

        // Session-level head-insert: intercepts cursor position before WindowServer
        // passes it to Dock. DockObserver uses HID-level tail-append for different
        // reasons (observing raw clicks/scrolls); here we need to modify events
        // before they reach the Dock trigger logic.
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let locker = Unmanaged<DockLocker>.fromOpaque(refcon).takeUnretainedValue()
                return locker.eventTapCallback(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("DockLocker: Failed to create event tap")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        eventTap = tap
        runLoopSource = source
    }

    private func removeEventTap() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            if let runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            }
            CFMachPortInvalidate(eventTap)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func eventTapCallback(proxy _: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // reEnableIfNeeded handles tap re-enable on tapDisabledByTimeout
        if let passthrough = reEnableIfNeeded(tap: eventTap, type: type, event: event) {
            return passthrough
        }

        let modifier = DockLockModifier(rawValue: Defaults[.dockLockOverrideModifier]) ?? .option
        if event.flags.contains(modifier.cgEventFlag) {
            return Unmanaged.passUnretained(event)
        }

        let cursorPos = event.location

        for zone in cachedTriggerZones {
            if zone.rect.contains(cursorPos) {
                // Modify in-place; CGWarpMouseCursorPosition would re-enter the callback
                let nudgedPos = CGPoint(
                    x: cursorPos.x + zone.nudgeVector.dx,
                    y: cursorPos.y + zone.nudgeVector.dy
                )
                event.location = nudgedPos
                return Unmanaged.passUnretained(event)
            }
        }

        return Unmanaged.passUnretained(event)
    }

    // MARK: - Trigger Zone Calculation

    private func refreshTriggerZones() {
        let screens = NSScreen.screens
        guard screens.count > 1 else {
            cachedTriggerZones = []
            return
        }

        let lockedIdentifier = Defaults[.lockedDockScreenIdentifier]
        guard !lockedIdentifier.isEmpty else {
            cachedTriggerZones = []
            return
        }

        let cgFrames = screens.map(\.cgFrame)
        let lockedIndex = screens.firstIndex { $0.uniqueIdentifier() == lockedIdentifier }

        guard let lockedIndex else {
            cachedTriggerZones = []
            return
        }

        let dockPosition = DockUtils.getDockPosition()
        cachedTriggerZones = DockLockerGeometry.calculateTriggerZones(
            screenFrames: cgFrames,
            lockedScreenIndex: lockedIndex,
            dockPosition: dockPosition
        )
    }

    // MARK: - Observers

    private func observeSettings() {
        settingsObserver = Defaults.observe(
            keys: .lockedDockScreenIdentifier, .dockLockOverrideModifier
        ) { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                self.refreshTriggerZones()
                if self.cachedTriggerZones.isEmpty {
                    self.removeEventTap()
                } else if self.eventTap == nil {
                    self.setupEventTap()
                }
            }
        }
    }

    private func observeScreenChanges() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenConfigChanged()
        }
    }

    private func handleScreenConfigChanged() {
        let lockedIdentifier = Defaults[.lockedDockScreenIdentifier]
        if !lockedIdentifier.isEmpty,
           NSScreen.findScreen(byIdentifier: lockedIdentifier) == nil
        {
            Defaults[.enableDockLocking] = false
            return
        }

        refreshTriggerZones()
        if cachedTriggerZones.isEmpty {
            removeEventTap()
        } else if eventTap == nil {
            setupEventTap()
        }
    }
}
