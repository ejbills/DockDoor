import SwiftUI

/// Bridge view that renders the existing MediaControlsView as a native widget.
@MainActor
struct MediaControlsWidgetView: View {
    let manifest: WidgetManifest
    let context: [String: String]
    let mode: WidgetMode
    let screen: NSScreen
    let isPinnedMode: Bool

    @StateObject private var mediaStore: MediaStore

    init(
        manifest: WidgetManifest,
        context: [String: String],
        mode: WidgetMode,
        screen: NSScreen,
        isPinnedMode: Bool = false
    ) {
        self.manifest = manifest
        self.context = context
        self.mode = mode
        self.screen = screen
        self.isPinnedMode = isPinnedMode
        _mediaStore = StateObject(wrappedValue: MediaStore(actions: manifest.actions))
    }

    var body: some View {
        MediaControlsView(
            mediaInfo: mediaStore,
            appName: context["appName"] ?? "Unknown",
            bundleIdentifier: context["bundleIdentifier"] ?? "",
            dockPosition: DockPosition(from: context["dockPosition"] ?? ""),
            bestGuessMonitor: screen,
            isEmbeddedMode: mode == .embedded,
            isPinnedMode: isPinnedMode,
            autoFetch: false
        )
        // Native media widgets handle their own polling (needed for both embedded and pinned usage)
        .widgetPolling(provider: manifest.provider) { updatedContext in
            mediaStore.updateFromContext(updatedContext)
        }
    }
}
