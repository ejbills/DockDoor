import AppKit
import Carbon.HIToolbox.Events
import Defaults

final class WindowGestureController {
    private struct Session {
        let zone: WindowGestureZone
        var recognizer: WindowGestureRecognizer
        var cursor: CGPoint
        let disabled: Set<WindowGesture>
        let windowFrame: CGRect?
        var naturalScrolling: Bool?
        var ownsPinch = false
        var lastProgress = GestureProgress()
        var switcherArmed = false
        var switcherOpened = false
    }

    private struct RecentZone {
        let zone: WindowGestureZone?
        let point: CGPoint
        let time: TimeInterval
    }

    private static let gestureEventType: UInt32 = 29
    private static let smartMagnifyEventType: UInt32 = 32
    private static let gestureSubtypeField = CGEventField(rawValue: 110)!
    private static let magnificationField = CGEventField(rawValue: 113)!
    private static let gesturePhaseField = CGEventField(rawValue: 132)!
    private static let magnifySubtype: Int64 = 8
    private static let zoomToggleSubtype: Int64 = 22
    private static let tickInterval: CFTimeInterval = 0.03
    private static let zoneReuseWindow: TimeInterval = 0.6
    private static let doubleTapDebounce: TimeInterval = 0.25

    private static let scrollBegan = Int64(CGScrollPhase.began.rawValue)
    private static let scrollChanged = Int64(CGScrollPhase.changed.rawValue)
    private static let scrollEnded = Int64(CGScrollPhase.ended.rawValue)
    private static let scrollCancelled = Int64(CGScrollPhase.cancelled.rawValue)
    private static let scrollMayBegin = Int64(CGScrollPhase.mayBegin.rawValue)
    private static let gestureBegan = Int64(CGGesturePhase.began.rawValue)
    private static let gestureEnded = Int64(CGGesturePhase.ended.rawValue)
    private static let gestureCancelled = Int64(CGGesturePhase.cancelled.rawValue)
    private static let momentumEnd = Int64(CGMomentumScrollPhase.end.rawValue)

    private let previewCoordinator: SharedPreviewWindowCoordinator
    private let switcher: @MainActor (TrackpadSwipeEvent) -> Void
    private lazy var thread = EventTapThread(name: "com.ethanbills.DockDoor.windowGestures")
    private let executor = WindowGestureExecutor()
    private let hud: WindowGestureHUD
    private let dragTracker: WindowSnapDragTracker
    private var enabledObservation: Defaults.Observation?
    private var escapeMonitor: Any?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var retainedSelf: Unmanaged<WindowGestureController>?
    private var tickTimer: CFRunLoopTimer?
    private var session: Session?
    private var consumingMomentum = false
    private var swallowingScroll = false
    private var swallowingPinch = false
    private var lastDoubleTap: TimeInterval = 0
    private var recentZone: RecentZone?

    @MainActor
    init(previewCoordinator: SharedPreviewWindowCoordinator, switcher: @escaping @MainActor (TrackpadSwipeEvent) -> Void) {
        self.previewCoordinator = previewCoordinator
        self.switcher = switcher
        hud = WindowGestureHUD()
        dragTracker = WindowSnapDragTracker()
        enabledObservation = Defaults.observe(.enableWindowGestures) { [weak self] change in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self else { return }
                    if change.newValue {
                        self.start()
                        self.dragTracker.start()
                        self.startEscapeMonitor()
                    } else {
                        self.stop()
                        self.dragTracker.stop()
                        self.stopEscapeMonitor()
                    }
                }
            }
        }
    }

    deinit {
        enabledObservation?.invalidate()
    }

    func start() {
        thread.perform { [weak self] in
            self?.installTap()
        }
    }

    func stop() {
        thread.perform { [weak self] in
            self?.removeTap()
        }
    }

    func reset() {
        thread.perform { [weak self] in
            guard let self else { return }
            if let eventTap, DockObserver.canPostEvents, CFMachPortIsValid(eventTap), CGEvent.tapIsEnabled(tap: eventTap) {
                return
            }
            removeTap()
            installTap()
        }
    }

    // MARK: - Event Tap

    private static let callback: CGEventTapCallBack = { _, type, event, refcon in
        guard let refcon else { return Unmanaged.passUnretained(event) }
        let controller = Unmanaged<WindowGestureController>.fromOpaque(refcon).takeUnretainedValue()
        return controller.handle(type: type, event: event)
    }

    private func installTap() {
        guard eventTap == nil, Defaults[.enableWindowGestures], DockObserver.canPostEvents else { return }
        let mask: CGEventMask = (1 << CGEventType.scrollWheel.rawValue)
            | (1 << CGEventMask(Self.gestureEventType))
            | (1 << CGEventMask(Self.smartMagnifyEventType))

        let retained = Unmanaged.passRetained(self)
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: Self.callback,
            userInfo: retained.toOpaque()
        ) else {
            retained.release()
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                self?.start()
            }
            return
        }

        retainedSelf = retained
        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func removeTap() {
        abandonSession(swallowRemainder: false)
        swallowingScroll = false
        swallowingPinch = false
        consumingMomentum = false
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        CFMachPortInvalidate(tap)
        eventTap = nil
        runLoopSource = nil
        let retained = retainedSelf
        retainedSelf = nil
        DispatchQueue.main.async {
            retained?.release()
        }
    }

    @MainActor
    private func startEscapeMonitor() {
        guard escapeMonitor == nil else { return }
        escapeMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == UInt16(kVK_Escape) else { return }
            self?.thread.perform { [weak self] in
                self?.escapePressed()
            }
        }
    }

    @MainActor
    private func stopEscapeMonitor() {
        if let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
        }
        escapeMonitor = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            if type == .tapDisabledByTimeout {
                abandonSession(swallowRemainder: true)
            }
            return Unmanaged.passUnretained(event)
        }

        switch type.rawValue {
        case CGEventType.scrollWheel.rawValue:
            return handleScroll(event)
        case Self.gestureEventType:
            return handleGesture(event)
        case Self.smartMagnifyEventType:
            return handleDoubleTap(event)
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    // MARK: - Scroll

    private func handleScroll(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)
        guard event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0 else { return pass }

        let momentum = event.getIntegerValueField(.scrollWheelEventMomentumPhase)
        if momentum != 0 {
            guard consumingMomentum else { return pass }
            if momentum == Self.momentumEnd {
                consumingMomentum = false
            }
            return nil
        }

        let now = ProcessInfo.processInfo.systemUptime
        let phase = event.getIntegerValueField(.scrollWheelEventScrollPhase)

        if phase == Self.scrollMayBegin {
            consumingMomentum = false
            swallowingScroll = false
            if let current = session {
                if current.recognizer.isPinching {
                    return nil
                }
                process(session?.recognizer.handle(.touchDown, at: now) ?? [])
                abandonSession(swallowRemainder: false)
            }
            guard startSession(at: event.location, now: now) else { return pass }
            process(session?.recognizer.handle(.touchDown, at: now) ?? [])
            return session?.zone.consumesScroll == false ? pass : nil
        }

        if swallowingScroll, session == nil {
            if phase == Self.scrollEnded || phase == Self.scrollCancelled {
                swallowingScroll = false
                consumingMomentum = phase == Self.scrollEnded
            }
            return nil
        }

        switch phase {
        case Self.scrollBegan, Self.scrollChanged:
            if session == nil, phase == Self.scrollBegan {
                consumingMomentum = false
                guard startSession(at: event.location, now: now) else { return pass }
            }
            guard let current = session else { return pass }
            guard current.zone.consumesScroll else {
                abandonSession(swallowRemainder: false)
                return pass
            }
            let natural = current.naturalScrolling ?? (NSEvent(cgEvent: event)?.isDirectionInvertedFromDevice ?? true)
            session?.naturalScrolling = natural
            session?.cursor = event.location
            let deltaX = CGFloat(event.getDoubleValueField(.scrollWheelEventPointDeltaAxis2))
            let deltaY = CGFloat(event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1))
            let input: WindowGestureRecognizer.Input = natural ? .scroll(dx: deltaX, dy: -deltaY) : .scroll(dx: -deltaX, dy: deltaY)
            process(session?.recognizer.handle(input, at: now) ?? [])
            return nil

        case Self.scrollEnded, Self.scrollCancelled:
            guard let current = session else { return pass }
            let consumes = current.zone.consumesScroll
            process(session?.recognizer.handle(.scrollLift, at: now) ?? [])
            guard consumes else { return pass }
            consumingMomentum = phase == Self.scrollEnded
            return nil

        default:
            return pass
        }
    }

    // MARK: - Pinch & Double Tap

    private func handleGesture(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)
        let subtype = event.getIntegerValueField(Self.gestureSubtypeField)
        if subtype == Self.zoomToggleSubtype {
            return handleDoubleTap(event)
        }
        guard subtype == Self.magnifySubtype else { return pass }

        let now = ProcessInfo.processInfo.systemUptime
        let phase = event.getIntegerValueField(Self.gesturePhaseField)
        let isEnd = phase & (Self.gestureEnded | Self.gestureCancelled) != 0

        if phase & Self.gestureBegan != 0 {
            swallowingPinch = false
            if session == nil {
                guard startSession(at: event.location, now: now) else { return pass }
            }
            session?.ownsPinch = true
            session?.cursor = event.location
            process(session?.recognizer.handle(.pinchBegan, at: now) ?? [])
            return nil
        }

        guard session?.ownsPinch == true else {
            guard swallowingPinch else { return pass }
            if isEnd {
                swallowingPinch = false
            }
            return nil
        }

        if isEnd {
            let input: WindowGestureRecognizer.Input = phase & Self.gestureCancelled != 0 ? .pinchCancelled : .pinchEnded
            process(session?.recognizer.handle(input, at: now) ?? [])
            if session?.recognizer.isIdle == true {
                endSession()
            }
            return nil
        }

        let magnification = CGFloat(event.getDoubleValueField(Self.magnificationField))
        process(session?.recognizer.handle(.pinch(magnification), at: now) ?? [])
        return nil
    }

    private func handleDoubleTap(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastDoubleTap > Self.doubleTapDebounce, !NSScreen.screens.isEmpty else { return pass }
        let point = event.location
        guard let zone = session?.zone ?? zone(at: point, now: now) else { return pass }

        let context = WindowGestureContext(zone: zone.kind, doubleTap: true, disabled: Defaults[.windowGesturesDisabled])
        guard let resolution = WindowGestureResolver.resolve(context) else { return pass }
        lastDoubleTap = now
        DebugLogger.log("WindowGestures", details: "double tap \(resolution.command)")

        execute(resolution.command, zone: zone, cursor: point)
        let content = hudContent(for: resolution.command, app: zone.app)
        DispatchQueue.main.async { [hud] in
            MainActor.assumeIsolated {
                WindowGestureHUD.haptic(.levelChange)
                hud.finish(content, cursor: point)
            }
        }
        return nil
    }

    private func escapePressed() {
        guard let current = session, !current.recognizer.isIdle, !current.recognizer.isSpent else { return }
        process(session?.recognizer.handle(.escape, at: ProcessInfo.processInfo.systemUptime) ?? [])
    }

    // MARK: - Sessions

    private func startSession(at point: CGPoint, now: TimeInterval) -> Bool {
        guard !NSScreen.screens.isEmpty else { return false }
        guard !previewCoordinator.containsQuartzPoint(point) else {
            DebugLogger.log("WindowGestures", details: "point \(point) is over a DockDoor preview")
            return false
        }
        guard let zone = zone(at: point, now: now) else {
            DebugLogger.log("WindowGestures", details: "no gesture zone at \(point)")
            return false
        }

        let disabled = Defaults[.windowGesturesDisabled]
        guard Self.hasEnabledGestures(for: zone, disabled: disabled) else { return false }
        DebugLogger.log("WindowGestures", details: "session \(zone.kind) app=\(zone.app?.localizedName ?? "-") at \(point)")

        let configuration = WindowGestureRecognizer.Configuration.make(
            sensitivity: Defaults[.windowGestureSensitivity],
            holds: zone.kind == .menuBar
        )
        session = Session(
            zone: zone,
            recognizer: WindowGestureRecognizer(configuration: configuration),
            cursor: point,
            disabled: disabled,
            windowFrame: zone.window?.frame
        )
        startTickTimer()
        return true
    }

    private func zone(at point: CGPoint, now: TimeInterval) -> WindowGestureZone? {
        if let recentZone, now - recentZone.time < Self.zoneReuseWindow,
           hypot(recentZone.point.x - point.x, recentZone.point.y - point.y) < 4
        {
            return recentZone.zone
        }
        let zone = DebugLogger.measureSlow("WindowGestures zone", thresholdMs: 30, details: "\(point)") {
            WindowGestureZoneResolver.resolve(at: point)
        }
        recentZone = RecentZone(zone: zone, point: point, time: now)
        return zone
    }

    private func endSession() {
        stopTickTimer()
        session = nil
    }

    private func abandonSession(swallowRemainder: Bool) {
        guard let current = session else { return }
        endSession()
        if swallowRemainder {
            swallowingScroll = current.zone.consumesScroll && current.recognizer.hasMoved && !current.recognizer.isPinching
            swallowingPinch = current.ownsPinch
        }
        if current.switcherOpened {
            notifySwitcher(.cancel)
        }
        DispatchQueue.main.async { [hud] in
            MainActor.assumeIsolated {
                hud.hide()
            }
        }
    }

    private static func hasEnabledGestures(for zone: WindowGestureZone, disabled: Set<WindowGesture>) -> Bool {
        let area: WindowGestureArea = switch zone {
        case .window, .tab: .titleBar
        case .app: .dock
        case .menuBar: .menuBar
        }
        return area.gestures.contains { !disabled.contains($0) }
    }

    // MARK: - Recognition

    private func process(_ outputs: [WindowGestureRecognizer.Output]) {
        for output in outputs {
            switch output {
            case let .progressed(progress):
                progressed(progress)
            case .rearmed:
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        WindowGestureHUD.haptic(.alignment)
                    }
                }
            case .cancelled:
                cancelled()
            case let .finished(progress):
                finished(progress)
            }
        }
    }

    private func progressed(_ progress: GestureProgress) {
        guard let current = session else { return }

        if case .menuBar = current.zone, current.switcherArmed || progress.held, switcherAvailable(disabled: current.disabled) {
            advanceSwitcher(progress)
            return
        }

        let changed = progress != current.lastProgress
        session?.lastProgress = progress
        var resolution = WindowGestureResolver.resolve(context(for: current, progress: progress))
        if resolution?.command == .openSwitcher {
            resolution = nil
        }

        if let resolution, resolution.command.isImmediate {
            DebugLogger.log("WindowGestures", details: "immediate \(resolution.command)")
            execute(resolution.command, zone: current.zone, cursor: current.cursor)
            session?.recognizer.clearSteps()
            session?.lastProgress = GestureProgress()
            let content = hudContent(for: resolution.command, app: current.zone.app)
            DispatchQueue.main.async { [hud] in
                MainActor.assumeIsolated {
                    WindowGestureHUD.haptic(.levelChange)
                    hud.flash(content, cursor: current.cursor)
                }
            }
            return
        }

        let content: WindowGestureHUD.Content? = if let resolution {
            hudContent(for: resolution.command, app: current.zone.app)
        } else if !progress.steps.isEmpty {
            WindowGestureHUD.Content(title: String(localized: "No Action", comment: "Window gesture tooltip"), symbolName: "nosign", isDimmed: true)
        } else {
            nil
        }
        let preview = resolution.flatMap { previewFrame(for: $0.command) }
        DispatchQueue.main.async { [hud] in
            MainActor.assumeIsolated {
                if changed {
                    WindowGestureHUD.haptic(.levelChange)
                }
                if let content {
                    hud.show(content, cursor: current.cursor, preview: preview)
                } else {
                    hud.hide()
                }
            }
        }
    }

    private func cancelled() {
        guard let current = session else { return }
        if current.switcherOpened {
            notifySwitcher(.cancel)
            session?.switcherOpened = false
        }
        let content = WindowGestureHUD.Content(title: String(localized: "Cancelled", comment: "Window gesture tooltip"), symbolName: "xmark.circle", isDimmed: true)
        DispatchQueue.main.async { [hud] in
            MainActor.assumeIsolated {
                WindowGestureHUD.haptic(.generic)
                hud.finish(content, cursor: current.cursor)
            }
        }
    }

    private func finished(_ progress: GestureProgress?) {
        guard let current = session else { return }
        endSession()

        if current.switcherOpened {
            notifySwitcher(.release)
            DispatchQueue.main.async { [hud] in
                MainActor.assumeIsolated {
                    hud.hide()
                }
            }
            return
        }

        var content: WindowGestureHUD.Content?
        if let progress,
           let resolution = WindowGestureResolver.resolve(context(for: current, progress: progress)),
           !resolution.command.isImmediate
        {
            DebugLogger.log("WindowGestures", details: "finish \(resolution.command)")
            execute(resolution.command, zone: current.zone, cursor: current.cursor)
            content = hudContent(for: resolution.command, app: current.zone.app)
        } else if let progress {
            DebugLogger.log("WindowGestures", details: "finish without action steps=\(progress.steps) held=\(progress.held)")
        }
        DispatchQueue.main.async { [hud] in
            MainActor.assumeIsolated {
                hud.finish(content, cursor: current.cursor)
            }
        }
    }

    private func context(for session: Session, progress: GestureProgress) -> WindowGestureContext {
        WindowGestureContext(zone: session.zone.kind, progress: progress, disabled: session.disabled)
    }

    // MARK: - Window Switcher

    private func switcherAvailable(disabled: Set<WindowGesture>) -> Bool {
        !disabled.contains(.menubarAppSwitcher) && Defaults[.enableWindowSwitcher]
    }

    private func advanceSwitcher(_ progress: GestureProgress) {
        guard let current = session else { return }
        if !current.switcherArmed {
            session?.switcherArmed = true
            session?.recognizer.repeatsWithoutPause = true
            let content = hudContent(for: .openSwitcher, app: nil)
            DispatchQueue.main.async { [hud] in
                MainActor.assumeIsolated {
                    WindowGestureHUD.haptic(.levelChange)
                    hud.show(content, cursor: current.cursor, preview: nil)
                }
            }
        }

        guard !progress.steps.isEmpty else { return }
        var opened = current.switcherOpened
        for step in progress.steps {
            if !opened {
                notifySwitcher(.open)
                opened = true
            } else {
                notifySwitcher(step == .right || step == .down ? .cycleForward : .cycleBackward)
            }
        }
        session?.switcherOpened = opened
        session?.recognizer.clearSteps()
        session?.recognizer.repeatsWithoutPause = true
        DispatchQueue.main.async { [hud] in
            MainActor.assumeIsolated {
                WindowGestureHUD.haptic(.alignment)
                hud.hide()
            }
        }
    }

    private func notifySwitcher(_ event: TrackpadSwipeEvent) {
        let switcher = switcher
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                switcher(event)
            }
        }
    }

    // MARK: - Execution

    private func execute(_ command: WindowGestureCommand, zone: WindowGestureZone, cursor: CGPoint) {
        recentZone = nil
        executor.perform(command, zone: zone, cursor: cursor)
        guard case .app = zone else { return }
        let previewCoordinator = previewCoordinator
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                previewCoordinator.hideWindow()
            }
        }
    }

    private func hudContent(for command: WindowGestureCommand, app: NSRunningApplication?) -> WindowGestureHUD.Content {
        var content = WindowGestureHUD.Content(title: command.title(appName: app?.localizedName), symbolName: command.symbolName)
        switch command {
        case let .snap(region):
            content.region = region
        case .quitApp, .restoreLastMinimized, .minimizeFrontWindow:
            content.appIcon = app?.icon
        default:
            break
        }
        return content
    }

    private func previewFrame(for command: WindowGestureCommand) -> CGRect? {
        guard let current = session else { return nil }
        let screen = current.windowFrame.flatMap(WindowGestureScreens.screen(containing:)) ?? NSScreen.screenFromQuartzPoint(current.cursor)
        switch command {
        case let .snap(region):
            return WindowGestureScreens.frame(for: region, on: screen)
        case .center:
            guard let windowFrame = current.windowFrame else { return nil }
            let restoreSize = WindowSnapRegistry.shared.record(for: current.zone.window?.windowID)?.restoreFrame.size
            return WindowGestureScreens.centered(restoreSize ?? windowFrame.size, in: WindowGestureScreens.usableFrame(for: screen))
        default:
            return nil
        }
    }

    // MARK: - Ticks

    private func startTickTimer() {
        guard tickTimer == nil else { return }
        let timer = CFRunLoopTimerCreateWithHandler(
            kCFAllocatorDefault,
            CFAbsoluteTimeGetCurrent() + Self.tickInterval,
            Self.tickInterval,
            0,
            0
        ) { [weak self] _ in
            self?.tick()
        }
        tickTimer = timer
        CFRunLoopAddTimer(CFRunLoopGetCurrent(), timer, .commonModes)
    }

    private func stopTickTimer() {
        guard let tickTimer else { return }
        CFRunLoopTimerInvalidate(tickTimer)
        self.tickTimer = nil
    }

    private func tick() {
        guard session != nil else {
            stopTickTimer()
            return
        }
        process(session?.recognizer.handle(.tick, at: ProcessInfo.processInfo.systemUptime) ?? [])
    }
}
