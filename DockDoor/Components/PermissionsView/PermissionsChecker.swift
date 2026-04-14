import Combine
import SwiftUI

class PermissionsChecker: ObservableObject {
    @Published var accessibilityPermission: Bool = false
    @Published var screenRecordingPermission: Bool = false
    private var timer: AnyCancellable?

    private static var cachedScreenRecordingPermission: Bool = checkScreenRecordingPermissionFromCG()

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

    static func hasScreenRecordingPermission() -> Bool {
        cachedScreenRecordingPermission
    }

    private static func checkScreenRecordingPermissionFromCG() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    private func startTimer() {
        timer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkPermissions()
            }
    }
}
