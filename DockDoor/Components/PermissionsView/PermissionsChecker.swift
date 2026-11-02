import AppKit
import Combine
import SwiftUI

/// Polls until both permissions are granted and publishes only transitions:
/// `@Published` fires on every assignment, so unchanged ticks would redraw
/// every pane that shows a permission row.
class PermissionsChecker: ObservableObject {
    @Published private(set) var accessibilityPermission: Bool = false
    @Published private(set) var screenRecordingPermission: Bool = false
    private var timer: AnyCancellable?
    private var activation: AnyCancellable?

    private static var cachedScreenRecordingPermission: Bool = checkScreenRecordingPermissionFromCG()

    init() {
        checkPermissions()
        startPollingIfNeeded()
        // Returning from System Settings is when a grant usually lands.
        activation = NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.checkPermissions()
                self?.startPollingIfNeeded()
            }
    }

    deinit {
        timer?.cancel()
        activation?.cancel()
    }

    func checkPermissions() {
        setIfChanged(\.accessibilityPermission, to: checkAccessibilityPermission())
        setIfChanged(\.screenRecordingPermission, to: checkScreenRecordingPermission())
        if accessibilityPermission, screenRecordingPermission {
            timer?.cancel()
            timer = nil
        }
    }

    private func setIfChanged(_ keyPath: ReferenceWritableKeyPath<PermissionsChecker, Bool>, to value: Bool) {
        guard self[keyPath: keyPath] != value else { return }
        self[keyPath: keyPath] = value
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

    private func startPollingIfNeeded() {
        guard timer == nil, !(accessibilityPermission && screenRecordingPermission) else { return }
        timer = Timer.publish(every: 3, tolerance: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkPermissions()
            }
    }
}
