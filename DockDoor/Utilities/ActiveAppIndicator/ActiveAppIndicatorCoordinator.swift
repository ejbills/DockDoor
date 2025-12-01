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
    private var colorObserver: Defaults.Observation?
    private var heightObserver: Defaults.Observation?
    private var offsetObserver: Defaults.Observation?

    private var currentActiveApp: NSRunningApplication?

    // Dock item shift tracking (app launch/terminate/minimize)
    private var dockShiftDebounceTimer: Timer?

    // Dock state observers (orientation and auto-hide visibility)
    private var orientationObserver: ActiveAppIndicatorOrientationObserver?
    private var visibilityManager: ActiveAppIndicatorVisibilityManager?

    init() {
        ActiveAppIndicatorCoordinator.shared = self
        setupObservers()
        setupDockStateObservers()
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
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                self?.handleActiveAppChanged(app)
            }
        }

        // Observe settings changes
        settingsObserver = Defaults.observe(.showActiveAppIndicator) { [weak self] change in
            DispatchQueue.main.async {
                self?.updateIndicatorVisibility()
            }
        }

        colorObserver = Defaults.observe(.activeAppIndicatorColor) { [weak self] _ in
            DispatchQueue.main.async {
                self?.indicatorWindow?.updateAppearance()
            }
        }

        heightObserver = Defaults.observe(.activeAppIndicatorHeight) { [weak self] _ in
            DispatchQueue.main.async {
                self?.indicatorWindow?.updateAppearance()
                if let app = self?.currentActiveApp {
                    self?.updateIndicatorPosition(for: app)
                }
            }
        }

        offsetObserver = Defaults.observe(.activeAppIndicatorOffset) { [weak self] _ in
            DispatchQueue.main.async {
                if let app = self?.currentActiveApp {
                    self?.updateIndicatorPosition(for: app)
                }
            }
        }
    }

    private func setupDockStateObservers() {
        // Initialize observers for dock orientation changes and auto-hide visibility
        orientationObserver = ActiveAppIndicatorOrientationObserver(coordinator: self)
        visibilityManager = ActiveAppIndicatorVisibilityManager(coordinator: self)
    }

    private func cleanup() {
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        dockShiftDebounceTimer?.invalidate()
        settingsObserver?.invalidate()
        colorObserver?.invalidate()
        heightObserver?.invalidate()
        offsetObserver?.invalidate()
        orientationObserver = nil
        visibilityManager = nil
        hideIndicator()
    }

    // MARK: - Dock Item Change Notifications

    /// Called when dock items may have shifted (app launch, terminate, minimize, etc.)
    /// Refreshes the indicator position after a debounced delay to account for dock animation.
    func notifyDockItemsChanged() {
        guard Defaults[.showActiveAppIndicator] else { return }

        // Debounce to avoid multiple rapid updates and wait for dock animation
        dockShiftDebounceTimer?.invalidate()
        dockShiftDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
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
            indicatorWindow?.orderOut(nil)
        } else if let app = currentActiveApp {
            // Dock moved to a supported position - reposition indicator
            updateIndicatorPosition(for: app)
        }
    }

    /// Called by DockObserver when a dock item is being hovered
    func notifyDockItemHovered() {
        visibilityManager?.notifyDockItemHovered()
    }

    /// Called by DockObserver when no dock item is hovered
    func notifyDockItemUnhovered() {
        visibilityManager?.notifyDockItemUnhovered()
    }

    /// Getter for indicator window (used by visibility manager)
    func getIndicatorWindow() -> ActiveAppIndicatorWindow? {
        indicatorWindow
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
            // Visibility manager will handle the visibility logic via DockObserver
            if CoreDockGetAutoHideEnabled() {
                // If auto-hide is enabled, start with invisible (DockObserver will show when needed)
                indicatorWindow?.alphaValue = 0.0
            } else {
                // If auto-hide is off, dock is always visible
                indicatorWindow?.alphaValue = 1.0
            }
        }
    }

    private func hideIndicator() {
        indicatorWindow?.orderOut(nil)
        indicatorWindow = nil
        currentActiveApp = nil
    }

    // MARK: - Active App Handling

    private func handleActiveAppChanged(_ app: NSRunningApplication) {
        currentActiveApp = app

        // Don't show indicator for the Dock itself or Finder's desktop
        guard app.bundleIdentifier != "com.apple.dock" else {
            indicatorWindow?.orderOut(nil)
            return
        }

        updateIndicatorPosition(for: app)
    }

    private func updateIndicatorPosition(for app: NSRunningApplication) {
        guard let indicatorWindow,
              let dockItemFrame = getDockItemFrame(for: app)
        else {
            indicatorWindow?.orderOut(nil)
            return
        }

        let dockPosition = DockUtils.getDockPosition()

        // Check if dock position is supported
        guard ActiveAppIndicatorPositioning.isSupported(dockPosition) else {
            indicatorWindow.orderOut(nil)
            return
        }

        positionIndicator(relativeTo: dockItemFrame, dockPosition: dockPosition)
        indicatorWindow.orderFront(nil)
    }

    // MARK: - Dock Item Detection

    private func getDockItemFrame(for app: NSRunningApplication) -> CGRect? {
        guard let bundleIdentifier = app.bundleIdentifier else { return nil }

        // Get the Dock application
        guard let dockApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            return nil
        }

        let dockElement = AXUIElementCreateApplication(dockApp.processIdentifier)

        // Navigate to the dock's list of items
        guard let children = try? dockElement.children(),
              let axList = children.first(where: { element in
                  (try? element.role()) == kAXListRole
              }),
              let dockItems = try? axList.children()
        else {
            return nil
        }

        // Find the dock item for this app
        for item in dockItems {
            guard let subrole = try? item.subrole(),
                  subrole == "AXApplicationDockItem"
            else { continue }

            // Check if this is our app by comparing bundle identifiers
            if let itemURL = try? item.attribute(kAXURLAttribute, NSURL.self)?.absoluteURL,
               let itemBundle = Bundle(url: itemURL),
               itemBundle.bundleIdentifier == bundleIdentifier
            {
                return getFrameForDockItem(item)
            }

            // Also check by running app
            if let itemTitle = try? item.title(),
               itemTitle == app.localizedName
            {
                return getFrameForDockItem(item)
            }
        }

        return nil
    }

    private func getFrameForDockItem(_ item: AXUIElement) -> CGRect? {
        guard let position = try? item.position(),
              let size = try? item.size()
        else { return nil }

        return CGRect(origin: position, size: size)
    }

    // MARK: - Positioning

    private func positionIndicator(relativeTo dockItemFrame: CGRect, dockPosition: DockPosition) {
        guard let indicatorWindow else { return }

        let indicatorThickness = Defaults[.activeAppIndicatorHeight]
        let indicatorOffset = Defaults[.activeAppIndicatorOffset]

        // Get the screen containing the dock
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(dockItemFrame.origin) }) ?? NSScreen.main else {
            return
        }

        // Calculate the indicator frame using the positioning module
        guard let indicatorFrame = ActiveAppIndicatorPositioning.calculateIndicatorFrame(
            for: dockItemFrame,
            dockPosition: dockPosition,
            indicatorThickness: indicatorThickness,
            indicatorOffset: indicatorOffset,
            on: screen
        ) else {
            indicatorWindow.orderOut(nil)
            return
        }

        indicatorWindow.setFrame(indicatorFrame, display: true)
    }
}

// MARK: - Indicator Window

/// A borderless window that displays the indicator line next to the active dock app.
final class ActiveAppIndicatorWindow: NSPanel {
    private var indicatorView: NSHostingView<ActiveAppIndicatorView>?

    init() {
        let styleMask: NSWindow.StyleMask = [.nonactivatingPanel, .fullSizeContentView, .borderless]
        super.init(contentRect: .zero, styleMask: styleMask, backing: .buffered, defer: false)
        setupWindow()
    }

    private func setupWindow() {
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces, .transient, .fullScreenAuxiliary, .ignoresCycle]
        hidesOnDeactivate = false
        ignoresMouseEvents = true
        animationBehavior = .none

        let view = ActiveAppIndicatorView()
        let hostingView = NSHostingView(rootView: view)
        contentView = hostingView
        indicatorView = hostingView
    }

    func updateAppearance() {
        indicatorView?.rootView = ActiveAppIndicatorView()
    }
}

// MARK: - Indicator View

/// The SwiftUI view that draws the indicator line.
/// The Capsule adapts to the window frame set by the positioning module:
/// - Horizontal (width > height) for bottom dock
/// - Vertical (height > width) for left/right dock
struct ActiveAppIndicatorView: View {
    @Default(.activeAppIndicatorColor) var indicatorColor

    var body: some View {
        Capsule()
            .fill(indicatorColor)
        // Frame is controlled by the window - Capsule fills it and adapts shape automatically
    }
}
