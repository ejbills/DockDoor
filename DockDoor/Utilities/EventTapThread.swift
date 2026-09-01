import Foundation

final class EventTapThread {
    static let shared = EventTapThread()

    private let thread: Thread
    private let ready = DispatchSemaphore(value: 0)
    private var runLoop: CFRunLoop!

    private init() {
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
        thread.name = "com.ethanbills.DockDoor.eventTap"
        thread.qualityOfService = .userInteractive
        thread.start()
        ready.wait()
        runLoop = capturedRunLoop
    }

    func add(_ source: CFRunLoopSource) {
        CFRunLoopAddSource(runLoop, source, .commonModes)
        CFRunLoopWakeUp(runLoop)
    }

    func remove(_ source: CFRunLoopSource) {
        CFRunLoopRemoveSource(runLoop, source, .commonModes)
        CFRunLoopWakeUp(runLoop)
    }
}
