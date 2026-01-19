import Cocoa
import Defaults
import SwiftUI

/// Manages the active app indicator that shows a line next to the currently active app in the dock.
/// Supports bottom, left, and right dock positions.
final class ActiveAppIndicatorCoordinator {
    static var shared: ActiveAppIndicatorCoordinator?

    private var indicatorWindow: ActiveAppIndicatorWindow?
    private var workspaceObserver: NSObjectProtocol?
    private var positionSettingsObserver: Defaults.Observation?
    private var screenParametersObserver: NSObjectProtocol?

    // Dock layout observer (detects when dock icons are added/removed)
    private var dockLayoutObserver: AXObserver?
    private var observedDockList: AXUIElement?

    private var currentActiveApp: NSRunningApplication?

    // Delayed position update timer (handles dock animation)
    private var delayedUpdateTimer: Timer?
    private let delayedUpdateInterval: TimeInterval = 0.6

    // Dock state tracking
    private var lastKnownDockPosition: DockPosition
    private var lastKnownDockSize: CGFloat
    private var isDockCurrentlyVisible: Bool = true

    init() {
        lastKnownDockPosition = DockUtils.getDockPosition()
        lastKnownDockSize = DockUtils.getDockSize()

        ActiveAppIndicatorCoordinator.shared = self
        setupObservers()
        showIndicator()
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
            if let app = notification.userInfo?[
                NSWorkspace.applicationUserInfoKey
            ] as? NSRunningApplication {
                self?.handleActiveAppChanged(app)
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
            print("[Indicator:positionSettingsObserver] Settings changed")
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

        // Observe dock layout changes (detects when icons are added/removed)
        setupDockLayoutObserver()
    }

    private func setupDockLayoutObserver() {
        guard let dockApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            return
        }

        let dockPID = dockApp.processIdentifier
        let dockElement = AXUIElementCreateApplication(dockPID)

        // Find the dock's list element
        guard let children = try? dockElement.children(),
              let dockList = children.first(where: { (try? $0.role()) == kAXListRole })
        else {
            return
        }

        // Create observer for dock layout changes
        var observer: AXObserver?
        guard AXObserverCreate(dockPID, { _, _, _, refcon in
            // Callback when dock layout changes
            guard let refcon else { return }
            let coordinator = Unmanaged<ActiveAppIndicatorCoordinator>.fromOpaque(refcon).takeUnretainedValue()
            DispatchQueue.main.async {
                coordinator.handleDockLayoutChanged()
            }
        }, &observer) == .success, let observer else {
            return
        }

        // Subscribe to UI element destroyed notification on the dock list
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        AXObserverAddNotification(observer, dockList, kAXUIElementDestroyedNotification as CFString, refcon)
        AXObserverAddNotification(observer, dockList, kAXCreatedNotification as CFString, refcon)

        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)

        dockLayoutObserver = observer
        observedDockList = dockList
    }

    private func handleDockLayoutChanged() {
        print("[Indicator:dockLayoutObserver] Dock layout changed (icon added/removed)")
        // Dock layout changed (icon added/removed) - schedule delayed update
        scheduleDelayedUpdate()
    }

    func handleSpaceChanged() {
        print("[Indicator:spaceChangeObserver] Space changed")
        // Space changed (possibly entering/exiting fullscreen)
        // Longer delay to allow fullscreen animation to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.updateDockVisibilityState()
        }
    }

    private func updateDockVisibilityState() {
        let isVisible = DockObserver.isDockVisible()

        guard isVisible != isDockCurrentlyVisible else { return }
        isDockCurrentlyVisible = isVisible

        if isVisible {
            // Dock became visible - show indicator for current app
            if let app = currentActiveApp {
                updateIndicatorPosition(for: app)
            }
        } else {
            // Dock is hidden - hide the indicator
            indicatorWindow?.orderOut(self)
        }
    }

    private func cleanup() {
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        if let observer = screenParametersObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        // Remove dock layout observer
        if let observer = dockLayoutObserver, let dockList = observedDockList {
            AXObserverRemoveNotification(observer, dockList, kAXUIElementDestroyedNotification as CFString)
            AXObserverRemoveNotification(observer, dockList, kAXCreatedNotification as CFString)
        }
        dockLayoutObserver = nil
        observedDockList = nil
        delayedUpdateTimer?.invalidate()
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
            // Also check visibility state as dock may have auto-hidden
            updateDockVisibilityState()
            scheduleDelayedUpdate()
        }
    }

    // MARK: - Dock Item Change Notifications

    /// Called when dock items may have shifted (app launch, terminate, minimize, etc.)
    /// Schedules a delayed position update to account for dock animation.
    func notifyDockItemsChanged() {
        scheduleDelayedUpdate()
    }

    /// Schedules a delayed position update. Called when dock layout might be changing.
    private func scheduleDelayedUpdate() {
        // Ensure we're on main thread for timer
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // Invalidate existing timer and schedule new one
            delayedUpdateTimer?.invalidate()
            delayedUpdateTimer = Timer.scheduledTimer(
                withTimeInterval: delayedUpdateInterval,
                repeats: false
            ) { [weak self] _ in
                guard let self else { return }
                delayedUpdateTimer = nil
                guard let app = currentActiveApp else { return }
                updateIndicatorPosition(for: app)
            }
        }
    }

    // MARK: - Dock Orientation Notifications

    /// Called when dock orientation changes
    private func notifyDockPositionChanged(newPosition: DockPosition) {
        // Hide indicator if dock moved to unsupported position
        if !ActiveAppIndicatorPositioning.isSupported(newPosition) {
            indicatorWindow?.orderOut(self)
        } else if let app = currentActiveApp {
            // Dock moved to a supported position - reposition indicator
            updateIndicatorPosition(for: app)
        }
    }

    // MARK: - Visibility Management

    private func showIndicator() {
        if indicatorWindow == nil {
            indicatorWindow = ActiveAppIndicatorWindow()
        }
        // Update with current frontmost app
        if let frontmost = NSWorkspace.shared.frontmostApplication {
            handleActiveAppChanged(frontmost)
        }
    }

    private func hideIndicator() {
        indicatorWindow?.orderOut(self)
        indicatorWindow = nil
        currentActiveApp = nil
    }

    // MARK: - Active App Handling

    private func handleActiveAppChanged(_ app: NSRunningApplication) {
        print("[Indicator:workspaceObserver] Active app changed: \(app.localizedName ?? "unknown")")
        currentActiveApp = app

        // Don't show indicator for the Dock itself
        guard app.bundleIdentifier != "com.apple.dock" else {
            indicatorWindow?.orderOut(self)
            return
        }

        // Refresh dock visibility state on app change
        isDockCurrentlyVisible = DockObserver.isDockVisible()

        // Update immediately (for instant response when clicking dock icons)
        updateIndicatorPosition(for: app)

        // Also schedule a delayed update (handles dock animation when apps appear/disappear)
        scheduleDelayedUpdate()
    }

    private func updateIndicatorPosition(for app: NSRunningApplication) {
        // Don't show indicator if dock is currently hidden
        guard isDockCurrentlyVisible else {
            indicatorWindow?.orderOut(self)
            return
        }

        guard let indicatorWindow else {
            return
        }

        guard let dockItemFrame = ActiveAppIndicatorDockDetection.getDockItemFrame(for: app) else {
            indicatorWindow.orderOut(self)
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
