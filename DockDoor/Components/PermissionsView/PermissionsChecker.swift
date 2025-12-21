import Combine
import SwiftUI

class PermissionsChecker: ObservableObject {
    @Published var accessibilityPermission: Bool = false
    @Published var screenRecordingPermission: Bool = false
    private var timer: AnyCancellable?

    // Cached permission value - updated by timer, read by WindowUtil
    private static var cachedScreenRecordingPermission: Bool = // Initialize with actual check on first access
        checkScreenRecordingPermissionFromCG()

    init() {
        checkPermissions()
        startTimer()
    }

    deinit {
        timer?.cancel()
    }

    func checkPermissions() {
        accessibilityPermission = checkAccessibilityPermission()
        screenRecordingPermission = checkScreenRecordingPermission()
    }

    private func checkAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }

    private func checkScreenRecordingPermission() -> Bool {
        let result = Self.checkScreenRecordingPermissionFromCG()
        Self.cachedScreenRecordingPermission = result
        return result
    }

    /// Returns the cached screen recording permission value (cheap read)
    static func hasScreenRecordingPermission() -> Bool {
        cachedScreenRecordingPermission
    }

    /// Performs the actual CG API check (expensive)
    private static func checkScreenRecordingPermissionFromCG() -> Bool {
        let stream = CGDisplayStream(
            dispatchQueueDisplay: CGMainDisplayID(),
            outputWidth: 1,
            outputHeight: 1,
            pixelFormat: Int32(kCVPixelFormatType_32BGRA),
            properties: nil,
            queue: DispatchQueue.main,
            handler: { _, _, _, _ in }
        )
        let hasPermission = (stream != nil)
        stream?.stop()
        return hasPermission
    }

    private func startTimer() {
        timer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkPermissions()
            }
    }
}
