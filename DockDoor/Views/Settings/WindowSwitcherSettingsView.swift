//
//  WindowSwitcherSettingsView.swift
//  DockDoor
//
//  Created by Hasan Sultan on 6/25/24.
//


import SwiftUI
import Defaults
import Carbon

class KeybindModel: ObservableObject {
    @Published var modifierKey: Int
    @Published var isRecording: Bool = false
    @Published var currentKeybind: UserKeyBind?

    init() {
        self.modifierKey = Defaults[.UserKeybind].modifierFlags
        self.currentKeybind = Defaults[.UserKeybind]
    }

}

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
                if !Defaults[.defaultCMDTABKeybind] {
                    InitializationKeyPickerView()
                }
            }
        }
        .padding(20)
        .frame(minWidth: 600)
    }
}

struct InitializationKeyPickerView: View {
    @ObservedObject var viewModel = KeybindModel()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Set Initialization Key and Keybind")
                .font(.headline)
                .padding(.top, 20)
            
            Picker("Initialization Key", selection: $viewModel.modifierKey) {
                Text("Control (⌃)").tag(Defaults[.Int64maskControl])
                Text("Option (⌥)").tag(Defaults[.Int64maskAlternate])
                Text("Command (⌘)").tag(Defaults[.Int64maskCommand])
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            Text("Press any key combination after holding the initialization key to set the keybind.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: { viewModel.isRecording = true }) {
                Text(viewModel.isRecording ? "Press the key combination..." : "Start Recording Keybind")
            }
            .keyboardShortcut(.defaultAction)
            .padding(.bottom, 20)
            
            if let keybind = viewModel.currentKeybind {
                Text("Current Keybind: \(printCurrentKeybind(keybind))")
                    .padding()
            }
        }
        .background(
            ShortcutCaptureView(
                currentKeybind: $viewModel.currentKeybind,
                isRecording: $viewModel.isRecording,
                modifierKey: $viewModel.modifierKey
            )
        )
        .onAppear {
            viewModel.currentKeybind = Defaults[.UserKeybind]
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
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
            if event.keyCode == 48 && modifierKey == Defaults[.Int64maskCommand] { // User has chosen the default Mac OS window switcher keybind
                // Set the default CMDTAB
                Defaults[.defaultCMDTABKeybind] = true
                Defaults[.UserKeybind] = UserKeyBind(keyCode: 48, modifierFlags: Defaults[.Int64maskControl])
                self.currentKeybind = Defaults[.UserKeybind]
                return event
            }
            Defaults[.UserKeybind] = UserKeyBind(keyCode: event.keyCode, modifierFlags: modifierKey)
            self.currentKeybind = Defaults[.UserKeybind]
            return nil
        }
        return view
    }
    
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}
