//
//  WindowSwitcher.swift
//  DockDoor
//
//  Created by Hasan Sultan on 6/25/24.
//


import SwiftUI
import Defaults
import Carbon

struct WindowSwitcherSettingsView: View {
    @Default(.showWindowSwitcher) var showWindowSwitcher
    @Default(.defaultCMDTABKeybind) var defaultCMDTABKeybind
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $showWindowSwitcher, label: {
                Text("Enable Window Switcher")
            }).onChange(of: showWindowSwitcher){
                _, newValue in
                restartApplication()
            }
            // Default CMD + TAB implementation checkbox
            if (Defaults[.showWindowSwitcher]){
                Toggle(isOn: $defaultCMDTABKeybind, label: {
                    Text("Use Default MacOS keybind ⌘ + Tab")
                }).onChange(of: defaultCMDTABKeybind){
                    _, newValue in
                }
                // If default is not enabled
                if !Defaults[.defaultCMDTABKeybind]{
                    ModifierKeyPickerView()
                }
            }
        }
        .padding(20)
        .frame(minWidth: 600)
    }
}

struct ModifierKeyPickerView : View {
    @State var modifierKey : Int = CGEventFlags.Int64maskAlphaShift //NSEvent.ModifierFlags.RawValue = NSEvent.ModifierFlags.command.rawValue
    @State var isRecording : Bool = false
    @State private var currentShortcut : UserKeyboardShortcut? {
        didSet {
            if let shortcut = currentShortcut {
                modifierKey = shortcut.modifierFlags
            }
        }
    }
    
    
    var body: some View {
        VStack(spacing: 20) {
            Picker("Modifier Key", selection: $modifierKey) {
                Text("Control (⌃)").tag(CGEventFlags.Int64maskControl)
                Text("Option (⌥)").tag(CGEventFlags.Int64maskAlternate)
                Text("Caps Lock").tag(CGEventFlags.Int64maskAlphaShift)
                Text("Command (⌘)").tag(CGEventFlags.Int64maskCommand)
            }
            .pickerStyle(SegmentedPickerStyle())
            Text("Press any key combination to set the keybind").padding()
            Button(action: {self.isRecording = true}){
                Text(isRecording ? "Press shortcut ..." : "Record shortcut")
            }.keyboardShortcut(.defaultAction)
            if let shortcut = currentShortcut {
                Text("Current Keybind: \(shortcutDescription(shortcut))").padding()
            }
        }
        .background(ShortcutCaptureView(currentShortcut: $currentShortcut, isRecording: $isRecording, modifierKey: $modifierKey))
        .onAppear{
            currentShortcut = UserDefaults.standard.getKeyboardShortcut()
        }
        .frame(alignment: .leading)
    }
    
    func shortcutDescription(_ shortcut: UserKeyboardShortcut) -> String {
        
        var parts: [String] = []
        
        if shortcut.modifierFlags == CGEventFlags.Int64maskCommand {
            parts.append("⌘")
        }
        if shortcut.modifierFlags == Int(CGEventFlags.Int64maskAlternate) {
            parts.append("⌥")
        }
        if shortcut.modifierFlags == CGEventFlags.Int64maskControl {
            parts.append("⌃")
        }
        if shortcut.modifierFlags == CGEventFlags.Int64maskAlphaShift {
            parts.append("Caps Lock")
        }
        
        parts.append(String(describing: KeyCodeConverter.string(from: shortcut.keyCode)))
        
        return parts.joined(separator: " ")
    }
    
}

struct ShortcutCaptureView: NSViewRepresentable {
    @Binding var currentShortcut: UserKeyboardShortcut?
    @Binding var isRecording: Bool
    @Binding var modifierKey: Int
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard self.isRecording else {
                return event
            }
            self.isRecording = false
            if (event.keyCode == 48) && ( modifierKey == 1048840){
                // Set the default CMDTAB
                Defaults[.defaultCMDTABKeybind] = true
                let newShortcut = UserKeyboardShortcut(keyCode: 48, modifierFlags: 65792)
                self.currentShortcut = newShortcut
                UserDefaults.standard.saveKeyboardShortcut(newShortcut)
                return event
            }
            let newShortcut = UserKeyboardShortcut(keyCode: event.keyCode, modifierFlags: modifierKey)
            self.currentShortcut = newShortcut
            UserDefaults.standard.saveKeyboardShortcut(newShortcut)
            return nil
        }
        return view
    }
    
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}


struct KeyCodeConverter {
    static func string(from keyCode: UInt16) -> String {
        switch keyCode {
        case 48:
            return "⇥" // Tab symbol
        case 51:
            return "⌫" // Delete symbol
        case 53:
            return "⎋" // Escape symbol
        case 36:
            return "↩︎" // Return symbol
        default:
            
            let source = TISCopyCurrentKeyboardInputSource().takeUnretainedValue()
            let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
            
            guard let data = layoutData else {
                return "?"
            }
            
            let layout = unsafeBitCast(data, to: CFData.self)
            let keyboardLayout = unsafeBitCast(CFDataGetBytePtr(layout), to: UnsafePointer<UCKeyboardLayout>.self)
            
            var keysDown: UInt32 = 0
            var chars = [UniChar](repeating: 0, count: 4)
            var realLength: Int = 0
            
            let result = UCKeyTranslate(keyboardLayout,
                                        keyCode,
                                        UInt16(kUCKeyActionDisplay),
                                        0,
                                        UInt32(LMGetKbdType()),
                                        UInt32(kUCKeyTranslateNoDeadKeysBit),
                                        &keysDown,
                                        chars.count,
                                        &realLength,
                                        &chars)
            
            if result == noErr {
                return String(utf16CodeUnits: chars, count: realLength)
            } else {
                return "?"
            }
        }
    }
}
