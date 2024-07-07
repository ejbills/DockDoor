//
//  KeybindHelper.swift
//  DockDoor
//
//  Created by Ethan Bills on 6/13/24.
//

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
        let keyBoardShortcutSaved: UserKeyBind = Defaults[.UserKeybind] // UserDefaults.standard.getKeybind()!
        let shiftKeyCurrentlyPressed = event.flags.contains(.maskShift)
        var userDefinedKeyCurrentlyPressed = false

        if ((type == .flagsChanged) && (!Defaults[.defaultCMDTABKeybind])){
            // New Keybind that the user has enforced, includes the modifier keys
            if event.flags.contains(.maskControl) {
                modifierValue = Defaults[.Int64maskControl]
                userDefinedKeyCurrentlyPressed = true
            }
            else if event.flags.contains(.maskAlternate) {
                modifierValue = Defaults[.Int64maskAlternate]
                userDefinedKeyCurrentlyPressed = true
            }
            handleModifierEvent(modifierKeyPressed: userDefinedKeyCurrentlyPressed, shiftKeyPressed: shiftKeyCurrentlyPressed)
        }
        
        else if ((type == .flagsChanged) && (Defaults[.defaultCMDTABKeybind])){
            // Default MacOS CMD + TAB keybind replaced
            handleModifierEvent(modifierKeyPressed: event.flags.contains(.maskCommand), shiftKeyPressed: shiftKeyCurrentlyPressed)
        }
        
        else if (type == .keyDown){
            if (isModifierKeyPressed && keyCode == keyBoardShortcutSaved.keyCode && modifierValue == keyBoardShortcutSaved.modifierFlags) || (Defaults[.defaultCMDTABKeybind] && keyCode == 48) {  // Tab key
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
