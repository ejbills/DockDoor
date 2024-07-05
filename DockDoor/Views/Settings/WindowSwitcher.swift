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
    @Default(.enableWindowSwitcher) var enableWindowSwitcher
    @Default(.defaultCMDTABKeybind) var defaultCMDTABKeybind
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $enableWindowSwitcher, label: {
                Text("Enable Window Switcher")
            }).onChange(of: enableWindowSwitcher){
                _, newValue in
                restartApplication()
            }
            // Default CMD + TAB implementation checkbox
            if Defaults[.enableWindowSwitcher] {
                Toggle(isOn: $defaultCMDTABKeybind, label: {
                    Text("Use default MacOS keybind ⌘ + ⇥")
                })
                // If default CMD Tab is not enabled
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
    @State var modifierKey : Int = Defaults[.Int64maskControl]
    @State var isRecording : Bool = false
    @State private var currentKeybind : UserKeyBind? {
        didSet {
            if let shortcut = currentKeybind {
                modifierKey = shortcut.modifierFlags
            }
        }
    }
    
    
    var body: some View {
        VStack(spacing: 20) {
            Picker("Modifier Key", selection: $modifierKey) {
                Text("Control (⌃)").tag(Defaults[.Int64maskControl])
                Text("Option (⌥)").tag(Defaults[.Int64maskAlternate])
                Text("Command (⌘)").tag(Defaults[.Int64maskCommand])
            }
            .pickerStyle(SegmentedPickerStyle())
            Text("Press any key combination to set the keybind").padding()
            Button(action: {self.isRecording = true}){
                Text(isRecording ? "Press key ..." : "Record keybind")
            }.keyboardShortcut(.defaultAction)
            if let keybind = currentKeybind {
                Text("Current Keybind: \(printCurrentKeybind(keybind))").padding()
            }
        }
        .background(ShortcutCaptureView(currentKeybind: $currentKeybind, isRecording: $isRecording, modifierKey: $modifierKey))
        .onAppear{
            currentKeybind = UserDefaults.standard.getKeybind()
        }
        .frame(alignment: .leading)
    }
    
    func printCurrentKeybind(_ shortcut: UserKeyBind) -> String {
        var parts: [String] = []
        parts.append(modifierConverter.toString(shortcut.modifierFlags))
        parts.append(KeyCodeConverter.toString(shortcut.keyCode))
        return parts.joined(separator: " ")
    }
    
}

struct ShortcutCaptureView: NSViewRepresentable {
    @Binding var currentKeybind: UserKeyBind?
    @Binding var isRecording: Bool
    @Binding var modifierKey: Int
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard self.isRecording else {
                return event
            }
            self.isRecording = false
            if event.keyCode == 48 && modifierKey == Defaults[.Int64maskCommand] {
                // Set the default CMDTAB
                Defaults[.defaultCMDTABKeybind] = true
                let newKeybind = UserKeyBind(keyCode: 48, modifierFlags: Defaults[.Int64maskControl])
                self.currentKeybind = newKeybind
                UserDefaults.standard.saveKeybind(newKeybind)
                return event
            }
            let newKeybind = UserKeyBind(keyCode: event.keyCode, modifierFlags: modifierKey)
            self.currentKeybind = newKeybind
            UserDefaults.standard.saveKeybind(newKeybind)
            return nil
        }
        return view
    }
    
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}
