import CoreGraphics
import Foundation

final class EventTapThread {
    static let shared = EventTapThread(name: "com.ethanbills.DockDoor.eventTap")

    private let thread: Thread
    private let ready = DispatchSemaphore(value: 0)
    private var runLoop: CFRunLoop!

    init(name: String) {
        var capturedRunLoop: CFRunLoop!
        let ready = ready
        thread = Thread {
            capturedRunLoop = CFRunLoopGetCurrent()
            var context = CFRunLoopSourceContext()
            let keepAlive = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &context)
            CFRunLoopAddSource(capturedRunLoop, keepAlive, .commonModes)
            ready.signal()
            CFRunLoopRun()
        }
        thread.name = name
        thread.qualityOfService = .userInteractive
        thread.start()
        ready.wait()
        runLoop = capturedRunLoop
    }

    func add(_ source: CFRunLoopSource) {
        CFRunLoopAddSource(runLoop, source, .commonModes)
        CFRunLoopWakeUp(runLoop)
    }

    func add(_ timer: CFRunLoopTimer) {
        CFRunLoopAddTimer(runLoop, timer, .commonModes)
        CFRunLoopWakeUp(runLoop)
    }

    func perform(_ block: @escaping () -> Void) {
        CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes.rawValue, block)
        CFRunLoopWakeUp(runLoop)
    }

    func remove(_ tap: CFMachPort, source: CFRunLoopSource?, then cleanup: (() -> Void)? = nil) {
        CGEvent.tapEnable(tap: tap, enable: false)
        CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes.rawValue) {
            if let source {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            }
            CFMachPortInvalidate(tap)
            cleanup?()
        }
        CFRunLoopWakeUp(runLoop)
    }
}
