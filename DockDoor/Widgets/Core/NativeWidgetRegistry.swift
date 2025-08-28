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

    /// Resolve a typed SimpleMediaStore for the first matching native media manifest for a bundle id.
    /// Returns nil if no suitable manifest/provider is installed.
    @MainActor
    static func mediaStore(for bundleId: String) -> MediaStore? {
        let manifests = WidgetRegistry.matchingWidgets(for: bundleId)
        guard let m = manifests.first(where: { $0.isNative() && $0.entry == "MediaControlsWidget" && $0.provider != nil }) else {
            return nil
        }
        return MediaStore(actions: m.actions)
    }

    @MainActor
    private static func createMediaControlsWidget(
        manifest: WidgetManifest,
        context: [String: String],
        mode: WidgetMode,
        screen: NSScreen,
        isPinnedMode: Bool = false
    ) -> AnyView {
        print("🎵 NativeWidgetRegistry createMediaControlsWidget - START")

        // Ensure provider exists
        guard manifest.provider != nil else {
            print("🎵 NativeWidgetRegistry createMediaControlsWidget - Missing provider!")
            return AnyView(Text("Missing provider").font(.caption).foregroundColor(.secondary))
        }

        print("🎵 NativeWidgetRegistry createMediaControlsWidget - About to create MediaControlsWidgetView")
        let widgetView = MediaControlsWidgetView(
            manifest: manifest,
            context: context,
            mode: mode,
            screen: screen,
            isPinnedMode: isPinnedMode
        )
        print("🎵 NativeWidgetRegistry createMediaControlsWidget - Created MediaControlsWidgetView, wrapping in AnyView")

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
