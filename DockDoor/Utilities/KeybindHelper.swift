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

    @MainActor
    func handleWindowSwitching(
        previewCoordinator: SharedPreviewWindowCoordinator,
        isModifierPressed: Bool,
        isShiftPressed: Bool
    ) async {
        guard !isProcessingSwitcher else { return }
        isProcessingSwitcher = true
        defer { isProcessingSwitcher = false }

        if previewCoordinator.isVisible {
            previewCoordinator.cycleWindows(goBackwards: isShiftPressed)
        } else if isModifierPressed {
            await showHoverWindow(
                previewCoordinator: previewCoordinator,
                isModifierPressed: isModifierPressed
            )
        }
    }

    @MainActor
    private func showHoverWindow(
        previewCoordinator: SharedPreviewWindowCoordinator,
        isModifierPressed: Bool
    ) async {
        guard isModifierPressed else { return }

        let windows = WindowUtil.getAllWindowsOfAllApps()
        guard !windows.isEmpty else {
            print("No windows found for switcher.")
            return
        }

        let currentMouseLocation = DockObserver.getMousePosition()
        let targetScreen = getTargetScreenForSwitcher()

        displayHoverWindow(
            previewCoordinator: previewCoordinator,
            windows: windows,
            currentMouseLocation: currentMouseLocation,
            targetScreen: targetScreen
        )

        Task.detached(priority: .low) {
            await WindowUtil.updateAllWindowsInCurrentSpace()
        }
    }

    @MainActor
    private func displayHoverWindow(
        previewCoordinator: SharedPreviewWindowCoordinator,
        windows: [WindowInfo],
        currentMouseLocation: CGPoint,
        targetScreen: NSScreen
    ) {
        if Defaults[.useClassicWindowOrdering], windows.count >= 2 {
            previewCoordinator.windowSwitcherCoordinator.setIndex(to: 1)
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
}

class KeybindHelper {
    private let previewCoordinator: SharedPreviewWindowCoordinator
    private let dockObserver: DockObserver
    private let windowSwitchingCoordinator = WindowSwitchingCoordinator()

    private var isSwitcherModifierKeyPressed: Bool = false
    private var isShiftKeyPressedGeneral: Bool = false

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

        // Detect when Shift is newly pressed during active window switching or dock previews
        if !oldShiftState, currentShiftState,
           previewCoordinator.isVisible,
           (previewCoordinator.windowSwitcherCoordinator.windowSwitcherActive && (currentSwitcherModifierIsPressed || Defaults[.preventSwitcherHide])) ||
           (!previewCoordinator.windowSwitcherCoordinator.windowSwitcherActive)
        {
            Task { @MainActor in
                self.previewCoordinator.cycleWindows(goBackwards: true)
            }
        }

        if !Defaults[.preventSwitcherHide] {
            if oldSwitcherModifierState, !isSwitcherModifierKeyPressed {
                Task { @MainActor in
                    if self.previewCoordinator.isVisible, self.previewCoordinator.windowSwitcherCoordinator.windowSwitcherActive {
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
                return (true, { await self.previewCoordinator.hideWindow() })
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
                return (true, { await self.previewCoordinator.cycleWindows(goBackwards: false) })
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
                    return (true, { await self.previewCoordinator.selectAndBringToFrontCurrentWindow() })
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
