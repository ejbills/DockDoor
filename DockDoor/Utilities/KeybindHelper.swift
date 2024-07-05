//
//  KeybindHelper.swift
//  DockDoor
//
//  Created by Ethan Bills on 6/13/24.
//

import AppKit
import Carbon
import Defaults

struct UserKeyBind: Codable {
    var keyCode: UInt16
    var modifierFlags: Int
    
    enum CodingKeys: String, CodingKey {
        case keyCode
        case modifierFlags
    }
    
    init(keyCode: UInt16, modifierFlags: Int) {
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags
    }
    
    // Encoder
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(keyCode, forKey: .keyCode)
        try container.encode(modifierFlags, forKey: .modifierFlags)
    }
    
    // Decoder
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        keyCode = try container.decode(UInt16.self, forKey: .keyCode)
        let rawModifierFlags = try container.decode(UInt.self, forKey: .modifierFlags)
        self.modifierFlags = Int(rawModifierFlags)
    }
}
extension UserDefaults {
    private enum Keys {
        static let keyboardShortcut = "None"
    }
    
    func saveKeybind(_ shortcut: UserKeyBind) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(shortcut) {
            self.set(encoded, forKey: Keys.keyboardShortcut)
        }
    }
    
    func getKeybind() -> UserKeyBind?{
        if let savedShortcutData = self.data(forKey: Keys.keyboardShortcut){
            let decoder = JSONDecoder()
            if let savedShortcut = try? decoder.decode(UserKeyBind.self, from: savedShortcutData){
                return savedShortcut
            }
        } else {
            return self.registerDefaultKeybind()
        }
        return nil
    }
    
    func registerDefaultKeybind() -> UserKeyBind? {
        if Keys.keyboardShortcut == "None" {
            let defaultShortcut = UserKeyBind(keyCode: 48, modifierFlags: Defaults[.Int64maskControl])
            self.saveKeybind(defaultShortcut)
            return defaultShortcut
        }
        return nil
    }
}


class KeybindHelper {
    static let shared = KeybindHelper()
    private var isModifierKeyPressed = false
    private var isShiftKeyPressed = false
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
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
        
        guard let eventTap = eventTap else {
            print("Failed to create event tap.")
            return
        }
        
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }
    
    private func removeEventTap() {
        if let eventTap = eventTap, let runLoopSource = runLoopSource {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            self.eventTap = nil
            self.runLoopSource = nil
        }
    }
    
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let keyBoardShortcutSaved: UserKeyBind = UserDefaults.standard.getKeybind()!
        let userDefinedKeyCurrentlyPressed = event.flags.contains(.maskCommand) ||
        event.flags.contains(.maskControl) ||
        event.flags.contains(.maskAlternate)
        let shiftKeyCurrentlyPressed = event.flags.contains(.maskShift)
        
        if ((type == .flagsChanged) && (!Defaults[.defaultCMDTABKeybind])){
            // New Keybind that the user has enforced, includes the modifier keys
            handleModifierEvent(modifierKeyPressed: userDefinedKeyCurrentlyPressed, shiftKeyPressed: shiftKeyCurrentlyPressed)
        }
        
        else if ((type == .flagsChanged) && (Defaults[.defaultCMDTABKeybind])){
            // Default MacOS CMD + TAB keybind replaced
            handleModifierEvent(modifierKeyPressed: userDefinedKeyCurrentlyPressed, shiftKeyPressed: shiftKeyCurrentlyPressed)
        }
        
        else if (type == .keyDown){
            if (isModifierKeyPressed && keyCode == keyBoardShortcutSaved.keyCode) || (Defaults[.defaultCMDTABKeybind] && keyCode == 48) {  // Tab key
                if HoverWindow.shared.isVisible {  // Check if HoverWindow is already shown
                    HoverWindow.shared.cycleWindows(goBackwards: isShiftKeyPressed)  // Cycle windows based on Shift key state
                } else {
                    showHoverWindow()  // Initialize HoverWindow if it's not open
                }
                return nil  // Suppress the Tab key event
            }
        }
        
        return Unmanaged.passUnretained(event)
    }
    
    private func handleModifierEvent(modifierKeyPressed : Bool, shiftKeyPressed : Bool){
        if modifierKeyPressed != isModifierKeyPressed {
            isModifierKeyPressed = modifierKeyPressed
        }
        // Update the state of Shift key
        if shiftKeyPressed != isShiftKeyPressed {
            isShiftKeyPressed = shiftKeyPressed
        }
        
        if !isModifierKeyPressed {
            HoverWindow.shared.hideWindow()  // Hide the HoverWindow
            HoverWindow.shared.selectAndBringToFrontCurrentWindow()
        }
    }
    
    private func showHoverWindow() {
        Task { [weak self] in
            do {
                guard let self = self else { return }
                let windows = try await WindowUtil.activeWindows(for: "")
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    if self.isModifierKeyPressed {
                        HoverWindow.shared.showWindow(appName: "Alt-Tab", windows: windows, overrideDelay: true, onWindowTap: { HoverWindow.shared.hideWindow() })
                    }
                }
            } catch {
                print("Error fetching active windows: \(error)")
            }
        }
    }
}
