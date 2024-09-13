import AppKit
import Carbon
import Defaults

struct UserKeyBind: Codable, Defaults.Serializable {
    var keyCode: UInt16
    var modifierFlags: Int
}

class KeybindHelper {
    static let shared = KeybindHelper()
    private var isModifierKeyPressed = false
    private var isShiftKeyPressed = false
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var modifierValue: Int = 0

    private init() {
        setupEventTap()
    }

    deinit {
        removeEventTap()
    }

    private func setupEventTap() {
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                return KeybindHelper.shared.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: nil
        )

        guard let eventTap else {
            print("Failed to create event tap.")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    private func removeEventTap() {
        if let eventTap, let runLoopSource {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            self.eventTap = nil
            self.runLoopSource = nil
        }
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let keyBoardShortcutSaved: UserKeyBind = Defaults[.UserKeybind]
        let shiftKeyCurrentlyPressed = event.flags.contains(.maskShift)
        var userDefinedKeyCurrentlyPressed = false

        if type == .flagsChanged {
            // New Keybind that the user has enforced, includes the modifier keys
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
            handleModifierEvent(modifierKeyPressed: userDefinedKeyCurrentlyPressed, shiftKeyPressed: shiftKeyCurrentlyPressed)
        } else if type == .keyDown {
            if SharedPreviewWindowCoordinator.shared.isVisible, keyCode == 53 { // Escape key
                SharedPreviewWindowCoordinator.shared.hideWindow()
                return nil // Suppress the Escape key event
            }

            if isModifierKeyPressed, keyCode == keyBoardShortcutSaved.keyCode, modifierValue == keyBoardShortcutSaved.modifierFlags { // Tab key
                if SharedPreviewWindowCoordinator.shared.isVisible { // Check if HoverWindow is already shown
                    SharedPreviewWindowCoordinator.shared.cycleWindows(goBackwards: isShiftKeyPressed) // Cycle windows based on Shift key state
                } else {
                    showHoverWindow() // Initialize HoverWindow if it's not open
                }
                return nil // Suppress the Tab key event
            }
        }

        return Unmanaged.passUnretained(event)
    }

    private func handleModifierEvent(modifierKeyPressed: Bool, shiftKeyPressed: Bool) {
        if modifierKeyPressed != isModifierKeyPressed {
            isModifierKeyPressed = modifierKeyPressed
        }
        // Update the state of Shift key
        if shiftKeyPressed != isShiftKeyPressed {
            isShiftKeyPressed = shiftKeyPressed
        }

        if !isModifierKeyPressed {
            SharedPreviewWindowCoordinator.shared.hideWindow()
            SharedPreviewWindowCoordinator.shared.selectAndBringToFrontCurrentWindow()
        }
    }

    private func showHoverWindow() {
        // Show window immediately on the main thread
        DispatchQueue.main.async { [weak self] in
            guard let self, isModifierKeyPressed else { return }

            let windows = WindowUtil.getAllWindowsOfAllApps()

            SharedPreviewWindowCoordinator.shared.showWindow(
                appName: "Window Switcher",
                windows: windows,
                iconRect: nil,
                overrideDelay: true,
                centeredHoverWindowState: .windowSwitcher,
                onWindowTap: { SharedPreviewWindowCoordinator.shared.hideWindow() }
            )
        }

        Task(priority: .high) { [weak self] in
            guard self != nil else { return }
            await WindowUtil.updateAllWindowsInCurrentSpace()
        }
    }
}
