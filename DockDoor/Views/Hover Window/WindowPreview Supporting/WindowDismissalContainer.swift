import Defaults
import SwiftUI

struct WindowDismissalContainer: NSViewRepresentable {
    let appName: String
    let bestGuessMonitor: NSScreen
    let dockPosition: DockPosition
    let minimizeAllWindowsCallback: () -> Void

    func makeNSView(context: Context) -> MouseTrackingNSView {
        let view = MouseTrackingNSView(appName: appName,
                                       bestGuessMonitor: bestGuessMonitor,
                                       dockPosition: dockPosition,
                                       minimizeAllWindowsCallback: minimizeAllWindowsCallback)
        view.resetOpacity()
        return view
    }

    func updateNSView(_ nsView: MouseTrackingNSView, context: Context) {
        nsView.resetOpacity()
    }
}

class MouseTrackingNSView: NSView {
    private let appName: String
    private let bestGuessMonitor: NSScreen
    private let dockPosition: DockPosition
    private let minimizeAllWindowsCallback: () -> Void
    private var fadeOutTimer: Timer?
    private let fadeOutDuration: TimeInterval
    private var inactivityCheckTimer: Timer?
    private let inactivityCheckInterval: TimeInterval

    private var eventMonitor: Any?

    init(appName: String, bestGuessMonitor: NSScreen, dockPosition: DockPosition, minimizeAllWindowsCallback: @escaping () -> Void, frame frameRect: NSRect = .zero) {
        self.appName = appName
        self.bestGuessMonitor = bestGuessMonitor
        self.dockPosition = dockPosition
        self.minimizeAllWindowsCallback = minimizeAllWindowsCallback
        fadeOutDuration = Defaults[.fadeOutDuration]
        inactivityCheckInterval = TimeInterval(Defaults[.inactivityTimeout])
        super.init(frame: frameRect)
        setupTrackingArea()
        setupGlobalClickMonitor()
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
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
    }

    private func clearTimers() {
        fadeOutTimer?.invalidate()
        fadeOutTimer = nil
        inactivityCheckTimer?.invalidate()
        inactivityCheckTimer = nil
    }

    private func startInactivityMonitoring() {
        inactivityCheckTimer?.invalidate() // Invalidate existing timer if any
        inactivityCheckTimer = Timer.scheduledTimer(withTimeInterval: inactivityCheckInterval, repeats: true) { [weak self] _ in
            guard let self, let window else { return }

            let currentMouseLocation = NSEvent.mouseLocation // Screen coordinates
            let windowFrame = window.frame // Screen coordinates

            let isMouseOverDockIcon = checkIfMouseIsOverDockIcon()

            if windowFrame.contains(currentMouseLocation) || isMouseOverDockIcon {
                // Mouse is inside the window or over the app's dock icon
                resetOpacityVisually()
            } else {
                // Mouse is outside the window and not over the app's dock icon
                // Start fade-out only if window is fully opaque and not already fading
                if fadeOutTimer == nil, window.alphaValue == 1.0 {
                    startFadeOut()
                }
            }
        }
    }

    private func checkIfMouseIsOverDockIcon() -> Bool {
        let currentAppReturnType = DockObserver.shared.getDockItemAppStatusUnderMouse()
        if case let .success(currApp) = currentAppReturnType.status, currApp.localizedName == self.appName {
            return true
        }
        return false
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
            guard !SharedPreviewWindowCoordinator.shared.windowSwitcherCoordinator.windowSwitcherActive else { return }

            // Ensure we don't start a new fade if one is already in progress or completed
            // This check is now partly handled by the caller (inactivityCheckTimer)
            // but an additional check here for `window.alphaValue > 0` can prevent hiding an already hidden window.
            guard let window, window.alphaValue > 0 else { return }

            cancelFadeOut() // Cancel any previously scheduled fade-out that hasn't completed

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
            // If already at target alpha, no need to animate
            if window.alphaValue == value { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = duration
                window.animator().alphaValue = value
            }
        }
    }

    private func performHideWindow() {
        DispatchQueue.main.async { [weak self] in
            guard self != nil else { return }
            SharedPreviewWindowCoordinator.shared.hideWindow()
            DockObserver.shared.lastAppUnderMouse = nil
        }
    }

    private func setupGlobalClickMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            guard let self else { return }

            let currentAppReturnType = DockObserver.shared.getDockItemAppStatusUnderMouse()

            switch currentAppReturnType.status {
            case let .success(currApp):
                if currApp.localizedName == appName { // Clicked on OUR app's dock icon
                    if Defaults[.shouldHideOnDockItemClick] {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                            self?.minimizeAllWindowsCallback()
                        }
                    } else {
                        // If not hiding on dock item click, we might want to just hide the preview window
                        performHideWindow()
                    }
                } else { // Clicked on a DIFFERENT app's dock icon or somewhere else not on our window
                    handleExternalClick(event: event)
                }
            default: // Error getting dock item, or not on any dock item
                handleExternalClick(event: event)
            }
        }
    }

    private func handleExternalClick(event: NSEvent) {
        guard let window else { return }
        let clickScreenLocation = NSEvent.mouseLocation
        let windowFrame = window.frame

        // If the click is outside our window and not on our dock icon (already handled), fade out.
        if !windowFrame.contains(clickScreenLocation) {
            DispatchQueue.main.async {
                self.startFadeOut()
            }
        }
    }
}
