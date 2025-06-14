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
    func createPinnedWindow(appName: String, bundleIdentifier: String, type: PinnableViewType) {
        let key = "\(bundleIdentifier)-\(type.rawValue)"

        // Check if already exists
        if pinnedWindows[key] != nil {
            print("⚠️ Pinned window already exists for: \(key)")
            return
        }

        // Create borderless, movable window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )

        // Configure independent floating window
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.hidesOnDeactivate = false
        window.canBecomeVisibleWithoutLogin = true
        window.title = "\(appName) - \(type.displayName)"

        // Create content view for pinned windows
        let contentView = switch type {
        case .media:
            AnyView(
                MediaControlsView(
                    appName: appName,
                    bundleIdentifier: bundleIdentifier,
                    dockPosition: DockUtils.getDockPosition(),
                    bestGuessMonitor: NSScreen.main ?? NSScreen.screens.first!,
                    isEmbeddedMode: false,
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
                    isEmbeddedMode: false,
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

        print("✅ Created pinned window: \(key)")
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
