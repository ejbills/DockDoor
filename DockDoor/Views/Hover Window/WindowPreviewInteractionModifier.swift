import Defaults
import SwiftUI

/// Shared interaction modifier for window preview views (both standard and compact)
/// Provides: middle click, trackpad gestures, context menu, and tap handling
struct WindowPreviewInteractionModifier: ViewModifier {
    let windowInfo: WindowInfo
    let windowSwitcherActive: Bool
    let dockPosition: DockPosition
    let handleWindowAction: (WindowAction) -> Void
    let onTap: (() -> Void)?

    // Middle click
    @Default(.middleClickAction) private var middleClickAction

    // Dock Preview Gestures
    @Default(.enableDockPreviewGestures) private var enableDockPreviewGestures
    @Default(.dockSwipeTowardsDockAction) private var dockSwipeTowardsDockAction
    @Default(.dockSwipeAwayFromDockAction) private var dockSwipeAwayFromDockAction

    // Window Switcher Gestures
    @Default(.enableWindowSwitcherGestures) private var enableWindowSwitcherGestures
    @Default(.switcherSwipeUpAction) private var switcherSwipeUpAction
    @Default(.switcherSwipeDownAction) private var switcherSwipeDownAction

    func body(content: Content) -> some View {
        content
            .onMiddleClick {
                if middleClickAction != .none {
                    performAction(middleClickAction)
                }
            }
            .onTrackpadSwipe(
                onSwipeUp: { handleSwipe(.up) },
                onSwipeDown: { handleSwipe(.down) },
                onSwipeLeft: { handleSwipe(.left) },
                onSwipeRight: { handleSwipe(.right) }
            )
            .onTapGesture {
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
        if windowSwitcherActive {
            guard enableWindowSwitcherGestures else { return }
            switch direction {
            case .up:
                performAction(switcherSwipeUpAction)
            case .down:
                performAction(switcherSwipeDownAction)
            case .left, .right:
                break
            }
        } else {
            guard enableDockPreviewGestures else { return }
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
        case .cmdTab, .unknown: direction == .down
        }
    }

    private func isSwipeAwayFromDock(_ direction: SwipeDirection) -> Bool {
        switch dockPosition {
        case .bottom: direction == .up
        case .top: direction == .down
        case .left: direction == .right
        case .right: direction == .left
        case .cmdTab, .unknown: direction == .up
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
        handleWindowAction: @escaping (WindowAction) -> Void,
        onTap: (() -> Void)?
    ) -> some View {
        modifier(WindowPreviewInteractionModifier(
            windowInfo: windowInfo,
            windowSwitcherActive: windowSwitcherActive,
            dockPosition: dockPosition,
            handleWindowAction: handleWindowAction,
            onTap: onTap
        ))
    }
}
