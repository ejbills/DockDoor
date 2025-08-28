import AppKit
import Foundation

/// Generic action router for declarative widgets.
/// Widgets emit opaque action strings; the host interprets and executes
/// built-in safe actions (no per-widget code wiring).
final class ActionRouter {
    static let shared = ActionRouter()
    private init() {}

    func route(_ action: String, context: [String: String] = [:]) {
        // Simple scheme: verb:payload or verb://url
        // Examples:
        // - open.app:com.apple.SystemSettings
        // - open.url:https://example.com
        // - open.systemsettings:general
        // Future: media.playPause, applescript.run:identifier, etc.

        let parts = action.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
        guard let verb = parts.first.map(String.init) else { return }
        let payload = parts.count > 1 ? String(parts[1]) : ""

        switch verb {
        case "open.app":
            openApp(bundleId: payload)
        case "open.url":
            if let url = URL(string: payload) { NSWorkspace.shared.open(url) }
        case "open.systemsettings":
            openSystemSettings(pane: payload)
        default:
            break
        }
    }

    private func openApp(bundleId: String) {
        guard !bundleId.isEmpty else { return }
        NSWorkspace.shared.launchApplication(withBundleIdentifier: bundleId, options: [.default], additionalEventParamDescriptor: nil, launchIdentifier: nil)
    }

    private func openSystemSettings(pane: String) {
        // Try classic System Preferences pane URL first for compatibility
        if !pane.isEmpty, let url = URL(string: "x-apple.systempreferences:com.apple.preference.\(pane)") {
            if NSWorkspace.shared.open(url) { return }
        }
        // Fallback: open app(s)
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.SystemSettings") ??
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.systempreferences")
        {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
        }
    }
}
