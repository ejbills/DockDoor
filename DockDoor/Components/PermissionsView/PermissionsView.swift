import SwiftUI

struct PermissionsView: View {
    var nextTab: (() -> Void)? = nil
    @StateObject private var permissionsChecker = PermissionsChecker()

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Permissions")
                    .font(.headline)
                Text("DockDoor needs the following macOS permissions to function.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer(minLength: 2)
                Divider()
                Spacer(minLength: 2)
                // Accessibility Row
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Accessibility").font(.headline)
                        Spacer()
                        Text(permissionsChecker.accessibilityPermission ? "Granted" : "Not Granted")
                            .foregroundColor(permissionsChecker.accessibilityPermission ? .green : .red)
                            .font(.subheadline)
                    }
                    Text("Required for dock hover detection and window switcher hotkeys.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    HStack(spacing: 8) {
                        Button("Change Accessibility permissions") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                Spacer(minLength: 2)
                Divider()
                Spacer(minLength: 2)
                // Screen Recording Row
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Screen Recording").font(.headline)
                        Spacer()
                        Text(permissionsChecker.screenRecordingPermission ? "Granted" : "Not Granted")
                            .foregroundColor(permissionsChecker.screenRecordingPermission ? .green : .red)
                            .font(.subheadline)
                    }
                    Text("Required for capturing window previews of other apps.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    HStack(spacing: 8) {
                        Button("Change Screen Recording permissions") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            if let nextTab {
                HStack {
                    Spacer()
                    Button(action: nextTab) {
                        Text("Next page")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}
