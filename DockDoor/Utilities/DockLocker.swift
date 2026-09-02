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

    var length: CGFloat {
        end - start
    }

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

        // macOS refuses to place the Dock on a fully covered edge, so locking there would only strand it.
        guard !exposedIntervals(
            for: screenFrames[lockedScreenIndex],
            dockPosition: dockPosition,
            allFrames: screenFrames
        ).isEmpty else { return [] }

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

    static func relocationPath(
        lockedFrame: CGRect,
        dockPosition: DockPosition,
        allFrames: [CGRect]
    ) -> (start: CGPoint, end: CGPoint, push: CGVector)? {
        guard let interval = exposedIntervals(for: lockedFrame, dockPosition: dockPosition, allFrames: allFrames)
            .max(by: { $0.length < $1.length })
        else { return nil }

        let along = interval.start + min(60, interval.length / 2)
        let approach: CGFloat = 80

        switch dockPosition {
        case .bottom:
            return (CGPoint(x: along, y: lockedFrame.maxY - approach), CGPoint(x: along, y: lockedFrame.maxY - 1), CGVector(dx: 0, dy: 8))
        case .left:
            return (CGPoint(x: lockedFrame.minX + approach, y: along), CGPoint(x: lockedFrame.minX, y: along), CGVector(dx: -8, dy: 0))
        case .right:
            return (CGPoint(x: lockedFrame.maxX - approach, y: along), CGPoint(x: lockedFrame.maxX - 1, y: along), CGVector(dx: 8, dy: 0))
        default:
            return nil
        }
    }

    static func screenIndexHoldingDock(
        dockRect: CGRect,
        screenFrames: [CGRect],
        dockPosition: DockPosition
    ) -> Int? {
        var best: (index: Int, distance: CGFloat)?

        for (index, frame) in screenFrames.enumerated() {
            let distance: CGFloat
            switch dockPosition {
            case .bottom:
                guard dockRect.midX >= frame.minX, dockRect.midX <= frame.maxX else { continue }
                distance = min(abs(frame.maxY - dockRect.minY), abs(frame.maxY - dockRect.maxY))
            case .left:
                guard dockRect.midY >= frame.minY, dockRect.midY <= frame.maxY else { continue }
                distance = min(abs(frame.minX - dockRect.maxX), abs(frame.minX - dockRect.minX))
            case .right:
                guard dockRect.midY >= frame.minY, dockRect.midY <= frame.maxY else { continue }
                distance = min(abs(frame.maxX - dockRect.minX), abs(frame.maxX - dockRect.maxX))
            default:
                return nil
            }
            if best == nil || distance < best!.distance {
                best = (index, distance)
            }
        }

        return best?.index
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
    private var screenObserver: Any?
    private var settingsObserver: Defaults.Observation?
    private var relocationInProgress = false
    private var relocationWorkItem: DispatchWorkItem?

    init() {
        refreshTriggerZones()
        if !cachedTriggerZones.isEmpty {
            setupEventTap()
        }
        observeScreenChanges()
        settingsObserver = Defaults.observe(.lockedDockScreenIdentifier, options: []) { [weak self] _ in
            DispatchQueue.main.async { self?.reset() }
        }
        DebugLogger.log("DockLocker", details: "init: \(NSScreen.screens.count) screens, \(cachedTriggerZones.count) zones")
        scheduleRelocation(after: 2)
    }

    deinit {
        removeEventTap()
        settingsObserver?.invalidate()
        relocationWorkItem?.cancel()
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
        scheduleRelocation(after: 0.5)
    }

    // MARK: - Relocation

    private func lockedScreen() -> NSScreen? {
        NSScreen.findScreen(byIdentifier: Defaults[.lockedDockScreenIdentifier])
    }

    private func scheduleRelocation(after delay: TimeInterval) {
        relocationWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.relocateDockIfNeeded() }
        relocationWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    /// macOS only moves the Dock when the cursor pushes against a free stretch of a screen's Dock
    /// edge, so emulate that push on the locked screen when the Dock is found elsewhere.
    private func relocateDockIfNeeded() {
        guard !relocationInProgress, NSScreen.screens.count > 1 else { return }
        guard let target = lockedScreen() else {
            DebugLogger.log("DockLocker", details: "Locked screen not connected: \(Defaults[.lockedDockScreenIdentifier])")
            return
        }

        let dockPosition = DockUtils.getDockPosition()
        let frames = NSScreen.screens.map(\.cgFrame)
        guard let path = DockLockerGeometry.relocationPath(
            lockedFrame: target.cgFrame,
            dockPosition: dockPosition,
            allFrames: frames
        ) else {
            DebugLogger.log("DockLocker", details: "Locked screen's Dock edge is fully covered; cannot relocate Dock")
            return
        }

        guard let current = DockUtils.dockScreen() else {
            DebugLogger.log("DockLocker", details: "Could not determine which screen holds the Dock")
            return
        }
        guard current != target else { return }

        let modifier = DockLockModifier(rawValue: Defaults[.dockLockOverrideModifier]) ?? .option
        guard !CGEventSource.flagsState(.combinedSessionState).contains(modifier.cgEventFlag) else { return }
        guard !CGEventSource.buttonState(.combinedSessionState, button: .left) else {
            scheduleRelocation(after: 2)
            return
        }

        let origin = CGEvent(source: nil)?.location
        relocationInProgress = true
        DebugLogger.log("DockLocker", details: "Relocating Dock from \(current.localizedName) to \(target.localizedName)")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let steps = 8
            for step in 0 ... steps {
                let t = CGFloat(step) / CGFloat(steps)
                let point = CGPoint(
                    x: path.start.x + (path.end.x - path.start.x) * t,
                    y: path.start.y + (path.end.y - path.start.y) * t
                )
                Self.postMouseMoved(at: point, delta: CGVector(
                    dx: (path.end.x - path.start.x) / CGFloat(steps),
                    dy: (path.end.y - path.start.y) / CGFloat(steps)
                ))
                usleep(16000)
            }
            for _ in 0 ..< 6 {
                Self.postMouseMoved(at: path.end, delta: path.push)
                usleep(16000)
            }
            usleep(150_000)
            if let origin {
                CGWarpMouseCursorPosition(origin)
            }
            DispatchQueue.main.async {
                self?.relocationInProgress = false
                let landed = DockUtils.dockScreen()?.localizedName ?? "unknown"
                DebugLogger.log("DockLocker", details: "Dock now on \(landed)")
            }
        }
    }

    private static func postMouseMoved(at point: CGPoint, delta: CGVector) {
        guard let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left) else { return }
        event.setIntegerValueField(.mouseEventDeltaX, value: Int64(delta.dx))
        event.setIntegerValueField(.mouseEventDeltaY, value: Int64(delta.dy))
        event.post(tap: .cghidEventTap)
    }

    // MARK: - Event Tap

    private func setupEventTap() {
        let eventMask: CGEventMask =
            (1 << CGEventType.mouseMoved.rawValue)

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

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)!
        EventTapThread.shared.add(source)
        eventTap = tap
        runLoopSource = source
    }

    private func removeEventTap() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            if let runLoopSource {
                EventTapThread.shared.remove(runLoopSource)
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
        // mouseMoved events don't reliably carry held modifier flags, so also query live keyboard state.
        let activeFlags = event.flags.union(CGEventSource.flagsState(.combinedSessionState))
        if activeFlags.contains(modifier.cgEventFlag) {
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

        guard let locked = lockedScreen(), let lockedIndex = screens.firstIndex(of: locked) else {
            cachedTriggerZones = []
            return
        }

        let cgFrames = screens.map(\.cgFrame)

        let dockPosition = DockUtils.getDockPosition()
        cachedTriggerZones = DockLockerGeometry.calculateTriggerZones(
            screenFrames: cgFrames,
            lockedScreenIndex: lockedIndex,
            dockPosition: dockPosition
        )
    }

    // MARK: - Observers

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
        NSScreen.migrateScreenIdentifier(.lockedDockScreenIdentifier)
        guard !Defaults[.lockedDockScreenIdentifier].isEmpty, lockedScreen() != nil else {
            cachedTriggerZones = []
            removeEventTap()
            return
        }

        refreshTriggerZones()
        if cachedTriggerZones.isEmpty {
            removeEventTap()
        } else if eventTap == nil {
            setupEventTap()
        }
        scheduleRelocation(after: 1.5)
    }
}
