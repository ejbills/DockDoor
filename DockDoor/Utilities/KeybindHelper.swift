//
//  KeybindHelper.swift
//  DockDoor
//
//  Created by Ethan Bills on 6/13/24.
//

import AppKit
import Carbon

class KeybindHelper {
    static let shared = KeybindHelper()

    private var isControlKeyPressed = false
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

        switch type {
        case .flagsChanged:
            let modifierFlags = event.flags
            let controlKeyCurrentlyPressed = modifierFlags.contains(.maskControl)

            if controlKeyCurrentlyPressed != isControlKeyPressed { // If the state changed
                isControlKeyPressed = controlKeyCurrentlyPressed

                if isControlKeyPressed {
                    showHoverWindow()
                } else {
                    HoverWindow.shared.hideWindow()
                    HoverWindow.shared.selectAndBringToFrontCurrentWindow()
                }
            }

        case .keyDown:
            if isControlKeyPressed && keyCode == 48 { // '48' is the keyCode for Tab
                HoverWindow.shared.cycleWindows()
                return nil // Suppress the Tab key event
            }

        default:
            break
        }

        return Unmanaged.passUnretained(event)
    }

    private func showHoverWindow() {
        Task {
            let windows = await WindowUtil.activeWindows(for: "")
            DispatchQueue.main.async {
                HoverWindow.shared.showWindow(appName: "Alt-Tab", windows: windows, mouseLocation: .zero, onWindowTap: nil)
            }
        }
    }
}
