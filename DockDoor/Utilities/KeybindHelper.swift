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

class KeybindHelper {
    private let previewCoordinator: SharedPreviewWindowCoordinator
    private let dockObserver: DockObserver

    private var isModifierKeyPressed = false
    private var isShiftKeyPressed = false
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var modifierValue: Int = 0
    private var monitorTimer: Timer?
    private var unmanagedEventTapUserInfo: Unmanaged<KeybindHelperUserInfo>?

    init(previewCoordinator: SharedPreviewWindowCoordinator, dockObserver: DockObserver) {
        self.previewCoordinator = previewCoordinator
        self.dockObserver = dockObserver
        setupEventTap()
        startMonitoring()
    }

    deinit {
        cleanup()
        print("KeybindHelper deinit")
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
        isModifierKeyPressed = false
        isShiftKeyPressed = false
        modifierValue = 0
    }

    private func startMonitoring() {
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.checkEventTapStatus()
        }
    }

    private func checkEventTapStatus() {
        guard let eventTap else {
            reset()
            return
        }

        if !CGEvent.tapIsEnabled(tap: eventTap) {
            reset()
        }
    }

    private static let eventCallback: CGEventTapCallBack = { proxy, type, event, refcon in
        guard let refcon else { return Unmanaged.passUnretained(event) }
        let userInfo = Unmanaged<KeybindHelperUserInfo>.fromOpaque(refcon).takeUnretainedValue()
        return userInfo.instance.handleEvent(proxy: proxy, type: type, event: event)
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
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let keyBoardShortcutSaved: UserKeyBind = Defaults[.UserKeybind]
        let shiftKeyCurrentlyPressed = event.flags.contains(.maskShift)
        var userDefinedKeyCurrentlyPressed = false

        switch type {
        case .flagsChanged:
            handleFlagsChanged(event: event, userDefinedKeyCurrentlyPressed: &userDefinedKeyCurrentlyPressed)
            handleModifierEvent(modifierKeyPressed: userDefinedKeyCurrentlyPressed,
                                shiftKeyPressed: shiftKeyCurrentlyPressed)

        case .keyDown:
            let shouldConsumeKeyEvent = handleKeyDown(keyCode: keyCode,
                                                      keyBoardShortcutSaved: keyBoardShortcutSaved)

            if shouldConsumeKeyEvent {
                return nil
            }

        default:
            break
        }

        return Unmanaged.passUnretained(event)
    }

    private func handleFlagsChanged(event: CGEvent, userDefinedKeyCurrentlyPressed: inout Bool) {
        if event.flags.contains(.maskControl) {
            modifierValue = Defaults[.Int64maskControl]
            userDefinedKeyCurrentlyPressed = true
        } else if event.flags.contains(.maskAlternate) {
            modifierValue = Defaults[.Int64maskAlternate]
            userDefinedKeyCurrentlyPressed = true
        } else if event.flags.contains(.maskCommand) {
            modifierValue = Defaults[.Int64maskCommand]
            userDefinedKeyCurrentlyPressed = true
        }
    }

    private func handleKeyDown(keyCode: Int64, keyBoardShortcutSaved: UserKeyBind) -> Bool {
        if previewCoordinator.isVisible, keyCode == kVK_Escape {
            previewCoordinator.hideWindow()
            return true
        }

        if isModifierKeyPressed,
           keyCode == keyBoardShortcutSaved.keyCode,
           modifierValue == keyBoardShortcutSaved.modifierFlags
        {
            handleKeybindActivation()
            return true
        }

        if previewCoordinator.isVisible,
           !isModifierKeyPressed,
           keyCode == keyBoardShortcutSaved.keyCode
        {
            handleKeybindActivation()
            return true
        }

        return false
    }

    private func handleKeybindActivation() {
        if previewCoordinator.isVisible {
            previewCoordinator.cycleWindows(goBackwards: isShiftKeyPressed)
        } else {
            showHoverWindow()
        }
    }

    private func handleModifierEvent(modifierKeyPressed: Bool, shiftKeyPressed: Bool) {
        let oldModifierState = isModifierKeyPressed
        isModifierKeyPressed = modifierKeyPressed
        isShiftKeyPressed = shiftKeyPressed

        if !Defaults[.preventSwitcherHide] {
            if oldModifierState, !isModifierKeyPressed {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    if previewCoordinator.isVisible {
                        previewCoordinator.selectAndBringToFrontCurrentWindow()
                    }
                }
            }
        }
    }

    private func showHoverWindow() {
        Task(priority: .userInitiated) { [weak self] in
            guard let self, isModifierKeyPressed else { return }

            let windows = WindowUtil.getAllWindowsOfAllApps()
            guard !windows.isEmpty else {
                print("No windows found for switcher.")
                return
            }

            let currentMouseLocation = DockObserver.getMousePosition()
            let targetScreen = getTargetScreenForSwitcher()

            await MainActor.run { [weak self] in
                guard let self else { return }
                displayHoverWindow(windows: windows,
                                   currentMouseLocation: currentMouseLocation,
                                   targetScreen: targetScreen)
            }
        }

        Task(priority: .low) { [weak self] in
            guard self != nil else { return }
            await WindowUtil.updateAllWindowsInCurrentSpace()
        }
    }

    private func displayHoverWindow(windows: [WindowInfo],
                                    currentMouseLocation: CGPoint,
                                    targetScreen: NSScreen)
    {
        if Defaults[.useClassicWindowOrdering], windows.count >= 2 {
            previewCoordinator.windowSwitcherCoordinator.setIndex(to: 1)
        }

        let showWindow = { (mouseLocation: NSPoint?, mouseScreen: NSScreen?) in
            self.previewCoordinator.showWindow(
                appName: "Window Switcher",
                windows: windows,
                mouseLocation: mouseLocation,
                mouseScreen: mouseScreen,
                dockItemElement: nil,
                overrideDelay: true,
                centeredHoverWindowState: .windowSwitcher,
                onWindowTap: { [weak self] in
                    self?.previewCoordinator.hideWindow()
                }
            )
        }

        switch Defaults[.windowSwitcherPlacementStrategy] {
        case .pinnedToScreen:
            let screenCenter = NSPoint(x: targetScreen.frame.midX,
                                       y: targetScreen.frame.midY)
            showWindow(screenCenter, targetScreen)

        case .screenWithLastActiveWindow:
            showWindow(nil, nil)

        case .screenWithMouse:
            let mouseScreen = NSScreen.screenContainingMouse(currentMouseLocation)
            let convertedMouseLocation = DockObserver.nsPointFromCGPoint(currentMouseLocation,
                                                                         forScreen: mouseScreen)
            showWindow(convertedMouseLocation, mouseScreen)
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
