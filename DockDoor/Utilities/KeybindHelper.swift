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
    private var uiRenderingTask: Task<Void, Never>?
    private var currentSessionId = UUID()
    /// When true, initialization should complete but immediately select the window instead of showing UI
    private var shouldSelectImmediately = false

    @MainActor
    func handleWindowSwitching(
        previewCoordinator: SharedPreviewWindowCoordinator,
        isModifierPressed: Bool,
        isShiftPressed: Bool,
        mode: SwitcherInvocationMode = .allWindows
    ) async {
        guard !isProcessingSwitcher else { return }
        isProcessingSwitcher = true
        defer { isProcessingSwitcher = false }

        let coordinator = previewCoordinator.windowSwitcherCoordinator

        if coordinator.isKeybindSessionActive {
            coordinator.hasMovedSinceOpen = false
            coordinator.initialHoverLocation = nil

            if isShiftPressed {
                coordinator.cycleBackward()
            } else {
                coordinator.cycleForward()
            }
        } else if isModifierPressed {
            await initializeWindowSwitching(
                previewCoordinator: previewCoordinator,
                mode: mode
            )
        }
    }

    @MainActor
    private func initializeWindowSwitching(
        previewCoordinator: SharedPreviewWindowCoordinator,
        mode: SwitcherInvocationMode = .allWindows
    ) async {
        // Reset the immediate-select flag at start of initialization
        shouldSelectImmediately = false

        var windows = WindowUtil.getAllWindowsOfAllApps()

        let filterBySpace = (mode == .currentSpaceOnly || mode == .activeAppCurrentSpace)
            || (mode == .allWindows && Defaults[.showWindowsFromCurrentSpaceOnlyInSwitcher])
        if filterBySpace {
            windows = WindowUtil.filterWindowsByCurrentSpace(windows)
        }

        let filterByApp = (mode == .activeAppOnly || mode == .activeAppCurrentSpace)
            || (mode == .allWindows && Defaults[.limitSwitcherToFrontmostApp])
        if filterByApp {
            windows = WindowUtil.getWindowsForFrontmostApp(from: windows)
        }

        if !Defaults[.includeHiddenWindowsInSwitcher] {
            windows = windows.filter { !$0.isHidden && !$0.isMinimized }
        }

        windows = WindowUtil.sortWindowsForSwitcher(windows)

        // Group windows for selected apps (only in multi-app modes)
        let isActiveAppMode = (mode == .activeAppOnly || mode == .activeAppCurrentSpace)
        if !isActiveAppMode {
            windows = WindowUtil.groupWindowsByApp(windows)
        }

        guard !windows.isEmpty else { return }

        currentSessionId = UUID()
        let sessionId = currentSessionId

        let coordinator = previewCoordinator.windowSwitcherCoordinator
        let targetScreen = getTargetScreenForSwitcher()
        coordinator.initializeForWindowSwitcher(with: windows, dockPosition: DockUtils.getDockPosition(), bestGuessMonitor: targetScreen)
        coordinator.activateKeybindSession()

        // If modifier was released during initialization, immediately select and exit
        if shouldSelectImmediately {
            if let selectedWindow = coordinator.getCurrentWindow() {
                selectedWindow.bringToFront()
            }
            coordinator.deactivateKeybindSession()
            shouldSelectImmediately = false
            return
        }

        let currentMouseLocation = DockObserver.getMousePosition()

        uiRenderingTask?.cancel()
        uiRenderingTask = Task { @MainActor in
            if !Defaults[.instantWindowSwitcher] {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            await renderWindowSwitcherUI(
                previewCoordinator: previewCoordinator,
                windows: windows,
                currentMouseLocation: currentMouseLocation,
                targetScreen: targetScreen,
                initialIndex: coordinator.currIndex,
                sessionId: sessionId
            )
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
        let coordinator = previewCoordinator.windowSwitcherCoordinator
        guard coordinator.isKeybindSessionActive else { return }

        if previewCoordinator.isVisible, coordinator.windowSwitcherActive {
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
                    self.cancelSwitching(previewCoordinator: previewCoordinator)
                    Task { @MainActor in
                        previewCoordinator.hideWindow()
                    }
                },
                initialIndex: coordinator.currIndex
            )
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

    @MainActor
    func selectCurrentWindow(previewCoordinator: SharedPreviewWindowCoordinator) -> WindowInfo? {
        let coordinator = previewCoordinator.windowSwitcherCoordinator
        guard coordinator.isKeybindSessionActive else { return nil }

        let selectedWindow = coordinator.getCurrentWindow()
        currentSessionId = UUID()
        coordinator.deactivateKeybindSession()
        uiRenderingTask?.cancel()
        return selectedWindow
    }

    func isActive(previewCoordinator: SharedPreviewWindowCoordinator) -> Bool {
        previewCoordinator.windowSwitcherCoordinator.isKeybindSessionActive
    }

    @MainActor
    func cancelSwitching(previewCoordinator: SharedPreviewWindowCoordinator) {
        currentSessionId = UUID()
        shouldSelectImmediately = false
        previewCoordinator.windowSwitcherCoordinator.deactivateKeybindSession()
        uiRenderingTask?.cancel()
    }

    /// Signals that the modifier was released during initialization.
    /// If initialization is still in progress, it will complete but immediately select the window.
    /// If initialization already completed, this just cancels the UI rendering task.
    @MainActor
    func cancelPendingRender() {
        currentSessionId = UUID()
        shouldSelectImmediately = true
        uiRenderingTask?.cancel()
    }
}

class KeybindHelper {
    private let previewCoordinator: SharedPreviewWindowCoordinator
    private let windowSwitchingCoordinator = WindowSwitchingCoordinator()

    private var isSwitcherModifierKeyPressed: Bool = false
    private var isShiftKeyPressedGeneral: Bool = false
    private var hasProcessedModifierRelease: Bool = false
    private var preventSwitcherHideOnRelease: Bool = false
    private var heldKeyRepeatTask: Task<Void, Never>?

    // Track the invocation mode for alternate keybinds
    private var currentInvocationMode: SwitcherInvocationMode = .allWindows

    // Track Command key state to detect key-up fallback for lingering previews
    private var isCommandKeyCurrentlyDown: Bool = false
    private var lastCmdTabObservedActive: Bool = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var monitorTimer: Timer?
    private var unmanagedEventTapUserInfo: Unmanaged<KeybindHelperUserInfo>?

    init(previewCoordinator: SharedPreviewWindowCoordinator) {
        self.previewCoordinator = previewCoordinator
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
        heldKeyRepeatTask?.cancel()
        heldKeyRepeatTask = nil
        removeEventTap()
    }

    /// Cancels any running held-key repeat task to prevent main thread blocking
    func cancelHeldKeyRepeatTask() {
        heldKeyRepeatTask?.cancel()
        heldKeyRepeatTask = nil
    }

    private func resetState() {
        isSwitcherModifierKeyPressed = false
        isShiftKeyPressedGeneral = false
        preventSwitcherHideOnRelease = false
        currentInvocationMode = .allWindows
        cancelHeldKeyRepeatTask()
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
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue)

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
        if let passthrough = reEnableIfNeeded(tap: eventTap, type: type, event: event) {
            return passthrough
        }

        switch type {
        case .flagsChanged:
            let keyBoardShortcutSaved: UserKeyBind = Defaults[.UserKeybind]
            let (currentSwitcherModifierIsPressed, currentShiftState) = updateModifierStatesFromFlags(event: event, keyBoardShortcutSaved: keyBoardShortcutSaved)

            // Track Command up/down explicitly for Cmd+Tab fallback behavior
            let cmdNowDown = event.flags.contains(.maskCommand)
            if isCommandKeyCurrentlyDown, !cmdNowDown {
                DockObserver.activeInstance?.stopCmdTabPolling()

                if Defaults[.enableCmdTabEnhancements], lastCmdTabObservedActive,
                   previewCoordinator.isVisible,
                   !previewCoordinator.windowSwitcherCoordinator.windowSwitcherActive
                {
                    Task { @MainActor in
                        if self.previewCoordinator.windowSwitcherCoordinator.currIndex >= 0 {
                            self.previewCoordinator.selectAndBringToFrontCurrentWindow()
                        } else {
                            self.previewCoordinator.hideWindow()
                        }
                    }
                }
                lastCmdTabObservedActive = false
            }
            isCommandKeyCurrentlyDown = cmdNowDown

            Task { @MainActor [weak self] in
                self?.handleModifierEvent(currentSwitcherModifierIsPressed: currentSwitcherModifierIsPressed, currentShiftState: currentShiftState)
            }

        case .keyDown:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags

            // Detect Cmd+Tab press to start on-demand polling for the switcher
            if Defaults[.enableCmdTabEnhancements],
               keyCode == Int64(kVK_Tab),
               flags.contains(.maskCommand)
            {
                let keyBoardShortcutSaved: UserKeyBind = Defaults[.UserKeybind]
                let isCustomKeybind = (keyCode == keyBoardShortcutSaved.keyCode) &&
                    (keyBoardShortcutSaved.modifierFlags & Int(CGEventFlags.maskCommand.rawValue)) != 0

                if !isCustomKeybind {
                    DockObserver.activeInstance?.startCmdTabPolling()
                }
            }

            // If system Cmd+Tab switcher is active, optionally handle arrows when enhancements are enabled
            if DockObserver.isCmdTabSwitcherActive {
                lastCmdTabObservedActive = true
                if Defaults[.enableCmdTabEnhancements],
                   previewCoordinator.isVisible
                {
                    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                    let hasSelection = previewCoordinator.windowSwitcherCoordinator.currIndex >= 0
                    let flags = event.flags
                    switch keyCode {
                    case Int64(kVK_Escape):
                        Task { @MainActor in
                            self.previewCoordinator.hideWindow()
                        }
                        return nil
                    case Int64(kVK_LeftArrow):
                        if hasSelection {
                            Task { @MainActor in
                                self.previewCoordinator.navigateWithArrowKey(direction: .left)
                            }
                            // Consume only when a selection is active (focused mode)
                            return nil
                        } else {
                            // Let system Cmd+Tab handle left/right until user focuses with Up
                            return Unmanaged.passUnretained(event)
                        }
                    case Int64(kVK_RightArrow):
                        if hasSelection {
                            Task { @MainActor in
                                self.previewCoordinator.navigateWithArrowKey(direction: .right)
                            }
                            return nil
                        } else {
                            return Unmanaged.passUnretained(event)
                        }
                    case Int64(kVK_UpArrow):
                        return Unmanaged.passUnretained(event)
                    case Int64(kVK_DownArrow):
                        // If a preview is selected, first Down just deselects and is consumed.
                        // Subsequent Down (with no selection) is passed through to system Exposé.
                        if hasSelection {
                            Task { @MainActor in
                                self.previewCoordinator.windowSwitcherCoordinator.setIndex(to: -1)
                            }
                            return nil
                        } else {
                            return Unmanaged.passUnretained(event)
                        }
                    default:
                        // Allow activation via customizable Cmd+key (when not yet focused) and
                        // Command-based actions when a preview is focused
                        if flags.contains(.maskCommand) {
                            // Backward cycle key (default: `)
                            if hasSelection, keyCode == Int64(Defaults[.cmdTabBackwardCycleKey]) {
                                Task { @MainActor in
                                    let currentIndex = self.previewCoordinator.windowSwitcherCoordinator.currIndex
                                    let windowCount = self.previewCoordinator.windowSwitcherCoordinator.windows.count
                                    let newIndex = currentIndex > 0 ? currentIndex - 1 : windowCount - 1
                                    self.previewCoordinator.windowSwitcherCoordinator.setIndex(to: newIndex)
                                }
                                return nil
                            }

                            // Forward cycle key (default: A)
                            if keyCode == Int64(Defaults[.cmdTabCycleKey]) {
                                Task { @MainActor in
                                    let currentIndex = self.previewCoordinator.windowSwitcherCoordinator.currIndex
                                    let windowCount = self.previewCoordinator.windowSwitcherCoordinator.windows.count
                                    let isShift = flags.contains(.maskShift)

                                    if !hasSelection {
                                        // First activation: select first preview
                                        self.previewCoordinator.windowSwitcherCoordinator.setIndex(to: 0)
                                        Defaults[.hasSeenCmdTabFocusHint] = true
                                    } else if isShift {
                                        // Cmd+Shift+A: cycle backward
                                        let newIndex = currentIndex > 0 ? currentIndex - 1 : windowCount - 1
                                        self.previewCoordinator.windowSwitcherCoordinator.setIndex(to: newIndex)
                                    } else {
                                        // Cmd+A: cycle forward
                                        let newIndex = (currentIndex + 1) % windowCount
                                        self.previewCoordinator.windowSwitcherCoordinator.setIndex(to: newIndex)
                                    }
                                }
                                return nil
                            }
                        }

                        if hasSelection, flags.contains(.maskCommand) {
                            // Check configurable Cmd+key shortcuts
                            if let action = getActionForCmdShortcut(keyCode: keyCode) {
                                Task { @MainActor in
                                    self.previewCoordinator.performActionOnCurrentWindow(action: action)
                                }
                                return nil
                            }
                        }
                    }
                }
                // Not enhancing or not in our cmdTab context — let the system handle it.
                return Unmanaged.passUnretained(event)
            }
            let (shouldConsume, actionTask) = determineActionForKeyDown(event: event)
            if let task = actionTask {
                heldKeyRepeatTask?.cancel()
                heldKeyRepeatTask = Task { @MainActor in
                    await task()
                }
            }
            if shouldConsume { return nil }

        case .leftMouseDown:
            let isWindowSwitcherActive = previewCoordinator.windowSwitcherCoordinator.windowSwitcherActive
            let isCmdTabActive = DockObserver.isCmdTabSwitcherActive

            if previewCoordinator.isVisible, isWindowSwitcherActive || isCmdTabActive {
                let clickLocation = NSEvent.mouseLocation
                let windowFrame = previewCoordinator.frame

                let searchFrame = SharedPreviewWindowCoordinator.activeInstance?.searchWindowFrame
                let isInSearchWindow = searchFrame?.contains(clickLocation) ?? false
                if windowFrame.contains(clickLocation) || isInSearchWindow {
                    let flags = event.flags
                    if flags.contains(.maskControl) {
                        var newFlags = flags
                        newFlags.remove(.maskControl)
                        event.flags = newFlags
                    }
                } else {
                    Task { @MainActor in
                        if isWindowSwitcherActive {
                            self.windowSwitchingCoordinator.cancelSwitching(previewCoordinator: self.previewCoordinator)
                            self.preventSwitcherHideOnRelease = false
                            self.hasProcessedModifierRelease = true
                        }
                        if isCmdTabActive {
                            DockObserver.activeInstance?.teardownCmdTabObserver()
                        }
                        self.previewCoordinator.hideWindow()
                    }
                }
            }

        default:
            break
        }
        return Unmanaged.passUnretained(event)
    }

    private func updateModifierStatesFromFlags(event: CGEvent, keyBoardShortcutSaved: UserKeyBind) -> (currentSwitcherModifierIsPressed: Bool, currentShiftState: Bool) {
        // Interpret saved mask by checking presence of standard CGEventFlag bits
        let saved = keyBoardShortcutSaved.modifierFlags
        let wantsAlt = (saved & Int(CGEventFlags.maskAlternate.rawValue)) != 0
        let wantsCtrl = (saved & Int(CGEventFlags.maskControl.rawValue)) != 0
        let wantsCmd = (saved & Int(CGEventFlags.maskCommand.rawValue)) != 0

        let flags = event.flags
        let hasAlt = flags.contains(.maskAlternate)
        let hasCtrl = flags.contains(.maskControl)
        let hasCmd = flags.contains(.maskCommand)

        let currentSwitcherModifierIsPressed = (wantsAlt == hasAlt) && (wantsCtrl == hasCtrl) && (wantsCmd == hasCmd)
        let currentShiftState = flags.contains(.maskShift)

        return (currentSwitcherModifierIsPressed, currentShiftState)
    }

    @MainActor
    private func handleModifierEvent(currentSwitcherModifierIsPressed: Bool, currentShiftState: Bool) {
        // If system Cmd+Tab switcher is active, do not engage DockDoor's own switcher logic
        if DockObserver.isCmdTabSwitcherActive { return }
        let oldSwitcherModifierState = isSwitcherModifierKeyPressed
        let oldShiftState = isShiftKeyPressedGeneral

        isSwitcherModifierKeyPressed = currentSwitcherModifierIsPressed
        isShiftKeyPressedGeneral = currentShiftState

        if preventSwitcherHideOnRelease, !previewCoordinator.isVisible {
            preventSwitcherHideOnRelease = false
        }

        if !oldSwitcherModifierState && currentSwitcherModifierIsPressed {
            hasProcessedModifierRelease = false
        }

        let isWindowSwitcherActive = previewCoordinator.windowSwitcherCoordinator.windowSwitcherActive
        let shouldSkipShiftOnlyBackward = Defaults[.requireShiftTabToGoBack] && isWindowSwitcherActive

        // Only allow Shift-only backward cycling when the window switcher is already active.
        if !oldShiftState, currentShiftState,
           previewCoordinator.isVisible,
           isWindowSwitcherActive,
           currentSwitcherModifierIsPressed || Defaults[.preventSwitcherHide]
        {
            if !shouldSkipShiftOnlyBackward {
                Task { @MainActor in
                    await self.windowSwitchingCoordinator.handleWindowSwitching(
                        previewCoordinator: self.previewCoordinator,
                        isModifierPressed: currentSwitcherModifierIsPressed,
                        isShiftPressed: true,
                        mode: self.currentInvocationMode
                    )
                }

                if isWindowSwitcherActive {
                    heldKeyRepeatTask?.cancel()
                    heldKeyRepeatTask = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 400_000_000)

                        while !Task.isCancelled,
                              self.isShiftKeyPressedGeneral,
                              self.previewCoordinator.isVisible,
                              self.previewCoordinator.windowSwitcherCoordinator.windowSwitcherActive
                        {
                            await self.windowSwitchingCoordinator.handleWindowSwitching(
                                previewCoordinator: self.previewCoordinator,
                                isModifierPressed: self.isSwitcherModifierKeyPressed,
                                isShiftPressed: true,
                                mode: self.currentInvocationMode
                            )
                            try? await Task.sleep(nanoseconds: 80_000_000)
                        }
                    }
                }
            }
        }

        if oldShiftState, !currentShiftState {
            cancelHeldKeyRepeatTask()
        }

        if !Defaults[.preventSwitcherHide], !preventSwitcherHideOnRelease, !(previewCoordinator.isSearchWindowFocused) {
            if oldSwitcherModifierState, !isSwitcherModifierKeyPressed, !hasProcessedModifierRelease {
                hasProcessedModifierRelease = true
                preventSwitcherHideOnRelease = false

                windowSwitchingCoordinator.cancelPendingRender()

                Task { @MainActor in
                    if self.previewCoordinator.isVisible, self.previewCoordinator.windowSwitcherCoordinator.windowSwitcherActive {
                        self.previewCoordinator.selectAndBringToFrontCurrentWindow()
                        self.windowSwitchingCoordinator.cancelSwitching(previewCoordinator: self.previewCoordinator)
                    } else if let selectedWindow = self.windowSwitchingCoordinator.selectCurrentWindow(previewCoordinator: self.previewCoordinator) {
                        selectedWindow.bringToFront()
                        self.previewCoordinator.hideWindow()
                    }
                }
            }
        }
    }

    private func determineActionForKeyDown(event: CGEvent) -> (shouldConsume: Bool, actionTask: (() async -> Void)?) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        let keyBoardShortcutSaved: UserKeyBind = Defaults[.UserKeybind]
        let previewIsCurrentlyVisible = previewCoordinator.isVisible

        if previewIsCurrentlyVisible {
            if keyCode == kVK_Escape {
                return (true, { @MainActor in
                    self.windowSwitchingCoordinator.cancelSwitching(previewCoordinator: self.previewCoordinator)
                    self.previewCoordinator.hideWindow()
                    self.preventSwitcherHideOnRelease = false
                    self.hasProcessedModifierRelease = true
                })
            }

            if flags.contains(.maskCommand), previewCoordinator.windowSwitcherCoordinator.currIndex >= 0 {
                // Check configurable Cmd+key shortcuts
                if let action = getActionForCmdShortcut(keyCode: keyCode) {
                    return (true, { await self.previewCoordinator.performActionOnCurrentWindow(action: action) })
                }
            }
        }

        // Compute desired modifier press based on current event flags to avoid relying solely on flagsChanged ordering
        let wantsAlt = (keyBoardShortcutSaved.modifierFlags & Int(CGEventFlags.maskAlternate.rawValue)) != 0
        let wantsCtrl = (keyBoardShortcutSaved.modifierFlags & Int(CGEventFlags.maskControl.rawValue)) != 0
        let wantsCmd = (keyBoardShortcutSaved.modifierFlags & Int(CGEventFlags.maskCommand.rawValue)) != 0
        let hasAlt = flags.contains(.maskAlternate)
        let hasCtrl = flags.contains(.maskControl)
        let hasCmd = flags.contains(.maskCommand)
        let isDesiredModifierPressedNow = (wantsAlt == hasAlt) && (wantsCtrl == hasCtrl) && (wantsCmd == hasCmd)

        let isExactSwitcherShortcutPressed = (isDesiredModifierPressedNow && keyCode == keyBoardShortcutSaved.keyCode) ||
            (!isDesiredModifierPressedNow && keyBoardShortcutSaved.modifierFlags == 0 && keyCode == keyBoardShortcutSaved.keyCode)

        if isExactSwitcherShortcutPressed {
            guard Defaults[.enableWindowSwitcher] else { return (false, nil) }
            if WindowUtil.shouldIgnoreKeybindForFrontmostApp() { return (false, nil) }
            return (true, { await self.handleKeybindActivation(mode: .allWindows) })
        }

        // Check alternate keybind (shares same modifier as primary keybind)
        if isDesiredModifierPressedNow {
            let alternateKey = Defaults[.alternateKeybindKey]
            if alternateKey != 0, keyCode == alternateKey {
                guard Defaults[.enableWindowSwitcher] else { return (false, nil) }
                if WindowUtil.shouldIgnoreKeybindForFrontmostApp() { return (false, nil) }
                let mode = Defaults[.alternateKeybindMode]
                return (true, { await self.handleKeybindActivation(mode: mode) })
            }
        }

        if previewIsCurrentlyVisible {
            if keyCode == kVK_Tab {
                let isShiftPressed = flags.contains(.maskShift)

                return (true, { @MainActor in
                    if self.previewCoordinator.windowSwitcherCoordinator.windowSwitcherActive {
                        if !self.previewCoordinator.windowSwitcherCoordinator.hasActiveSearch {
                            let shouldGoBackward = isShiftPressed &&
                                (!Defaults[.requireShiftTabToGoBack] ||
                                    self.isSwitcherModifierKeyPressed ||
                                    Defaults[.preventSwitcherHide])

                            await self.windowSwitchingCoordinator.handleWindowSwitching(
                                previewCoordinator: self.previewCoordinator,
                                isModifierPressed: self.isSwitcherModifierKeyPressed,
                                isShiftPressed: shouldGoBackward,
                                mode: self.currentInvocationMode
                            )
                        }
                    } else {
                        self.previewCoordinator.navigateWithArrowKey(direction: .right)
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
                return (true, { @MainActor in
                    self.previewCoordinator.navigateWithArrowKey(direction: dir)
                })
            case Int64(kVK_Return), Int64(kVK_ANSI_KeypadEnter):
                if previewCoordinator.windowSwitcherCoordinator.currIndex >= 0 {
                    return (true, makeEnterSelectionTask())
                }
            default:
                break
            }
        }

        if previewIsCurrentlyVisible,
           previewCoordinator.windowSwitcherCoordinator.windowSwitcherActive,
           Defaults[.enableWindowSwitcherSearch],
           keyCode == Int64(Defaults[.searchTriggerKey]),
           !(previewCoordinator.isSearchWindowFocused)
        {
            return (true, { @MainActor in
                self.previewCoordinator.focusSearchWindow()
                self.preventSwitcherHideOnRelease = true
            })
        }
        if previewIsCurrentlyVisible,
           previewCoordinator.windowSwitcherCoordinator.windowSwitcherActive,
           Defaults[.enableWindowSwitcherSearch],
           !(previewCoordinator.isSearchWindowFocused)
        {
            if keyCode == Int64(kVK_Delete) {
                return (true, { @MainActor in
                    var query = self.previewCoordinator.windowSwitcherCoordinator.searchQuery
                    if !query.isEmpty {
                        query.removeLast()
                        self.previewCoordinator.windowSwitcherCoordinator.searchQuery = query
                        SharedPreviewWindowCoordinator.activeInstance?.updateSearchWindow(with: query)

                        if query.isEmpty {
                            self.preventSwitcherHideOnRelease = false
                        }
                    }
                })
            }

            if !flags.contains(.maskCommand),
               let nsEvent = NSEvent(cgEvent: event),
               let characters = nsEvent.characters,
               !characters.isEmpty
            {
                let filteredChars = characters.filter { char in
                    char.isLetter || char.isNumber || char.isWhitespace ||
                        ".,!?-_()[]{}@#$%^&*+=|\\:;\"'<>/~`".contains(char)
                }
                if !filteredChars.isEmpty {
                    return (true, { @MainActor in
                        self.previewCoordinator.windowSwitcherCoordinator.searchQuery.append(contentsOf: filteredChars)
                        let newQuery = self.previewCoordinator.windowSwitcherCoordinator.searchQuery
                        SharedPreviewWindowCoordinator.activeInstance?.updateSearchWindow(with: newQuery)

                        if !newQuery.isEmpty {
                            self.preventSwitcherHideOnRelease = true
                        }
                    })
                }
            }
        }

        if previewIsCurrentlyVisible,
           previewCoordinator.windowSwitcherCoordinator.windowSwitcherActive,
           keyCode == keyBoardShortcutSaved.keyCode,
           !isSwitcherModifierKeyPressed,
           keyBoardShortcutSaved.modifierFlags != 0,
           !flags.hasSuperfluousModifiers(ignoring: [.maskShift, .maskAlphaShift, .maskNumericPad])
        {
            if WindowUtil.shouldIgnoreKeybindForFrontmostApp() { return (false, nil) }
            return (true, { await self.handleKeybindActivation() })
        }

        return (false, nil)
    }

    private func makeEnterSelectionTask() -> (() async -> Void) {
        { @MainActor in
            self.preventSwitcherHideOnRelease = false

            if self.previewCoordinator.isVisible, self.previewCoordinator.windowSwitcherCoordinator.windowSwitcherActive {
                self.previewCoordinator.selectAndBringToFrontCurrentWindow()
                self.windowSwitchingCoordinator.cancelSwitching(previewCoordinator: self.previewCoordinator)
                return
            }

            if let selectedWindow = self.windowSwitchingCoordinator.selectCurrentWindow(previewCoordinator: self.previewCoordinator) {
                selectedWindow.bringToFront()
                self.previewCoordinator.hideWindow()
            } else {
                self.previewCoordinator.selectAndBringToFrontCurrentWindow()
            }
        }
    }

    @MainActor
    private func handleKeybindActivation(mode: SwitcherInvocationMode = .allWindows) {
        guard Defaults[.enableWindowSwitcher] else { return }
        hasProcessedModifierRelease = false
        currentInvocationMode = mode
        Task { @MainActor in
            await windowSwitchingCoordinator.handleWindowSwitching(
                previewCoordinator: previewCoordinator,
                isModifierPressed: self.isSwitcherModifierKeyPressed,
                isShiftPressed: self.isShiftKeyPressedGeneral,
                mode: mode
            )
        }
    }

    /// Returns the action for a Cmd+key shortcut if the keyCode matches any configured shortcut
    private func getActionForCmdShortcut(keyCode: Int64) -> WindowAction? {
        let shortcut1Key = Defaults[.cmdShortcut1Key]
        let shortcut2Key = Defaults[.cmdShortcut2Key]
        let shortcut3Key = Defaults[.cmdShortcut3Key]

        switch keyCode {
        case Int64(shortcut1Key):
            let action = Defaults[.cmdShortcut1Action]
            return action != .none ? action : nil
        case Int64(shortcut2Key):
            let action = Defaults[.cmdShortcut2Action]
            return action != .none ? action : nil
        case Int64(shortcut3Key):
            let action = Defaults[.cmdShortcut3Action]
            return action != .none ? action : nil
        default:
            return nil
        }
    }
}

/// Re-enables a disabled event tap and returns a passthrough result, or nil if the event type is not tap-disabled.
func reEnableIfNeeded(tap: CFMachPort?, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
    guard type == .tapDisabledByTimeout || type == .tapDisabledByUserInput else { return nil }
    if let tap {
        CGEvent.tapEnable(tap: tap, enable: true)
    }
    return Unmanaged.passUnretained(event)
}

extension CGEventFlags {
    func hasSuperfluousModifiers(ignoring: CGEventFlags = []) -> Bool {
        let significantModifiers: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand]
        let relevantToCheck = significantModifiers.subtracting(ignoring)
        return !intersection(relevantToCheck).isEmpty
    }
}
