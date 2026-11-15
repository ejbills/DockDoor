import AppKit

class SystemPreferencesHelper {
    private static var resetServices: Set<String> = []

    static func openAccessibilityPreferences() {
        if !AXIsProcessTrusted(), resetPermissionOnce("Accessibility") {
            AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        }
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    static func openCalendarPreferences() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
    }

    static func openTrackpadPreferences() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Trackpad-Settings.extension")!)
    }

    static func openScreenRecordingPreferences() {
        if !CGPreflightScreenCaptureAccess(), resetPermissionOnce("ScreenCapture") {
            CGRequestScreenCaptureAccess()
        }
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
    }

    private static func resetPermissionOnce(_ service: String) -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier, resetServices.insert(service).inserted else { return false }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        task.arguments = ["reset", service, bundleID]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
        } catch {
            return false
        }
        task.waitUntilExit()
        return true
    }
}
