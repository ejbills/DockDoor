import AppKit
import Carbon
import Defaults

struct UserKeyBind: Codable, Defaults.Serializable {
    var keyCode: UInt16
    var modifierFlags: Int
}

class KeybindHelper {
    static let shared = KeybindHelper()

    // MARK: - Properties

    private var isModifierKeyPressed = false
    private var isShiftKeyPressed = false
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var modifierValue: Int = 0
    private var monitorTimer: Timer?

    // MARK: - Initialization

    private init() {
        setupEventTap()
        startMonitoring()
    }

    deinit {
        cleanup()
    }

    // MARK: - Public Methods

    func reset() {
        cleanup()
        resetState()
        setupEventTap()
        startMonitoring()
    }

    // MARK: - Private Methods

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
        KeybindHelper.shared.handleEvent(proxy: proxy, type: type, event: event)
    }

    private func setupEventTap() {
        let eventMask = (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)

        guard let newEventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: KeybindHelper.eventCallback,
            userInfo: nil
        ) else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
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
        if SharedPreviewWindowCoordinator.shared.isVisible, keyCode == 53 { // Escape key
            SharedPreviewWindowCoordinator.shared.hideWindow()
            return true
        }

        if isModifierKeyPressed,
           keyCode == keyBoardShortcutSaved.keyCode,
           modifierValue == keyBoardShortcutSaved.modifierFlags
        {
            handleKeybindActivation()
            return true
        }

        return false
    }

    private func handleKeybindActivation() {
        if SharedPreviewWindowCoordinator.shared.isVisible {
            SharedPreviewWindowCoordinator.shared.cycleWindows(goBackwards: isShiftKeyPressed)
        } else {
            showHoverWindow()
        }
    }

    private func handleModifierEvent(modifierKeyPressed: Bool, shiftKeyPressed: Bool) {
        isModifierKeyPressed = modifierKeyPressed
        isShiftKeyPressed = shiftKeyPressed

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if !isModifierKeyPressed, SharedPreviewWindowCoordinator.shared.isVisible {
                SharedPreviewWindowCoordinator.shared.selectAndBringToFrontCurrentWindow()
            }
        }
    }

    private func showHoverWindow() {
        DispatchQueue.main.async { [weak self] in
            guard let self, isModifierKeyPressed else { return }

            let windows = WindowUtil.getAllWindowsOfAllApps()
            let currentMouseLocation = DockObserver.getMousePosition()
            let targetScreen = getTargetScreenForSwitcher()

            displayHoverWindow(windows: windows,
                               currentMouseLocation: currentMouseLocation,
                               targetScreen: targetScreen)
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
        // If classic window ordering is enabled and there are at least two windows,
        // set the initial focus on the second window preview (instead of the first).
        //
        // This behavior improves window switching speed and mimics the Windows OS
        // experience, making it easier for users to switch between recent windows quickly.
        if Defaults[.useClassicWindowOrdering], windows.count >= 2 {
            SharedPreviewWindowCoordinator.shared.windowSwitcherCoordinator.setIndex(to: 1)
        }

        let showWindow = { (mouseLocation: NSPoint?, mouseScreen: NSScreen?) in
            SharedPreviewWindowCoordinator.shared.showWindow(
                appName: "Window Switcher",
                windows: windows,
                mouseLocation: mouseLocation,
                mouseScreen: mouseScreen,
                iconRect: nil,
                overrideDelay: true,
                centeredHoverWindowState: .windowSwitcher,
                onWindowTap: {
                    SharedPreviewWindowCoordinator.shared.hideWindow()
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
