import Combine
import SwiftUI

class PermissionsChecker: ObservableObject {
    @Published var accessibilityPermission: Bool = false
    @Published var screenRecordingPermission: Bool = false
    private var timer: AnyCancellable?

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
