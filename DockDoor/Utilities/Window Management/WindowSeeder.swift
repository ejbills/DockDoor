import ApplicationServices
import Cocoa

final class WindowSeeder {
    func run() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(opts) else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            let myPID = ProcessInfo.processInfo.processIdentifier
            let apps = NSWorkspace.shared.runningApplications
                .filter { $0.activationPolicy == .regular && $0.processIdentifier != 0 && $0.processIdentifier != myPID }

            for app in apps {
                self.seedApp(app: app)
            }
        }
    }

    private func seedApp(app: NSRunningApplication) {
        _ = WindowUtil.discoverWindowsViaAX(app: app)
    }
}
