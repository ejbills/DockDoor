import Cocoa
import Defaults
import SwiftUI

/// Manages the active app indicator that shows a line next to the currently active app in the dock.
/// Supports bottom, left, and right dock positions.
final class ActiveAppIndicatorCoordinator {
    static var shared: ActiveAppIndicatorCoordinator?

    private var indicatorWindow: ActiveAppIndicatorWindow?
    private var workspaceObserver: NSObjectProtocol?
    private var settingsObserver: Defaults.Observation?
    private var positionSettingsObserver: Defaults.Observation?
    private var screenParametersObserver: NSObjectProtocol?

    private var currentActiveApp: NSRunningApplication?

    // Dock item shift tracking (app launch/terminate/minimize)
    private var dockShiftDebounceTimer: Timer?

    // Dock state tracking
    private var lastKnownDockPosition: DockPosition
    private var lastKnownDockSize: CGFloat

    // Auto-hide visibility tracking
    private var isDockCurrentlyVisible: Bool = true
    private var dockHideDebounceTimer: Timer?

    init() {
        lastKnownDockPosition = DockUtils.getDockPosition()
        lastKnownDockSize = DockUtils.getDockSize()
        isDockCurrentlyVisible = !CoreDockGetAutoHideEnabled()

        ActiveAppIndicatorCoordinator.shared = self
        setupObservers()
        updateIndicatorVisibility()
    }

    deinit {
        cleanup()
        if ActiveAppIndicatorCoordinator.shared === self {
            ActiveAppIndicatorCoordinator.shared = nil
        }
    }

    // MARK: - Setup

    private func setupObservers() {
        // Observe frontmost app changes
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard Defaults[.showActiveAppIndicator] else { return }
            if let app = notification.userInfo?[
                NSWorkspace.applicationUserInfoKey
            ] as? NSRunningApplication {
                self?.handleActiveAppChanged(app)
            }
        }

        // Observe enable/disable setting
        settingsObserver = Defaults.observe(.showActiveAppIndicator) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateIndicatorVisibility()
            }
        }

        // Observe all position-related settings with a single observer
        // Color is handled by @Default in the SwiftUI view automatically
        positionSettingsObserver = Defaults.observe(
            keys: .activeAppIndicatorAutoSize,
            .activeAppIndicatorAutoLength,
            .activeAppIndicatorHeight,
            .activeAppIndicatorOffset,
            .activeAppIndicatorLength,
            .activeAppIndicatorShift
        ) { [weak self] in
            DispatchQueue.main.async {
                guard let self, let app = self.currentActiveApp else { return }
                self.updateIndicatorPosition(for: app)
            }
        }

        // Observe screen parameter changes (dock position/size changes)
        screenParametersObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenParametersChanged()
        }
    }

    private func cleanup() {
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        if let observer = screenParametersObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        dockShiftDebounceTimer?.invalidate()
        dockHideDebounceTimer?.invalidate()
        settingsObserver?.invalidate()
        positionSettingsObserver?.invalidate()
        hideIndicator()
    }

    private func handleScreenParametersChanged() {
        let newDockPosition = DockUtils.getDockPosition()
        let newDockSize = DockUtils.getDockSize()

        // Check if dock position changed
        if newDockPosition != lastKnownDockPosition {
            lastKnownDockPosition = newDockPosition
            notifyDockPositionChanged(newPosition: newDockPosition)
        }

        // Check if dock size changed (refresh indicator position for auto-size)
        if newDockSize != lastKnownDockSize {
            lastKnownDockSize = newDockSize
            notifyDockItemsChanged()
        }
    }

    // MARK: - Dock Item Change Notifications

    /// Called when dock items may have shifted (app launch, terminate, minimize, etc.)
    /// Refreshes the indicator position after a debounced delay to account for dock animation.
    func notifyDockItemsChanged() {
        guard Defaults[.showActiveAppIndicator] else { return }

        // Debounce to avoid multiple rapid updates and wait for dock animation
        dockShiftDebounceTimer?.invalidate()
        dockShiftDebounceTimer = Timer.scheduledTimer(
            withTimeInterval: 0.5,
            repeats: false
        ) { [weak self] _ in
            guard let self, let app = currentActiveApp else { return }
            updateIndicatorPosition(for: app)
        }
    }

    // MARK: - Dock Orientation & Visibility Notifications

    /// Called when dock orientation changes
    func notifyDockPositionChanged(newPosition: DockPosition) {
        guard Defaults[.showActiveAppIndicator] else { return }

        // Hide indicator if dock moved to unsupported position
        if !ActiveAppIndicatorPositioning.isSupported(newPosition) {
            indicatorWindow?.orderOut(self)
        } else if let app = currentActiveApp {
            // Dock moved to a supported position - reposition indicator
            updateIndicatorPosition(for: app)
        }
    }

    /// Called by DockObserver when a dock item is being hovered
    func notifyDockItemHovered() {
        guard Defaults[.showActiveAppIndicator] else { return }

        // Cancel any pending hide timer
        dockHideDebounceTimer?.invalidate()
        dockHideDebounceTimer = nil

        // If auto-hide is disabled, dock is always visible - no animation needed
        guard CoreDockGetAutoHideEnabled() else {
            if !isDockCurrentlyVisible {
                isDockCurrentlyVisible = true
                indicatorWindow?.alphaValue = 1.0
            }
            return
        }

        // Show the indicator if it was hidden
        if !isDockCurrentlyVisible {
            isDockCurrentlyVisible = true
            fadeInIndicator()
        }
    }

    /// Called by DockObserver when no dock item is hovered
    func notifyDockItemUnhovered() {
        guard Defaults[.showActiveAppIndicator] else { return }

        // If auto-hide is disabled, dock is always visible - don't hide the indicator
        guard CoreDockGetAutoHideEnabled() else { return }

        // Cancel any previous hide timer
        dockHideDebounceTimer?.invalidate()

        // Start a debounce timer before hiding
        let fadeOutDelay = Defaults[.activeAppIndicatorFadeOutDelay]
        dockHideDebounceTimer = Timer.scheduledTimer(
            withTimeInterval: fadeOutDelay,
            repeats: false
        ) { [weak self] _ in
            guard let self else { return }
            isDockCurrentlyVisible = false
            fadeOutIndicator()
            dockHideDebounceTimer = nil
        }
    }

    // MARK: - Visibility Management

    private func updateIndicatorVisibility() {
        if Defaults[.showActiveAppIndicator] {
            showIndicator()
            // Update with current frontmost app
            if let frontmost = NSWorkspace.shared.frontmostApplication {
                handleActiveAppChanged(frontmost)
            }
        } else {
            hideIndicator()
        }
    }

    private func showIndicator() {
        if indicatorWindow == nil {
            indicatorWindow = ActiveAppIndicatorWindow()

            // Set initial alpha based on dock auto-hide state
            if CoreDockGetAutoHideEnabled() {
                indicatorWindow?.alphaValue = 0.0
            } else {
                indicatorWindow?.alphaValue = 1.0
            }
        }
    }

    private func fadeInIndicator() {
        guard let window = indicatorWindow else { return }

        let fadeInDuration = Defaults[.activeAppIndicatorFadeInDuration]
        let fadeInDelay = Defaults[.activeAppIndicatorFadeInDelay]

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
        guard let window = indicatorWindow else { return }

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

    private func hideIndicator() {
        indicatorWindow?.orderOut(self)
        indicatorWindow = nil
        currentActiveApp = nil
    }

    // MARK: - Active App Handling

    private func handleActiveAppChanged(_ app: NSRunningApplication) {
        currentActiveApp = app

        // Don't show indicator for the Dock itself or Finder's desktop
        guard app.bundleIdentifier != "com.apple.dock" else {
            indicatorWindow?.orderOut(self)
            return
        }

        updateIndicatorPosition(for: app)
    }

    private func updateIndicatorPosition(for app: NSRunningApplication) {
        guard let indicatorWindow,
              let dockItemFrame = ActiveAppIndicatorDockDetection.getDockItemFrame(for: app)
        else {
            indicatorWindow?.orderOut(self)
            return
        }

        let dockPosition = DockUtils.getDockPosition()

        // Check if dock position is supported
        guard ActiveAppIndicatorPositioning.isSupported(dockPosition) else {
            indicatorWindow.orderOut(self)
            return
        }

        ActiveAppIndicatorDockDetection.positionIndicator(
            indicatorWindow,
            relativeTo: dockItemFrame,
            dockPosition: dockPosition
        )
        indicatorWindow.orderFront(self)
    }
}
