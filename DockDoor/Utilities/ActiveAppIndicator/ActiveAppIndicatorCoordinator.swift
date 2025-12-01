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

    init() {
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

    private func cleanup() {
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        settingsObserver?.invalidate()
        colorObserver?.invalidate()
        heightObserver?.invalidate()
        offsetObserver?.invalidate()
        hideIndicator()
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
