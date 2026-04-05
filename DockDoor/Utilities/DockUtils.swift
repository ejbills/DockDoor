import Cocoa
import Defaults

enum DockPosition {
    case top
    case bottom
    case left
    case right
    case cmdTab
    case cli
    case unknown

    var isHorizontalFlow: Bool {
        switch self {
        case .top, .bottom, .cmdTab, .cli:
            true
        case .left, .right:
            false
        case .unknown:
            true
        }
    }
}

class DockUtils {
    static func getDockPosition() -> DockPosition {
        var orientation: Int32 = 0
        var pinning: Int32 = 0
        CoreDockGetOrientationAndPinning(&orientation, &pinning)
        switch orientation {
        case 1: return .top
        case 2: return .bottom
        case 3: return .left
        case 4: return .right
        default: return .unknown
        }
    }

    /// Returns the dock size in pixels based on the screen's visible frame.
    static func getDockSize() -> CGFloat {
        guard let screen = NSScreen.main else { return 0 }
        let dockPosition = getDockPosition()
        switch dockPosition {
        case .right:
            return screen.frame.width - screen.visibleFrame.width
        case .left:
            return screen.visibleFrame.origin.x
        case .bottom:
            return screen.visibleFrame.origin.y
        case .top:
            return screen.frame.height - screen.visibleFrame.maxY
        case .cmdTab, .cli, .unknown:
            return 0
        }
    }
}

/// Central owner for native Dock auto-hide mutations.
///
/// Preview UI and the optional GNOME-style intellihide feature both flow through
/// this service so DockDoor only has one place that mutates the Dock's autohide
/// state. Intellihide is fully event-driven: workspace and AX observers trigger
/// reevaluations directly, and move/resize gestures use a one-shot settle delay
/// instead of a repeating polling loop.
final class DockAutoHideManager {
    static let shared = DockAutoHideManager()

    private let interactionSettleDelay: TimeInterval = 0.18
    private let titleBarHideDuration: TimeInterval = 1.1
    private let titleBarDetectionHeight: CGFloat = 80

    private var wasAutoHideEnabled: Bool?
    private var isManagingDock = false
    private var previewRequestsVisibleDock = false
    private var lastAppliedAutoHideState: Bool?

    private var defaultsObserver: Defaults.Observation?
    private var hasPendingRefresh = false
    private var scheduledEvaluation: DispatchWorkItem?
    private let geometry = DockIntellihideGeometry()
    private lazy var titleBarClickMonitor = DockTitleBarClickMonitor { [weak self] location in
        self?.handleTitleBarDoubleClick(at: location)
    }

    // MARK: - Lifecycle

    private init() {
        defaultsObserver = Defaults.observe(keys: .enableDockIntellihide) { [weak self] in
            DispatchQueue.main.async {
                self?.reconfigureIntellihide()
            }
        }
        reconfigureIntellihide()
    }

    deinit {
        defaultsObserver = nil
        cancelScheduledEvaluation()
        titleBarClickMonitor.stop()
        restoreManagedDockState(force: true)
    }

    // MARK: - Public API

    func preventDockHiding(_ windowSwitcherActive: Bool = false) {
        previewRequestsVisibleDock = Defaults[.preventDockHide] && !windowSwitcherActive
        if previewRequestsVisibleDock {
            cancelScheduledEvaluation()
        }
        refreshNow()
    }

    func restoreDockState() {
        previewRequestsVisibleDock = false
        refreshNow()
    }

    func refreshNow() {
        guard Defaults[.enableDockIntellihide] || previewRequestsVisibleDock || isManagingDock else { return }

        if Thread.isMainThread {
            applyCurrentPolicy()
            return
        }

        guard !hasPendingRefresh else { return }
        hasPendingRefresh = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            hasPendingRefresh = false
            applyCurrentPolicy()
        }
    }

    func cleanup() {
        previewRequestsVisibleDock = false
        cancelScheduledEvaluation()
        titleBarClickMonitor.stop()
        restoreManagedDockState(force: true)
    }

    func handleWorkspaceContextChange() {
        guard Defaults[.enableDockIntellihide] || isManagingDock else { return }
        cancelScheduledEvaluation()
        refreshNow()
    }

    func handleWindowObservation(notificationName: String, app: NSRunningApplication, element: AXUIElement) {
        guard Defaults[.enableDockIntellihide] || isManagingDock else { return }

        if Thread.isMainThread {
            handleWindowObservationOnMain(notificationName: notificationName, app: app, element: element)
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.handleWindowObservationOnMain(notificationName: notificationName, app: app, element: element)
        }
    }

    // MARK: - Configuration

    private func reconfigureIntellihide() {
        if Defaults[.enableDockIntellihide] {
            titleBarClickMonitor.start()
        } else {
            cancelScheduledEvaluation()
            titleBarClickMonitor.stop()
        }

        refreshNow()
    }

    private func applyCurrentPolicy() {
        if previewRequestsVisibleDock {
            applyAutoHide(false)
            return
        }

        guard Defaults[.enableDockIntellihide] else {
            restoreManagedDockState()
            return
        }

        evaluateDockVisibility()
    }

    // MARK: - Dock State Management

    private func captureOriginalDockStateIfNeeded() {
        if !isManagingDock {
            wasAutoHideEnabled = CoreDockGetAutoHideEnabled()
            isManagingDock = true
        }
    }

    private func restoreManagedDockState(force: Bool = false) {
        guard force || !previewRequestsVisibleDock, isManagingDock, let wasAutoHideEnabled else { return }
        CoreDockSetAutoHideEnabled(wasAutoHideEnabled)
        self.wasAutoHideEnabled = nil
        isManagingDock = false
        lastAppliedAutoHideState = nil
    }

    // MARK: - Intellihide Policy

    private func evaluateDockVisibility() {
        guard let frontmostApp = eligibleFrontmostApp() else {
            applyAutoHide(false)
            return
        }

        guard let sample = geometry.sample(for: frontmostApp) else {
            if WindowUtil.isAppInFullscreen(frontmostApp) {
                applyAutoHide(true)
                return
            }
            applyAutoHide(false)
            return
        }

        if sample.isFullscreen {
            applyAutoHide(true)
            return
        }

        guard let windowScreen = geometry.screen(for: sample.frame),
              let dockContext = geometry.dockContext(preferCached: shouldPreferCachedDockContext())
        else {
            applyAutoHide(false)
            return
        }

        guard windowScreen.uniqueIdentifier() == dockContext.screen.uniqueIdentifier() else {
            applyAutoHide(false)
            return
        }

        let shouldHide = if lastAppliedAutoHideState == true {
            sample.frame.intersects(dockContext.releaseRegion)
        } else {
            sample.frame.intersects(dockContext.dockRegion)
        }

        applyAutoHide(shouldHide)
    }

    private func eligibleFrontmostApp() -> NSRunningApplication? {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
              frontmostApp.activationPolicy == .regular,
              frontmostApp.bundleIdentifier != Bundle.main.bundleIdentifier,
              frontmostApp.bundleIdentifier != DockAccessibility.dockBundleIdentifier
        else {
            return nil
        }

        return frontmostApp
    }

    private func shouldPreferCachedDockContext() -> Bool {
        lastAppliedAutoHideState == true
    }

    private func handleWindowObservationOnMain(notificationName: String, app: NSRunningApplication, element: AXUIElement) {
        if previewRequestsVisibleDock {
            refreshNow()
            return
        }

        switch notificationName {
        case kAXWindowMovedNotification, kAXWindowResizedNotification:
            handleInteractiveWindowFrameChange(for: app, window: element)
        case kAXFocusedWindowChangedNotification,
             kAXMainWindowChangedNotification,
             kAXWindowMiniaturizedNotification,
             kAXWindowDeminiaturizedNotification,
             kAXApplicationHiddenNotification,
             kAXApplicationShownNotification,
             kAXUIElementDestroyedNotification:
            handleWorkspaceContextChange()
        default:
            break
        }
    }

    private func handleInteractiveWindowFrameChange(for app: NSRunningApplication, window: AXUIElement) {
        guard Defaults[.enableDockIntellihide],
              let frontmostApp = eligibleFrontmostApp(),
              frontmostApp.processIdentifier == app.processIdentifier
        else {
            return
        }

        guard let sample = geometry.sample(for: app, preferredWindow: window) else {
            refreshNow()
            return
        }

        if sample.isFullscreen {
            cancelScheduledEvaluation()
            applyAutoHide(true)
            return
        }

        guard let windowScreen = geometry.screen(for: sample.frame),
              let dockContext = geometry.dockContext(preferCached: true)
        else {
            refreshNow()
            return
        }

        guard windowScreen.uniqueIdentifier() == dockContext.screen.uniqueIdentifier() else {
            cancelScheduledEvaluation()
            applyAutoHide(false)
            return
        }

        // While a window is actively moving or resizing on the Dock-bearing
        // display, keep the Dock hidden and re-evaluate once the stream of
        // AX notifications settles.
        applyAutoHide(true)
        scheduleEvaluation(after: interactionSettleDelay)
    }

    private func handleTitleBarDoubleClick(at location: CGPoint) {
        guard Defaults[.enableDockIntellihide],
              let frontmostApp = eligibleFrontmostApp(),
              let sample = geometry.sample(for: frontmostApp)
        else {
            return
        }

        if geometry.titleBarRegion(for: sample.frame, detectionHeight: titleBarDetectionHeight).contains(location) {
            scheduleEvaluation(after: titleBarHideDuration)
            applyAutoHide(true)
        }
    }

    private func scheduleEvaluation(after delay: TimeInterval) {
        cancelScheduledEvaluation()

        let workItem = DispatchWorkItem { [weak self] in
            self?.scheduledEvaluation = nil
            self?.refreshNow()
        }

        scheduledEvaluation = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func cancelScheduledEvaluation() {
        scheduledEvaluation?.cancel()
        scheduledEvaluation = nil
    }

    // MARK: - Applying Dock State

    private func applyAutoHide(_ enabled: Bool, force: Bool = false) {
        let currentState = CoreDockGetAutoHideEnabled()

        if !force, currentState == enabled, !isManagingDock {
            lastAppliedAutoHideState = enabled
            return
        }

        if !force, lastAppliedAutoHideState == enabled {
            return
        }

        captureOriginalDockStateIfNeeded()

        if force || currentState != enabled {
            CoreDockSetAutoHideEnabled(enabled)
        }

        lastAppliedAutoHideState = enabled
    }
}
