import Defaults
import SwiftUI

/// Shared interaction modifier for window preview views (both standard and compact)
/// Provides: middle click, trackpad gestures, context menu, and tap handling
struct WindowPreviewInteractionModifier: ViewModifier {
    let windowInfo: WindowInfo
    let windowSwitcherActive: Bool
    let dockPosition: DockPosition
    let useCompactMode: Bool
    let handleWindowAction: (WindowAction) -> Void
    let onTap: (() -> Void)?

    // Middle click
    @Default(.middleClickAction) private var middleClickAction

    // Dock Preview Gestures
    @Default(.enableDockPreviewGestures) private var enableDockPreviewGestures
    @Default(.dockSwipeTowardsDockAction) private var dockSwipeTowardsDockAction
    @Default(.dockSwipeAwayFromDockAction) private var dockSwipeAwayFromDockAction

    @State private var suppressTap = false

    func body(content: Content) -> some View {
        content
            .onMiddleClick {
                if middleClickAction != .none {
                    performAction(middleClickAction)
                }
            }
            .onTrackpadSwipe(
                onScrollingChanged: { scrolling in suppressTap = scrolling },
                onSwipeUp: { handleSwipe(.up) },
                onSwipeDown: { handleSwipe(.down) },
                onSwipeLeft: { handleSwipe(.left) },
                onSwipeRight: { handleSwipe(.right) }
            )
            .onTapGesture {
                guard !suppressTap else { return }
                handleWindowTap()
            }
            .contextMenu {
                windowContextMenu
            }
    }

    @ViewBuilder
    private var windowContextMenu: some View {
        if windowInfo.closeButton != nil {
            Button(action: { handleWindowAction(.minimize) }) {
                if windowInfo.isMinimized {
                    Label("Un-minimize", systemImage: "arrow.up.left.and.arrow.down.right.square")
                } else {
                    Label("Minimize", systemImage: "minus.square")
                }
            }

            Button(action: { handleWindowAction(.toggleFullScreen) }) {
                Label("Toggle Full Screen", systemImage: "arrow.up.left.and.arrow.down.right.square")
            }

            Divider()

            Button(action: { handleWindowAction(.close) }) {
                Label("Close", systemImage: "xmark.square")
            }

            Button(role: .destructive, action: { handleWindowAction(.quit) }) {
                if NSEvent.modifierFlags.contains(.option) {
                    Label("Force Quit", systemImage: "power")
                } else {
                    Label("Quit", systemImage: "minus.square.fill")
                }
            }
        }
    }

    // MARK: - Swipe Handling

    private enum SwipeDirection {
        case up, down, left, right
    }

    private func handleSwipe(_ direction: SwipeDirection) {
        guard !windowSwitcherActive else { return }
        guard enableDockPreviewGestures else { return }
        // In compact mode, use horizontal gestures (left/right) since vertical is for scrolling
        if useCompactMode {
            switch direction {
            case .left:
                performAction(dockSwipeTowardsDockAction)
            case .right:
                performAction(dockSwipeAwayFromDockAction)
            case .up, .down:
                break
            }
        } else {
            if isSwipeTowardsDock(direction) {
                performAction(dockSwipeTowardsDockAction)
            } else if isSwipeAwayFromDock(direction) {
                performAction(dockSwipeAwayFromDockAction)
            }
        }
    }

    private func isSwipeTowardsDock(_ direction: SwipeDirection) -> Bool {
        switch dockPosition {
        case .bottom: direction == .down
        case .top: direction == .up
        case .left: direction == .left
        case .right: direction == .right
        case .cmdTab, .cli, .unknown: direction == .down
        }
    }

    private func isSwipeAwayFromDock(_ direction: SwipeDirection) -> Bool {
        switch dockPosition {
        case .bottom: direction == .up
        case .top: direction == .down
        case .left: direction == .right
        case .right: direction == .left
        case .cmdTab, .cli, .unknown: direction == .up
        }
    }

    private func performAction(_ action: WindowAction) {
        guard action != .none else { return }
        handleWindowAction(action)
    }

    // MARK: - Tap Handling

    private func handleWindowTap() {
        if windowInfo.isMinimized {
            handleWindowAction(.minimize)
        } else if windowInfo.isHidden {
            handleWindowAction(.hide)
        } else {
            windowInfo.bringToFront()
            onTap?()
        }
    }
}

extension View {
    /// Applies shared window preview interactions (middle click, gestures, context menu, tap)
    func windowPreviewInteractions(
        windowInfo: WindowInfo,
        windowSwitcherActive: Bool,
        dockPosition: DockPosition,
        useCompactMode: Bool = false,
        handleWindowAction: @escaping (WindowAction) -> Void,
        onTap: (() -> Void)?
    ) -> some View {
        modifier(WindowPreviewInteractionModifier(
            windowInfo: windowInfo,
            windowSwitcherActive: windowSwitcherActive,
            dockPosition: dockPosition,
            useCompactMode: useCompactMode,
            handleWindowAction: handleWindowAction,
            onTap: onTap
        ))
    }
}
