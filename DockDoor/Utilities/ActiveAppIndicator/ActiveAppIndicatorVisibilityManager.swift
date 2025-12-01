import Cocoa
import Defaults

/// Manages the visibility of the active app indicator based on dock auto-hide state.
/// Integrates with DockObserver to determine when the dock is being hovered.
///
/// This replaces the previous mouse-monitoring approach with a more reliable integration
/// that uses DockObserver's existing dock hover detection.
final class ActiveAppIndicatorVisibilityManager {
    private weak var coordinator: ActiveAppIndicatorCoordinator?

    /// Tracks whether the dock is currently visible (for auto-hide mode)
    private var isDockCurrentlyVisible: Bool = true

    /// Timer for debouncing the fade-out when leaving the dock
    private var dockHideDebounceTimer: Timer?

    init(coordinator: ActiveAppIndicatorCoordinator) {
        self.coordinator = coordinator

        // Set initial visibility state based on auto-hide setting
        if CoreDockGetAutoHideEnabled() {
            // If auto-hide is enabled, dock starts hidden
            isDockCurrentlyVisible = false
        } else {
            // If auto-hide is off, dock is always visible
            isDockCurrentlyVisible = true
        }
    }

    deinit {
        cleanup()
    }

    // MARK: - Cleanup

    private func cleanup() {
        dockHideDebounceTimer?.invalidate()
        dockHideDebounceTimer = nil
    }

    // MARK: - Dock Hover Notifications (called from DockObserver via Coordinator)

    /// Called when a dock item is being hovered (dock is visible)
    func notifyDockItemHovered() {
        guard Defaults[.showActiveAppIndicator] else { return }

        // Cancel any pending hide timer
        dockHideDebounceTimer?.invalidate()
        dockHideDebounceTimer = nil

        // If auto-hide is disabled, dock is always visible - no animation needed
        guard CoreDockGetAutoHideEnabled() else {
            if !isDockCurrentlyVisible {
                isDockCurrentlyVisible = true
                // Immediately show without animation since auto-hide was just disabled
                coordinator?.getIndicatorWindow()?.alphaValue = 1.0
            }
            return
        }

        // Show the indicator if it was hidden
        if !isDockCurrentlyVisible {
            isDockCurrentlyVisible = true
            fadeInIndicator()
        }
    }

    /// Called when no dock item is hovered (user may have left the dock area)
    func notifyDockItemUnhovered() {
        guard Defaults[.showActiveAppIndicator] else { return }

        // If auto-hide is disabled, dock is always visible - don't hide the indicator
        guard CoreDockGetAutoHideEnabled() else { return }

        // Cancel any previous hide timer
        dockHideDebounceTimer?.invalidate()

        // Start a debounce timer before hiding
        // This prevents flickering when moving between dock items
        let fadeOutDelay = Defaults[.activeAppIndicatorFadeOutDelay]
        dockHideDebounceTimer = Timer.scheduledTimer(withTimeInterval: fadeOutDelay, repeats: false) { [weak self] _ in
            guard let self else { return }
            isDockCurrentlyVisible = false
            fadeOutIndicator()
            dockHideDebounceTimer = nil
        }
    }

    // MARK: - Animation

    private func fadeInIndicator() {
        guard let window = coordinator?.getIndicatorWindow() else { return }

        let fadeInDuration = Defaults[.activeAppIndicatorFadeInDuration]
        let fadeInDelay = Defaults[.activeAppIndicatorFadeInDelay]

        // Apply delay before starting fade-in animation
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeInDelay) { [weak self, weak window] in
            guard self != nil, let window else { return }

            if fadeInDuration > 0 {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = fadeInDuration
                    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    window.animator().alphaValue = 1.0
                }
            } else {
                window.alphaValue = 1.0
            }
        }
    }

    private func fadeOutIndicator() {
        guard let window = coordinator?.getIndicatorWindow() else { return }

        let fadeOutDuration = Defaults[.activeAppIndicatorFadeOutDuration]

        if fadeOutDuration > 0 {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = fadeOutDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                window.animator().alphaValue = 0.0
            }
        } else {
            window.alphaValue = 0.0
        }
    }

    // MARK: - State Query

    /// Returns whether the dock is currently considered visible
    func isDockVisible() -> Bool {
        isDockCurrentlyVisible
    }
}
