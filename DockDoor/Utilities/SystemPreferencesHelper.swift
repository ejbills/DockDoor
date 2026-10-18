import AppKit

class SystemPreferencesHelper {
    static func openAccessibilityPreferences() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    static func openCalendarPreferences() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
    }

    static func openTrackpadPreferences() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Trackpad-Settings.extension")!)
    }

    static func openScreenRecordingPreferences() {
        // macOS only lists an app under Screen Recording once it has asked.
        if !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
        }
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
    }
}
