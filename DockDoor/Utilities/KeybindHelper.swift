import AppKit
import Carbon
import Carbon.HIToolbox.Events
import Defaults

private class KeybindHelperUserInfo {
    let instance: KeybindHelper
    init(instance: KeybindHelper) {
        self.instance = instance
    }
}

struct UserKeyBind: Codable, Defaults.Serializable {
    var keyCode: UInt16
    var modifierFlags: Int
}

private class WindowSwitchingCoordinator {
    private var isProcessingSwitcher = false
    private let stateManager = WindowSwitcherStateManager()
    private var uiRenderingTask: Task<Void, Never>?
    private var currentSessionId = UUID()

    @MainActor
    func handleWindowSwitching(
        previewCoordinator: SharedPreviewWindowCoordinator,
        isModifierPressed: Bool,
        isShiftPressed: Bool
    ) async {
        guard !isProcessingSwitcher else { return }
        isProcessingSwitcher = true
        defer { isProcessingSwitcher = false }

        if stateManager.isActive {
            if isShiftPressed {
                stateManager.cycleBackward()
            } else {
                stateManager.cycleForward()
            }
            previewCoordinator.windowSwitcherCoordinator.setIndex(to: stateManager.currentIndex)
        } else if isModifierPressed {
            await initializeWindowSwitching(
                previewCoordinator: previewCoordinator
            )
        }
    }

    @MainActor
    private func initializeWindowSwitching(
        previewCoordinator: SharedPreviewWindowCoordinator
    ) async {
        let windows = WindowUtil.getAllWindowsOfAllApps()
        guard !windows.isEmpty else { return }

        currentSessionId = UUID()
        let sessionId = currentSessionId

        stateManager.initializeWithWindows(windows)

        let currentMouseLocation = DockObserver.getMousePosition()
        let targetScreen = getTargetScreenForSwitcher()

        uiRenderingTask?.cancel()
        uiRenderingTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000)
            await renderWindowSwitcherUI(
                previewCoordinator: previewCoordinator,
                windows: windows,
                currentMouseLocation: currentMouseLocation,
                targetScreen: targetScreen,
                initialIndex: stateManager.currentIndex,
                sessionId: sessionId
            )
        }

        Task.detached(priority: .low) {
            await WindowUtil.updateAllWindowsInCurrentSpace()
        }
    }

    @MainActor
    private func renderWindowSwitcherUI(
        previewCoordinator: SharedPreviewWindowCoordinator,
        windows: [WindowInfo],
        currentMouseLocation: CGPoint,
        targetScreen: NSScreen,
        initialIndex: Int,
        sessionId: UUID
    ) async {
        guard sessionId == currentSessionId else { return }
        guard stateManager.isActive else { return }

        if previewCoordinator.isVisible, previewCoordinator.windowSwitcherCoordinator.windowSwitcherActive {
            previewCoordinator.windowSwitcherCoordinator.setIndex(to: stateManager.currentIndex)
            return
        }
        let showWindowLambda = { (mouseLocation: NSPoint?, mouseScreen: NSScreen?) in
            previewCoordinator.showWindow(
                appName: "Window Switcher",
                windows: windows,
                mouseLocation: mouseLocation,
                mouseScreen: mouseScreen,
                dockItemElement: nil,
                overrideDelay: true,
                centeredHoverWindowState: .windowSwitcher,
                onWindowTap: {
                    Task { @MainActor in
                        previewCoordinator.hideWindow()
                    }
                }
            )

            // Set the correct index after the window is shown, with a small delay to ensure setWindows completes
            DispatchQueue.main.async {
                previewCoordinator.windowSwitcherCoordinator.setIndex(to: self.stateManager.currentIndex)
            }
        }

        switch Defaults[.windowSwitcherPlacementStrategy] {
        case .pinnedToScreen:
            let screenCenter = NSPoint(x: targetScreen.frame.midX, y: targetScreen.frame.midY)
            showWindowLambda(screenCenter, targetScreen)
        case .screenWithLastActiveWindow:
            showWindowLambda(nil, nil)
        case .screenWithMouse:
            let mouseScreen = NSScreen.screenContainingMouse(currentMouseLocation)
            let convertedMouseLocation = DockObserver.nsPointFromCGPoint(currentMouseLocation, forScreen: mouseScreen)
            showWindowLambda(convertedMouseLocation, mouseScreen)
        }
    }

    private func getTargetScreenForSwitcher() -> NSScreen {
        if Defaults[.windowSwitcherPlacementStrategy] == .pinnedToScreen,
           let pinnedScreen = NSScreen.findScreen(byIdentifier: Defaults[.pinnedScreenIdentifier])
        {
            return pinnedScreen
        }
        let mouseLocation = DockObserver.getMousePosition()
        return NSScreen.screenContainingMouse(mouseLocation)
    }

    func selectCurrentWindow() -> WindowInfo? {
        guard stateManager.isActive else { return nil }

        let selectedWindow = stateManager.getCurrentWindow()
        currentSessionId = UUID()
        stateManager.reset()
        uiRenderingTask?.cancel()
        return selectedWindow
    }

    func isStateManagerActive() -> Bool {
        stateManager.isActive
    }

    func cancelSwitching() {
        currentSessionId = UUID()
        stateManager.reset()
        uiRenderingTask?.cancel()
    }
}

class KeybindHelper {
    private let previewCoordinator: SharedPreviewWindowCoordinator
    private let dockObserver: DockObserver
    private let windowSwitchingCoordinator = WindowSwitchingCoordinator()

    private var isSwitcherModifierKeyPressed: Bool = false
    private var isShiftKeyPressedGeneral: Bool = false
    private var hasProcessedModifierRelease: Bool = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var monitorTimer: Timer?
    private var unmanagedEventTapUserInfo: Unmanaged<KeybindHelperUserInfo>?

    init(previewCoordinator: SharedPreviewWindowCoordinator, dockObserver: DockObserver) {
        self.previewCoordinator = previewCoordinator
        self.dockObserver = dockObserver
        setupEventTap()
        startMonitoring()
    }

    func reset() {
        cleanup()
        resetState()
        setupEventTap()
        startMonitoring()
    }

    private func cleanup() {
        monitorTimer?.invalidate()
        monitorTimer = nil
        removeEventTap()
    }

    private func resetState() {
        isSwitcherModifierKeyPressed = false
        isShiftKeyPressedGeneral = false
    }

    private func startMonitoring() {
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.checkEventTapStatus()
        }
    }

    private func checkEventTapStatus() {
        guard let eventTap, CGEvent.tapIsEnabled(tap: eventTap) else {
            reset()
            return
        }
    }

    private static let eventCallback: CGEventTapCallBack = { proxy, type, event, refcon in
        guard let refcon else { return Unmanaged.passUnretained(event) }
        return Unmanaged<KeybindHelperUserInfo>.fromOpaque(refcon).takeUnretainedValue().instance.handleEvent(proxy: proxy, type: type, event: event)
    }

    private func setupEventTap() {
        let eventMask = (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)

        let userInfo = KeybindHelperUserInfo(instance: self)
        unmanagedEventTapUserInfo = Unmanaged.passRetained(userInfo)

        guard let newEventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: KeybindHelper.eventCallback,
            userInfo: unmanagedEventTapUserInfo?.toOpaque()
        ) else {
            unmanagedEventTapUserInfo?.release()
            unmanagedEventTapUserInfo = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                print("Retrying KeybindHelper event tap setup...")
                self?.setupEventTap()
            }
            return
        }

        eventTap = newEventTap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newEventTap, 0)

        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: newEventTap, enable: true)
        }
    }

    private func removeEventTap() {
        if let eventTap, let runLoopSource {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            unmanagedEventTapUserInfo?.release()
            unmanagedEventTapUserInfo = nil
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .flagsChanged:
            let keyBoardShortcutSaved: UserKeyBind = Defaults[.UserKeybind]
            let (currentSwitcherModifierIsPressed, currentShiftState) = updateModifierStatesFromFlags(event: event, keyBoardShortcutSaved: keyBoardShortcutSaved)

            Task { @MainActor [weak self] in
                self?.handleModifierEvent(currentSwitcherModifierIsPressed: currentSwitcherModifierIsPressed, currentShiftState: currentShiftState)
            }

        case .keyDown:
            let (shouldConsume, actionTask) = determineActionForKeyDown(event: event)
            if let task = actionTask {
                Task { @MainActor in
                    await task()
                }
            }
            if shouldConsume { return nil }

        default:
            break
        }
        return Unmanaged.passUnretained(event)
    }

    private func updateModifierStatesFromFlags(event: CGEvent, keyBoardShortcutSaved: UserKeyBind) -> (currentSwitcherModifierIsPressed: Bool, currentShiftState: Bool) {
        let currentSwitcherModifierIsPressed = event.flags.rawValue & UInt64(keyBoardShortcutSaved.modifierFlags) == UInt64(keyBoardShortcutSaved.modifierFlags) && keyBoardShortcutSaved.modifierFlags != 0
        let currentShiftState = event.flags.contains(.maskShift)

        return (currentSwitcherModifierIsPressed, currentShiftState)
    }

    @MainActor
    private func handleModifierEvent(currentSwitcherModifierIsPressed: Bool, currentShiftState: Bool) {
        let oldSwitcherModifierState = isSwitcherModifierKeyPressed
        let oldShiftState = isShiftKeyPressedGeneral

        isSwitcherModifierKeyPressed = currentSwitcherModifierIsPressed
        isShiftKeyPressedGeneral = currentShiftState

        if !oldSwitcherModifierState && currentSwitcherModifierIsPressed {
            hasProcessedModifierRelease = false
        }

        // Detect when Shift is newly pressed during active window switching or dock previews
        if !oldShiftState, currentShiftState,
           previewCoordinator.isVisible,
           (previewCoordinator.windowSwitcherCoordinator.windowSwitcherActive && (currentSwitcherModifierIsPressed || Defaults[.preventSwitcherHide])) ||
           (!previewCoordinator.windowSwitcherCoordinator.windowSwitcherActive)
        {
            Task { @MainActor in
                await self.windowSwitchingCoordinator.handleWindowSwitching(
                    previewCoordinator: self.previewCoordinator,
                    isModifierPressed: currentSwitcherModifierIsPressed,
                    isShiftPressed: true
                )
            }
        }

        if !Defaults[.preventSwitcherHide] {
            if oldSwitcherModifierState, !isSwitcherModifierKeyPressed, !hasProcessedModifierRelease {
                hasProcessedModifierRelease = true
                Task { @MainActor in
                    if let selectedWindow = self.windowSwitchingCoordinator.selectCurrentWindow() {
                        WindowUtil.bringWindowToFront(windowInfo: selectedWindow)
                        self.previewCoordinator.hideWindow()
                    } else if self.previewCoordinator.isVisible, self.previewCoordinator.windowSwitcherCoordinator.windowSwitcherActive {
                        self.previewCoordinator.selectAndBringToFrontCurrentWindow()
                    }
                }
            }
        }
    }

    private func determineActionForKeyDown(event: CGEvent) -> (shouldConsume: Bool, actionTask: (() async -> Void)?) {
        // Check if we should ignore keybinds for fullscreen blacklisted apps
        if WindowUtil.shouldIgnoreKeybindForFrontmostApp() {
            return (false, nil)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        let keyBoardShortcutSaved: UserKeyBind = Defaults[.UserKeybind]
        let previewIsCurrentlyVisible = previewCoordinator.isVisible

        if previewIsCurrentlyVisible {
            if keyCode == kVK_Escape {
                return (true, {
                    self.windowSwitchingCoordinator.cancelSwitching()
                    await self.previewCoordinator.hideWindow()
                })
            }

            if flags.contains(.maskCommand), previewCoordinator.windowSwitcherCoordinator.currIndex >= 0 {
                switch keyCode {
                case Int64(kVK_ANSI_W):
                    return (true, { await self.previewCoordinator.performActionOnCurrentWindow(action: .close) })
                case Int64(kVK_ANSI_Q):
                    return (true, { await self.previewCoordinator.performActionOnCurrentWindow(action: .quit) })
                case Int64(kVK_ANSI_M):
                    return (true, { await self.previewCoordinator.performActionOnCurrentWindow(action: .minimize) })
                default:
                    break
                }
            }
        }

        let isExactSwitcherShortcutPressed = (isSwitcherModifierKeyPressed && keyCode == keyBoardShortcutSaved.keyCode) ||
            (!isSwitcherModifierKeyPressed && keyBoardShortcutSaved.modifierFlags == 0 && keyCode == keyBoardShortcutSaved.keyCode)

        if isExactSwitcherShortcutPressed {
            return (true, { await self.handleKeybindActivation() })
        }

        if previewIsCurrentlyVisible {
            if keyCode == kVK_Tab {
                // Tab always goes forward, backwards navigation is handled by Shift modifier changes
                return (true, {
                    if self.previewCoordinator.windowSwitcherCoordinator.windowSwitcherActive {
                        await self.windowSwitchingCoordinator.handleWindowSwitching(
                            previewCoordinator: self.previewCoordinator,
                            isModifierPressed: self.isSwitcherModifierKeyPressed,
                            isShiftPressed: false
                        )
                    } else {
                        await self.previewCoordinator.navigateWithArrowKey(direction: .right)
                    }
                })
            }

            switch keyCode {
            case Int64(kVK_LeftArrow), Int64(kVK_RightArrow), Int64(kVK_UpArrow), Int64(kVK_DownArrow):
                let dir: ArrowDirection = switch keyCode {
                case Int64(kVK_LeftArrow):
                    .left
                case Int64(kVK_RightArrow):
                    .right
                case Int64(kVK_UpArrow):
                    .up
                default:
                    .down
                }
                return (true, { await self.previewCoordinator.navigateWithArrowKey(direction: dir) })
            case Int64(kVK_Return):
                if previewCoordinator.windowSwitcherCoordinator.currIndex >= 0 {
                    return (true, {
                        if let selectedWindow = self.windowSwitchingCoordinator.selectCurrentWindow() {
                            WindowUtil.bringWindowToFront(windowInfo: selectedWindow)
                            await self.previewCoordinator.hideWindow()
                        } else {
                            await self.previewCoordinator.selectAndBringToFrontCurrentWindow()
                        }
                    })
                }
            default:
                break
            }
        }

        if previewIsCurrentlyVisible,
           previewCoordinator.windowSwitcherCoordinator.windowSwitcherActive,
           keyCode == keyBoardShortcutSaved.keyCode,
           !isSwitcherModifierKeyPressed,
           keyBoardShortcutSaved.modifierFlags != 0,
           !flags.hasSuperfluousModifiers(ignoring: [.maskShift, .maskAlphaShift, .maskNumericPad])
        {
            return (true, { await self.handleKeybindActivation() })
        }

        return (false, nil)
    }

    @MainActor
    private func handleKeybindActivation() {
        hasProcessedModifierRelease = false
        Task { @MainActor in
            await windowSwitchingCoordinator.handleWindowSwitching(
                previewCoordinator: previewCoordinator,
                isModifierPressed: self.isSwitcherModifierKeyPressed,
                isShiftPressed: self.isShiftKeyPressedGeneral
            )
        }
    }
}

extension CGEventFlags {
    func hasSuperfluousModifiers(ignoring: CGEventFlags = []) -> Bool {
        let significantModifiers: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand]
        let relevantToCheck = significantModifiers.subtracting(ignoring)
        return !intersection(relevantToCheck).isEmpty
    }
}
