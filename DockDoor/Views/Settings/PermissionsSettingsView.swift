import AppKit
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

struct PermissionsSettingsView: View {
    @StateObject private var permissionsChecker = PermissionsChecker()

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            permissionRow(
                title: "Accessibility",
                description: "Required for dock hover detection and window switcher hotkeys",
                isGranted: permissionsChecker.accessibilityPermission,
                iconName: "accessibility",
                action: openAccessibilityPreferences
            )

            Divider()

            permissionRow(
                title: "Screen recording",
                description: "Needed to capture window previews of other apps",
                isGranted: permissionsChecker.screenRecordingPermission,
                iconName: "video.fill",
                action: openScreenRecordingPreferences
            )

            Divider()

            Text("Changes to permissions require an application restart")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding(.top, 16)

            Button(action: restartApp) {
                Text("Restart app")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 8)
        }
        .navigationBarBackButtonHidden(true)
        .padding(32)
        .background {
            BlurView()
                .ignoresSafeArea(.all)
        }
    }

    private func permissionRow(title: String, description: String, isGranted: Bool, iconName: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 24))
                .foregroundColor(.accentColor)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .background(FluidGradientView().opacity(0.125))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .frame(width: 300)
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                HStack {
                    Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isGranted ? .green : .red)
                        .font(.system(size: 20))
                    Text(isGranted ? "Granted" : "Not granted")
                }
                .padding(16)
                .background(isGranted ? .green.opacity(0.25) : .red.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                Button(action: action) {
                    Text("Open Settings")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            }
        }
        .frame(maxHeight: 50)
        .padding(.vertical, 8)
    }

    private func openAccessibilityPreferences() {
        SystemPreferencesHelper.openAccessibilityPreferences()
    }

    private func openScreenRecordingPreferences() {
        SystemPreferencesHelper.openScreenRecordingPreferences()
    }

    private func restartApp() {
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        appDelegate.restartApp()
    }
}
