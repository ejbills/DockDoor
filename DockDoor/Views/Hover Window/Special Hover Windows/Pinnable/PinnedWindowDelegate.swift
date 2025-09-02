import SwiftUI

// MARK: - Pinning Extension for SharedPreviewWindowCoordinator

extension SharedPreviewWindowCoordinator {
    /// Check if a view is pinned
    func isPinned(bundleIdentifier: String, type: PinnableViewType) -> Bool {
        let key = "\(bundleIdentifier)-\(type.rawValue)"
        return pinnedWindows[key] != nil
    }

    /// Unpin all windows
    func unpinAll() {
        closeAllPinnedWindows()
    }

    /// Create a pinned window for a specific view type
    @MainActor
    func createPinnedWindow(appName: String, bundleIdentifier: String, type: PinnableViewType, isEmbedded: Bool = false) {
        let key = "\(bundleIdentifier)-\(type.rawValue)"

        if pinnedWindows[key] != nil { return }

        let styleMask: NSWindow.StyleMask = [.nonactivatingPanel, .fullSizeContentView, .borderless]

        let window = NSPanel(
            contentRect: .zero,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )

        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .transient, .fullScreenAuxiliary]
        window.hidesOnDeactivate = false
        window.becomesKeyOnlyIfNeeded = true
        window.isMovableByWindowBackground = true

        let contentView = switch type {
        case .media:
            // Try to use the widget system first
            if let manifest = WidgetRegistry.matchingWidgets(for: bundleIdentifier)
                .first(where: { $0.isNative() && $0.entry == "MediaControlsWidget" }),
                let widgetView = NativeWidgetFactory.createWidget(
                    manifest: manifest,
                    context: [
                        "appName": appName,
                        "bundleIdentifier": bundleIdentifier,
                        "dockPosition": DockUtils.getDockPosition().rawValue,
                    ],
                    mode: isEmbedded ? .embedded : .full,
                    screen: NSScreen.main ?? NSScreen.screens.first!,
                    isPinnedMode: true
                )
            {
                AnyView(widgetView.pinnableDisabled(key: key))
            } else {
                // Fallback to legacy view with no data (will be empty)
                AnyView(
                    MediaControlsView(
                        mediaInfo: nil,
                        appName: appName,
                        bundleIdentifier: bundleIdentifier,
                        dockPosition: DockUtils.getDockPosition(),
                        bestGuessMonitor: NSScreen.main ?? NSScreen.screens.first!,
                        isEmbeddedMode: isEmbedded,
                        isPinnedMode: true,
                        idealWidth: nil,
                        autoFetch: false
                    )
                    .pinnableDisabled(key: key)
                )
            }
        case .calendar:
            AnyView(
                CalendarView(
                    appName: appName,
                    bundleIdentifier: bundleIdentifier,
                    dockPosition: DockUtils.getDockPosition(),
                    bestGuessMonitor: NSScreen.main ?? NSScreen.screens.first!,
                    isEmbeddedMode: isEmbedded,
                    isPinnedMode: true,
                    calendarInfo: DailyCalendarInfo()
                )
                .pinnableDisabled(key: key)
            )
        }

        let hostingView = NSHostingView(rootView: contentView)
        window.contentView = hostingView

        // Let the view size itself, then fit window to content
        let fittingSize = hostingView.fittingSize

        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1000, height: 800)
        let existingCount = pinnedWindows.count

        let windowFrame = NSRect(
            x: screenFrame.midX - fittingSize.width / 2,
            y: screenFrame.midY - fittingSize.height / 2,
            width: fittingSize.width,
            height: fittingSize.height
        )

        window.setFrame(windowFrame, display: true)

        let delegate = PinnedWindowDelegate(coordinator: self, key: key)
        window.delegate = delegate

        pinnedWindows[key] = window
        window.makeKeyAndOrderFront(nil)
    }

    /// Close a specific pinned window
    @MainActor
    func closePinnedWindow(key: String) {
        if let window = pinnedWindows[key] {
            window.close()
            pinnedWindows.removeValue(forKey: key)
        }
    }

    /// Close all pinned windows
    func closeAllPinnedWindows() {
        for window in pinnedWindows.values {
            window.close()
        }
        pinnedWindows.removeAll()
    }
}

// MARK: - Pinned Window Delegate

private class PinnedWindowDelegate: NSObject, NSWindowDelegate {
    weak var coordinator: SharedPreviewWindowCoordinator?
    let key: String

    init(coordinator: SharedPreviewWindowCoordinator, key: String) {
        self.coordinator = coordinator
        self.key = key
        super.init()
    }

    func windowWillClose(_ notification: Notification) {
        coordinator?.closePinnedWindow(key: key)
    }
}
