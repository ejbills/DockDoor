import SwiftUI

// MARK: - Pinned Window Info

/// Stores metadata about a pinned window for later modification
struct PinnedWindowInfo {
    let appName: String
    let bundleIdentifier: String
    var type: PinnableViewType
    var isEmbedded: Bool
}

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
    func createPinnedWindow(appName: String, bundleIdentifier: String, type: PinnableViewType, isEmbedded: Bool = false, preservePosition: CGPoint? = nil) {
        let key = "\(bundleIdentifier)-\(type.rawValue)"

        if pinnedWindows[key] != nil {
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
                    dockItemElement: nil,
                    isEmbeddedMode: isEmbedded,
                    isPinnedMode: true
                )
                .pinnableDisabled(key: key, type: type, isEmbedded: isEmbedded)
            )
        case .calendar:
            AnyView(
                CalendarView(
                    appName: appName,
                    bundleIdentifier: bundleIdentifier,
                    dockPosition: DockUtils.getDockPosition(),
                    bestGuessMonitor: NSScreen.main ?? NSScreen.screens.first!,
                    dockItemElement: nil,
                    isEmbeddedMode: isEmbedded,
                    isPinnedMode: true
                )
                .pinnableDisabled(key: key, type: type, isEmbedded: isEmbedded)
            )
        }

        let hostingView = NSHostingView(rootView: contentView)
        window.contentView = hostingView

        let fittingSize = hostingView.fittingSize

        let windowFrame: NSRect
        if let position = preservePosition {
            windowFrame = NSRect(
                x: position.x,
                y: position.y,
                width: fittingSize.width,
                height: fittingSize.height
            )
        } else {
            let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1000, height: 800)
            windowFrame = NSRect(
                x: screenFrame.midX - fittingSize.width / 2,
                y: screenFrame.midY - fittingSize.height / 2,
                width: fittingSize.width,
                height: fittingSize.height
            )
        }

        window.setFrame(windowFrame, display: true)

        let delegate = PinnedWindowDelegate(coordinator: self, key: key)
        window.delegate = delegate

        let info = PinnedWindowInfo(
            appName: appName,
            bundleIdentifier: bundleIdentifier,
            type: type,
            isEmbedded: isEmbedded
        )
        pinnedWindows[key] = (window: window, info: info)
        window.makeKeyAndOrderFront(nil)
    }

    /// Toggle between full and compact mode for a pinned window
    @MainActor
    func togglePinnedWindowMode(key: String) {
        guard let entry = pinnedWindows[key] else { return }

        let currentPosition = entry.window.frame.origin
        let info = entry.info

        pinnedWindows.removeValue(forKey: key)
        entry.window.close()

        createPinnedWindow(
            appName: info.appName,
            bundleIdentifier: info.bundleIdentifier,
            type: info.type,
            isEmbedded: !info.isEmbedded,
            preservePosition: currentPosition
        )
    }

    /// Close a specific pinned window
    @MainActor
    func closePinnedWindow(key: String) {
        if let entry = pinnedWindows.removeValue(forKey: key) {
            entry.window.close()
        }
    }

    /// Close all pinned windows
    func closeAllPinnedWindows() {
        for entry in pinnedWindows.values {
            entry.window.close()
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
