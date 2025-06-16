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

        if pinnedWindows[key] != nil {
            print("⚠️ Pinned window already exists for: \(key)")
            return
        }

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
            AnyView(
                MediaControlsView(
                    appName: appName,
                    bundleIdentifier: bundleIdentifier,
                    dockPosition: DockUtils.getDockPosition(),
                    bestGuessMonitor: NSScreen.main ?? NSScreen.screens.first!,
                    isEmbeddedMode: isEmbedded,
                    isPinnedMode: true
                )
                .pinnableDisabled(key: key)
            )
        case .calendar:
            AnyView(
                CalendarView(
                    appName: appName,
                    bundleIdentifier: bundleIdentifier,
                    dockPosition: DockUtils.getDockPosition(),
                    bestGuessMonitor: NSScreen.main ?? NSScreen.screens.first!,
                    isEmbeddedMode: isEmbedded,
                    isPinnedMode: true
                )
                .pinnableDisabled(key: key)
            )
        }

        let hostingView = NSHostingView(rootView: contentView)
        window.contentView = hostingView

        // Let the view size itself, then fit window to content
        let fittingSize = hostingView.fittingSize

        // Position with cascade for multiple windows
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1000, height: 800)
        let existingCount = pinnedWindows.count
        let offset = CGFloat(existingCount) * 30

        let windowFrame = NSRect(
            x: screenFrame.midX - fittingSize.width / 2 + offset,
            y: screenFrame.midY - fittingSize.height / 2 - offset,
            width: fittingSize.width,
            height: fittingSize.height
        )

        window.setFrame(windowFrame, display: true)

        // Set up delegate for cleanup
        let delegate = PinnedWindowDelegate(coordinator: self, key: key)
        window.delegate = delegate

        // Store and show
        pinnedWindows[key] = window
        window.makeKeyAndOrderFront(nil)

        print("✅ Created pinned window: \(key) - Embedded: \(isEmbedded)")
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
