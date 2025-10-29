import Foundation
import SwiftUI

/// Factory for built-in native SwiftUI widgets
enum NativeWidgetFactory {
    /// Create a widget instance with full manifest context
    @MainActor
    static func createWidget(
        manifest: WidgetManifest,
        context: [String: String],
        mode: WidgetMode,
        screen: NSScreen,
        isPinnedMode: Bool = false
    ) -> AnyView? {
        guard let identifier = manifest.entry else { return nil }

        switch identifier {
        case "MediaControlsWidget":
            return createMediaControlsWidget(manifest: manifest, context: context, mode: mode, screen: screen, isPinnedMode: isPinnedMode)
        case "CalendarWidget":
            return createCalendarWidget(context: context, mode: mode, screen: screen)
        default:
            return nil
        }
    }

    // Removed mediaStore(for:) helper (unused).

    @MainActor
    private static func createMediaControlsWidget(
        manifest: WidgetManifest,
        context: [String: String],
        mode: WidgetMode,
        screen: NSScreen,
        isPinnedMode: Bool = false
    ) -> AnyView {
        // Ensure provider exists
        guard manifest.provider != nil else {
            return AnyView(Text("Missing provider").font(.caption).foregroundColor(.secondary))
        }

        let widgetView = MediaControlsWidgetView(
            manifest: manifest,
            context: context,
            mode: mode,
            screen: screen,
            isPinnedMode: isPinnedMode
        )
        return AnyView(widgetView)
    }

    @MainActor
    private static func createCalendarWidget(
        context: [String: String],
        mode: WidgetMode,
        screen: NSScreen
    ) -> AnyView {
        AnyView(CalendarWidgetView(
            context: context,
            appName: context["appName"] ?? "Unknown App",
            bundleIdentifier: context["bundleIdentifier"] ?? "",
            dockPosition: DockPosition(from: context["dockPosition"] ?? ""),
            screen: screen,
            mode: mode
        ))
    }
}
