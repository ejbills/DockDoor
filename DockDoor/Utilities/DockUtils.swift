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

final class DockAutoHideManager {
    static let shared = DockAutoHideManager()

    private let pollInterval: TimeInterval = 0.15
    private let transitionHideDuration: TimeInterval = 0.75
    private let titleBarHideDuration: TimeInterval = 1.1
    private let minimumFrameDeltaToDetectTransition: CGFloat = 2
    private let titleBarDetectionHeight: CGFloat = 80

    private var wasAutoHideEnabled: Bool?
    private var isManagingDock = false
    private var previewRequestsVisibleDock = false
    private var lastAppliedAutoHideState: Bool?

    private var defaultsObserver: Defaults.Observation?
    private var evaluationTimer: Timer?
    private var hasPendingRefresh = false
    private let geometry = DockIntellihideGeometry()
    private lazy var titleBarClickMonitor = DockTitleBarClickMonitor { [weak self] location in
        self?.handleTitleBarDoubleClick(at: location)
    }

    private var lastSample: DockIntellihideWindowSample?
    private var forceHideUntil: Date?

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
        stopEvaluating()
        titleBarClickMonitor.stop()
        restoreManagedDockState(force: true)
    }

    func preventDockHiding(_ windowSwitcherActive: Bool = false) {
        previewRequestsVisibleDock = Defaults[.preventDockHide] && !windowSwitcherActive
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
        stopEvaluating()
        titleBarClickMonitor.stop()
        lastSample = nil
        forceHideUntil = nil
        restoreManagedDockState(force: true)
    }

    private func reconfigureIntellihide() {
        if Defaults[.enableDockIntellihide] {
            startEvaluating()
            titleBarClickMonitor.start()
        } else {
            stopEvaluating()
            titleBarClickMonitor.stop()
            lastSample = nil
            forceHideUntil = nil
        }

        refreshNow()
    }

    private func startEvaluating() {
        guard evaluationTimer == nil else { return }

        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.applyCurrentPolicy()
        }
        evaluationTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopEvaluating() {
        evaluationTimer?.invalidate()
        evaluationTimer = nil
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

    private func evaluateDockVisibility() {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
              frontmostApp.activationPolicy == .regular,
              frontmostApp.bundleIdentifier != Bundle.main.bundleIdentifier,
              frontmostApp.bundleIdentifier != "com.apple.dock"
        else {
            lastSample = nil
            forceHideUntil = nil
            applyAutoHide(false)
            return
        }

        guard let sample = geometry.sample(for: frontmostApp) else {
            if WindowUtil.isAppInFullscreen(frontmostApp) {
                applyAutoHide(true)
                return
            }
            lastSample = nil
            forceHideUntil = nil
            applyAutoHide(false)
            return
        }

        if sample.isFullscreen {
            applyAutoHide(true)
            return
        }

        guard let windowScreen = geometry.screen(for: sample.frame),
              let dockContext = geometry.dockContext(preferCached: lastAppliedAutoHideState == true || forceHideUntil != nil)
        else {
            applyAutoHide(false)
            return
        }

        guard windowScreen.uniqueIdentifier() == dockContext.screen.uniqueIdentifier() else {
            forceHideUntil = nil
            applyAutoHide(false)
            return
        }

        if geometry.shouldForceHideTransition(
            from: lastSample,
            to: sample,
            dockInfluenceRegion: dockContext.releaseRegion,
            minimumFrameDeltaToDetectTransition: minimumFrameDeltaToDetectTransition
        ) {
            forceHideUntil = Date().addingTimeInterval(transitionHideDuration)
        }

        lastSample = sample

        if let forceHideUntil, forceHideUntil > Date() {
            applyAutoHide(true)
            return
        }
        forceHideUntil = nil

        let shouldHide = if lastAppliedAutoHideState == true {
            sample.frame.intersects(dockContext.releaseRegion)
        } else {
            sample.frame.intersects(dockContext.dockRegion)
        }

        applyAutoHide(shouldHide)
    }

    private func handleTitleBarDoubleClick(at location: CGPoint) {
        guard Defaults[.enableDockIntellihide],
              let frontmostApp = NSWorkspace.shared.frontmostApplication,
              frontmostApp.activationPolicy == .regular,
              frontmostApp.bundleIdentifier != Bundle.main.bundleIdentifier,
              let sample = geometry.sample(for: frontmostApp)
        else {
            return
        }

        if geometry.titleBarRegion(for: sample.frame, detectionHeight: titleBarDetectionHeight).contains(location) {
            forceHideUntil = Date().addingTimeInterval(titleBarHideDuration)
            applyAutoHide(true)
        }
    }

    private func applyAutoHide(_ enabled: Bool, force: Bool = false) {
        captureOriginalDockStateIfNeeded()

        if !force, lastAppliedAutoHideState == enabled {
            return
        }

        let currentState = CoreDockGetAutoHideEnabled()
        if force || currentState != enabled {
            CoreDockSetAutoHideEnabled(enabled)
        }

        lastAppliedAutoHideState = enabled
    }
}
