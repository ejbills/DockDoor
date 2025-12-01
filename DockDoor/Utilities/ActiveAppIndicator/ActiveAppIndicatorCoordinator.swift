import Cocoa
import Defaults
import SwiftUI

/// Manages the active app indicator that shows a line below the currently active app in the dock.
/// This feature only supports bottom dock position.
final class ActiveAppIndicatorCoordinator {
    static var shared: ActiveAppIndicatorCoordinator?

    private var indicatorWindow: ActiveAppIndicatorWindow?
    private var workspaceObserver: NSObjectProtocol?
    private var settingsObserver: Defaults.Observation?
    private var colorObserver: Defaults.Observation?
    private var heightObserver: Defaults.Observation?
    private var offsetObserver: Defaults.Observation?

    private var currentActiveApp: NSRunningApplication?

    // Dock auto-hide visibility tracking
    private var mouseMonitor: Any?
    private var isDockCurrentlyVisible: Bool = true
    private var dockHideDebounceTimer: Timer?
    private var dockShowDebounceTimer: Timer?

    init() {
        ActiveAppIndicatorCoordinator.shared = self
        setupObservers()
        setupDockVisibilityTracking()
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

    private func setupDockVisibilityTracking() {
        // Monitor mouse movements globally to detect when dock should show/hide
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] event in
            self?.handleMouseMoved(event)
        }

        // Also monitor local events when DockDoor windows are active
        NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] event in
            self?.handleMouseMoved(event)
            return event
        }
    }

    private func cleanup() {
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
        dockHideDebounceTimer?.invalidate()
        dockShowDebounceTimer?.invalidate()
        settingsObserver?.invalidate()
        colorObserver?.invalidate()
        heightObserver?.invalidate()
        offsetObserver?.invalidate()
        hideIndicator()
    }

    // MARK: - Dock Visibility Tracking

    private func handleMouseMoved(_ event: NSEvent) {
        // Only track if auto-hide is enabled
        guard CoreDockGetAutoHideEnabled() else {
            dockShowDebounceTimer?.invalidate()
            dockShowDebounceTimer = nil
            if !isDockCurrentlyVisible {
                isDockCurrentlyVisible = true
                fadeInIndicator()
            }
            return
        }

        guard let screen = NSScreen.main else { return }

        // Get mouse position in screen coordinates (Y from bottom)
        let mouseLocation = NSEvent.mouseLocation
        let dockTriggerZone = Defaults[.activeAppIndicatorDockTriggerZone]

        // Check if mouse is in the dock trigger zone (bottom of screen for bottom dock)
        let isInDockZone = mouseLocation.y <= dockTriggerZone &&
            mouseLocation.x >= screen.frame.minX &&
            mouseLocation.x <= screen.frame.maxX

        if isInDockZone {
            // Mouse is near dock area - dock should be visible
            dockHideDebounceTimer?.invalidate()
            dockHideDebounceTimer = nil

            if !isDockCurrentlyVisible, dockShowDebounceTimer == nil {
                let fadeInDelay = Defaults[.activeAppIndicatorFadeInDelay]
                // Start delay timer before showing indicator
                dockShowDebounceTimer = Timer.scheduledTimer(withTimeInterval: fadeInDelay, repeats: false) { [weak self] _ in
                    self?.isDockCurrentlyVisible = true
                    self?.fadeInIndicator()
                    self?.dockShowDebounceTimer = nil
                }
            }
        } else {
            // Mouse moved away from dock area - cancel show timer and start hide timer
            dockShowDebounceTimer?.invalidate()
            dockShowDebounceTimer = nil

            if isDockCurrentlyVisible, dockHideDebounceTimer == nil {
                let fadeOutDelay = Defaults[.activeAppIndicatorFadeOutDelay]
                dockHideDebounceTimer = Timer.scheduledTimer(withTimeInterval: fadeOutDelay, repeats: false) { [weak self] _ in
                    self?.isDockCurrentlyVisible = false
                    self?.fadeOutIndicator()
                    self?.dockHideDebounceTimer = nil
                }
            }
        }
    }

    private func fadeInIndicator() {
        guard let indicatorWindow, Defaults[.showActiveAppIndicator] else { return }

        let fadeInDuration = Defaults[.activeAppIndicatorFadeInDuration]
        NSAnimationContext.runAnimationGroup { context in
            context.duration = fadeInDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            indicatorWindow.animator().alphaValue = 1.0
        }
    }

    private func fadeOutIndicator() {
        guard let indicatorWindow else { return }

        let fadeOutDuration = Defaults[.activeAppIndicatorFadeOutDuration]
        NSAnimationContext.runAnimationGroup { context in
            context.duration = fadeOutDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            indicatorWindow.animator().alphaValue = 0.0
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
                // If auto-hide is enabled, check if mouse is currently in dock zone
                let mouseLocation = NSEvent.mouseLocation
                let dockTriggerZone = Defaults[.activeAppIndicatorDockTriggerZone]
                let isInDockZone = mouseLocation.y <= dockTriggerZone
                isDockCurrentlyVisible = isInDockZone
                indicatorWindow?.alphaValue = isInDockZone ? 1.0 : 0.0
            } else {
                isDockCurrentlyVisible = true
                indicatorWindow?.alphaValue = 1.0
            }
        }
    }

    private func hideIndicator() {
        dockHideDebounceTimer?.invalidate()
        dockHideDebounceTimer = nil
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

        // Only support bottom dock position
        let dockPosition = DockUtils.getDockPosition()
        guard dockPosition == .bottom else {
            indicatorWindow.orderOut(nil)
            return
        }

        positionIndicator(below: dockItemFrame)
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

    private func positionIndicator(below dockItemFrame: CGRect) {
        guard let indicatorWindow else { return }

        let indicatorHeight = Defaults[.activeAppIndicatorHeight]
        let indicatorOffset = Defaults[.activeAppIndicatorOffset]
        let indicatorWidth = dockItemFrame.width * 0.6 // Make indicator slightly narrower than dock icon

        // Position indicator centered below the dock icon
        // Note: In screen coordinates, Y increases downward from top-left
        let x = dockItemFrame.midX - (indicatorWidth / 2)

        // Get the screen containing the dock
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(dockItemFrame.origin) }) ?? NSScreen.main else {
            return
        }

        // Convert from screen coordinates (Y from top) to AppKit coordinates (Y from bottom)
        let screenHeight = screen.frame.height
        let dockItemBottomInScreenCoords = dockItemFrame.origin.y + dockItemFrame.height

        // The indicator should be just below the dock icon
        // In AppKit coordinates, we need to flip Y
        // Positive offset moves indicator up (adds to Y in AppKit coords), negative moves down
        let y = screenHeight - dockItemBottomInScreenCoords - indicatorHeight - 2 + indicatorOffset // 2px base gap

        let indicatorFrame = CGRect(x: x, y: y, width: indicatorWidth, height: indicatorHeight)
        indicatorWindow.setFrame(indicatorFrame, display: true)
    }
}

// MARK: - Indicator Window

/// A borderless window that displays the indicator line below the active dock app.
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
struct ActiveAppIndicatorView: View {
    @Default(.activeAppIndicatorColor) var indicatorColor
    @Default(.activeAppIndicatorHeight) var indicatorHeight

    var body: some View {
        Capsule()
            .fill(indicatorColor)
            .frame(height: indicatorHeight)
    }
}
