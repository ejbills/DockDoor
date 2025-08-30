import Defaults
import SwiftUI

struct WindowDismissalContainer: NSViewRepresentable {
    let appName: String
    let bestGuessMonitor: NSScreen
    let dockPosition: DockPosition
    let minimizeAllWindowsCallback: (_ wasAppActiveBeforeClick: Bool) -> Void

    func makeNSView(context: Context) -> MouseTrackingNSView {
        let view = MouseTrackingNSView(appName: appName,
                                       bestGuessMonitor: bestGuessMonitor,
                                       dockPosition: dockPosition,
                                       minimizeAllWindowsCallback: minimizeAllWindowsCallback)
        view.resetOpacity()
        return view
    }

    func updateNSView(_ nsView: MouseTrackingNSView, context: Context) {}
}

class MouseTrackingNSView: NSView {
    private let appName: String
    private let bestGuessMonitor: NSScreen
    private let dockPosition: DockPosition
    private let minimizeAllWindowsCallback: (_ wasAppActiveBeforeClick: Bool) -> Void
    private var fadeOutTimer: Timer?
    private let fadeOutDuration: TimeInterval
    private var inactivityCheckTimer: Timer?
    private let inactivityCheckInterval: TimeInterval

    init(appName: String, bestGuessMonitor: NSScreen, dockPosition: DockPosition, minimizeAllWindowsCallback: @escaping (_ wasAppActiveBeforeClick: Bool) -> Void, frame frameRect: NSRect = .zero) {
        self.appName = appName
        self.bestGuessMonitor = bestGuessMonitor
        self.dockPosition = dockPosition
        self.minimizeAllWindowsCallback = minimizeAllWindowsCallback
        fadeOutDuration = Defaults[.fadeOutDuration]
        inactivityCheckInterval = TimeInterval(Defaults[.inactivityTimeout])
        super.init(frame: frameRect)
        setupTrackingArea()
        startInactivityMonitoring()
        resetOpacityVisually()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupTrackingArea() {
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways, .inVisibleRect]
        let trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }

    deinit {
        clearTimers()
    }

    private func clearTimers() {
        fadeOutTimer?.invalidate()
        fadeOutTimer = nil
        inactivityCheckTimer?.invalidate()
        inactivityCheckTimer = nil
    }

    private func startInactivityMonitoring() {
        inactivityCheckTimer?.invalidate()
        inactivityCheckTimer = Timer.scheduledTimer(withTimeInterval: inactivityCheckInterval, repeats: true) { [weak self] _ in
            guard let self, let window else { return }

            let currentMouseLocation = NSEvent.mouseLocation
            let windowFrame = window.frame

            let isMouseOverDockIcon = checkIfMouseIsOverDockIcon()

            if windowFrame.contains(currentMouseLocation) || isMouseOverDockIcon {
                resetOpacityVisually()
            } else {
                if fadeOutTimer == nil, window.alphaValue == 1.0 {
                    startFadeOut()
                }
            }
        }
    }

    private func checkIfMouseIsOverDockIcon() -> Bool {
        guard let activeDockObserver = DockObserver.activeInstance else { return false }
        // If DockObserver requests inactivity-based dismissal (e.g., hovered an empty app with lateral movement off),
        // treat the dock icon as not hovered so the inactivity timer can dismiss the window.
        if activeDockObserver.requireInactivityDismissal { return false }
        let currentAppReturnType = activeDockObserver.getDockItemAppStatusUnderMouse()
        return currentAppReturnType.status != .notFound
    }

    func resetOpacity() {
        resetOpacityVisually()
    }

    private func resetOpacityVisually() {
        cancelFadeOut()
        setWindowOpacity(to: 1.0, duration: 0.2)
    }

    override func mouseEntered(with event: NSEvent) {
        resetOpacityVisually()
    }

    private func startFadeOut() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard SharedPreviewWindowCoordinator.activeInstance?.windowSwitcherCoordinator.windowSwitcherActive == false else { return }

            guard let window, window.alphaValue > 0 else { return }

            cancelFadeOut()

            if fadeOutDuration == 0 {
                performHideWindow()
            } else {
                setWindowOpacity(to: 0.0, duration: fadeOutDuration)
                fadeOutTimer = Timer.scheduledTimer(withTimeInterval: fadeOutDuration, repeats: false) { [weak self] _ in
                    self?.performHideWindow()
                }
            }
        }
    }

    func cancelFadeOut() {
        fadeOutTimer?.invalidate()
        fadeOutTimer = nil
    }

    private func setWindowOpacity(to value: CGFloat, duration: TimeInterval) {
        DispatchQueue.main.async { [weak self] in
            guard let window = self?.window else { return }
            if window.alphaValue == value { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = duration
                window.animator().alphaValue = value
            }
        }
    }

    private func performHideWindow(preventLastAppClear: Bool = false) {
        DispatchQueue.main.async { [weak self] in
            guard self != nil else { return }
            SharedPreviewWindowCoordinator.activeInstance?.hideWindow()
            if !preventLastAppClear { DockObserver.activeInstance?.lastAppUnderMouse = nil }
            DockObserver.activeInstance?.resetTrackingAfterContainerDismissal()
        }
    }
}
