import ApplicationServices
import Cocoa

final class DockTitleBarClickMonitor {
    private static let eventTapCallback: CGEventTapCallBack = { _, type, event, refcon in
        guard let refcon else { return Unmanaged.passUnretained(event) }
        let monitor = Unmanaged<DockTitleBarClickMonitor>.fromOpaque(refcon).takeUnretainedValue()
        return monitor.handleEvent(type: type, event: event)
    }

    private let onDoubleClick: (CGPoint) -> Void

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(onDoubleClick: @escaping (CGPoint) -> Void) {
        self.onDoubleClick = onDoubleClick
    }

    deinit {
        stop()
    }

    func start() {
        guard eventTap == nil else { return }

        let eventMask = CGEventMask(1 << CGEventType.leftMouseDown.rawValue)
        guard let newEventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: Self.eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return
        }

        let newRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newEventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), newRunLoopSource, .commonModes)
        CGEvent.tapEnable(tap: newEventTap, enable: true)

        eventTap = newEventTap
        runLoopSource = newRunLoopSource
    }

    func stop() {
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

    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if let passthrough = reEnableIfNeeded(tap: eventTap, type: type, event: event) {
            return passthrough
        }

        guard type == .leftMouseDown,
              event.getIntegerValueField(.mouseEventClickState) >= 2
        else {
            return Unmanaged.passUnretained(event)
        }

        onDoubleClick(event.location)
        return Unmanaged.passUnretained(event)
    }
}
