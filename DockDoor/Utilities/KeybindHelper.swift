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
    let stateManager = WindowSwitcherStateManager()
    private var uiRenderingTask: Task<Void, Never>?
    private var currentSessionId = UUID()

    private static var lastUpdateAllWindowsTime: Date?
    private static let updateAllWindowsThrottleInterval: TimeInterval = 60.0

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
        var windows = WindowUtil.getAllWindowsOfAllApps()
        if Defaults[.showWindowsFromCurrentSpaceOnlyInSwitcher] {
            windows = await WindowUtil.filterWindowsByCurrentSpace(windows)
        }
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
            let now = Date()
            let shouldUpdate: Bool = if let lastUpdate = WindowSwitchingCoordinator.lastUpdateAllWindowsTime {
                now.timeIntervalSince(lastUpdate) >= WindowSwitchingCoordinator.updateAllWindowsThrottleInterval
            } else {
                true
            }

            guard shouldUpdate else { return }
            WindowSwitchingCoordinator.lastUpdateAllWindowsTime = now
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
                    self.cancelSwitching()
                    Task { @MainActor in
                        previewCoordinator.hideWindow()
                    }
                },
                initialIndex: self.stateManager.currentIndex
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
    private let windowSwitchingCoordinator = WindowSwitchingCoordinator()

    private var isSwitcherModifierKeyPressed: Bool = false
    private var isShiftKeyPressedGeneral: Bool = false
    private var hasProcessedModifierRelease: Bool = false
    private var preventSwitcherHideOnRelease: Bool = false

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
        removeEventTap()
    }

    private func resetState() {
        isSwitcherModifierKeyPressed = false
        isShiftKeyPressedGeneral = false
        preventSwitcherHideOnRelease = false
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
            if DockObserver.isCmdTabSwitcherActive() {
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
                        // Allow activation via Cmd+A (when not yet focused) and
                        // Command-based actions when a preview is focused
                        if flags.contains(.maskCommand) {
                            if keyCode == Int64(kVK_ANSI_A) {
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
                            switch keyCode {
                            case Int64(kVK_ANSI_W):
                                Task { @MainActor in
                                    self.previewCoordinator.performActionOnCurrentWindow(action: .close)
                                }
                                return nil
                            case Int64(kVK_ANSI_Q):
                                Task { @MainActor in
                                    self.previewCoordinator.performActionOnCurrentWindow(action: .quit)
                                }
                                return nil
                            case Int64(kVK_ANSI_M):
                                Task { @MainActor in
                                    self.previewCoordinator.performActionOnCurrentWindow(action: .minimize)
                                }
                                return nil
                            default:
                                break
                            }
                        }
                    }
                }
                // Not enhancing or not in our cmdTab context — let the system handle it.
                return Unmanaged.passUnretained(event)
            }
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
        // Interpret saved mask by checking presence of standard CGEventFlag bits
        let saved = keyBoardShortcutSaved.modifierFlags
        let wantsAlt = (saved & Int(CGEventFlags.maskAlternate.rawValue)) != 0
        let wantsCtrl = (saved & Int(CGEventFlags.maskControl.rawValue)) != 0
        let wantsCmd = (saved & Int(CGEventFlags.maskCommand.rawValue)) != 0

        let flags = event.flags
        let hasAlt = flags.contains(.maskAlternate)
        let hasCtrl = flags.contains(.maskControl)
        let hasCmd = flags.contains(.maskCommand)

        let currentSwitcherModifierIsPressed = (wantsAlt && hasAlt) || (wantsCtrl && hasCtrl) || (wantsCmd && hasCmd)
        let currentShiftState = flags.contains(.maskShift)

        return (currentSwitcherModifierIsPressed, currentShiftState)
    }

    @MainActor
    private func handleModifierEvent(currentSwitcherModifierIsPressed: Bool, currentShiftState: Bool) {
        // If system Cmd+Tab switcher is active, do not engage DockDoor's own switcher logic
        if DockObserver.isCmdTabSwitcherActive() { return }
        let oldSwitcherModifierState = isSwitcherModifierKeyPressed
        let oldShiftState = isShiftKeyPressedGeneral

        isSwitcherModifierKeyPressed = currentSwitcherModifierIsPressed
        isShiftKeyPressedGeneral = currentShiftState

        if !oldSwitcherModifierState && currentSwitcherModifierIsPressed {
            hasProcessedModifierRelease = false
        }

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

        if !Defaults[.preventSwitcherHide], !preventSwitcherHideOnRelease, !(previewCoordinator.isSearchWindowFocused) {
            if oldSwitcherModifierState, !isSwitcherModifierKeyPressed, !hasProcessedModifierRelease {
                hasProcessedModifierRelease = true
                preventSwitcherHideOnRelease = false
                Task { @MainActor in
                    if self.previewCoordinator.isVisible, self.previewCoordinator.windowSwitcherCoordinator.windowSwitcherActive {
                        self.previewCoordinator.selectAndBringToFrontCurrentWindow()
                        self.windowSwitchingCoordinator.cancelSwitching()
                    } else if let selectedWindow = self.windowSwitchingCoordinator.selectCurrentWindow() {
                        WindowUtil.bringWindowToFront(windowInfo: selectedWindow)
                        self.previewCoordinator.hideWindow()
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
                    self.preventSwitcherHideOnRelease = false
                    self.hasProcessedModifierRelease = true
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

        // Compute desired modifier press based on current event flags to avoid relying solely on flagsChanged ordering
        let wantsAlt = (keyBoardShortcutSaved.modifierFlags & Int(CGEventFlags.maskAlternate.rawValue)) != 0
        let wantsCtrl = (keyBoardShortcutSaved.modifierFlags & Int(CGEventFlags.maskControl.rawValue)) != 0
        let wantsCmd = (keyBoardShortcutSaved.modifierFlags & Int(CGEventFlags.maskCommand.rawValue)) != 0
        let isDesiredModifierPressedNow = (wantsAlt && flags.contains(.maskAlternate)) ||
            (wantsCtrl && flags.contains(.maskControl)) ||
            (wantsCmd && flags.contains(.maskCommand))

        let isExactSwitcherShortcutPressed = (isDesiredModifierPressedNow && keyCode == keyBoardShortcutSaved.keyCode) ||
            (!isDesiredModifierPressedNow && keyBoardShortcutSaved.modifierFlags == 0 && keyCode == keyBoardShortcutSaved.keyCode)

        if isExactSwitcherShortcutPressed {
            return (true, { await self.handleKeybindActivation() })
        }

        if previewIsCurrentlyVisible {
            if keyCode == kVK_Tab {
                return (true, { @MainActor in
                    if self.previewCoordinator.windowSwitcherCoordinator.windowSwitcherActive {
                        let hasActiveSearch = self.previewCoordinator.windowSwitcherCoordinator.hasActiveSearch
                        if !hasActiveSearch {
                            await self.windowSwitchingCoordinator.handleWindowSwitching(
                                previewCoordinator: self.previewCoordinator,
                                isModifierPressed: self.isSwitcherModifierKeyPressed,
                                isShiftPressed: false
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
                    let hasActiveSearch = self.previewCoordinator.windowSwitcherCoordinator.hasActiveSearch
                    if !hasActiveSearch {
                        self.previewCoordinator.navigateWithArrowKey(direction: dir)
                    }
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
           keyCode == Int64(kVK_ANSI_Slash) // Forward slash key
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
            return (true, { await self.handleKeybindActivation() })
        }

        return (false, nil)
    }

    private func makeEnterSelectionTask() -> (() async -> Void) {
        { @MainActor in
            self.preventSwitcherHideOnRelease = false

            if self.previewCoordinator.isVisible, self.previewCoordinator.windowSwitcherCoordinator.windowSwitcherActive {
                self.previewCoordinator.selectAndBringToFrontCurrentWindow()
                self.windowSwitchingCoordinator.cancelSwitching()
                return
            }

            if let selectedWindow = self.windowSwitchingCoordinator.selectCurrentWindow() {
                WindowUtil.bringWindowToFront(windowInfo: selectedWindow)
                self.previewCoordinator.hideWindow()
            } else {
                self.previewCoordinator.selectAndBringToFrontCurrentWindow()
            }
        }
    }

    @MainActor
    private func handleKeybindActivation() {
        guard Defaults[.enableWindowSwitcher] else { return }
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
