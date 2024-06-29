//
//  WindowSwitcher.swift
//  DockDoor
//
//  Created by Hasan Sultan on 6/25/24.
//


import SwiftUI
import Defaults
import Cocoa

struct WindowSwitcherSettingsView: View {
    @Default(.showWindowSwitcher) var showWindowSwitcher
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $showWindowSwitcher, label: {
                Text("Enable Window Switcher")
            }).onChange(of: showWindowSwitcher){
                _, newValue in
                restartApplication()
            }
            // Default CMD + TAB implementation checkbox
            ModifierKeyPickerView()
        }
        .padding(20)
        .frame(minWidth: 600)
    }
}

struct ModifierKeyPickerView : View {
    @State var modifierKey : String = ""
    var body: some View {
        VStack(spacing: 20) {
            Picker("Modifier Key", selection: $modifierKey) {
                ForEach(1...5, id: \.self) { modifierKeyId in
                    Text(printModifierKey(for: modifierKeyId)).tag(modifierKeyId)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: modifierKey) { _, newValue in
                // Change to the implementation here
            }
        }
    }
    
    private func printModifierKey(for key: Int) -> String {
        // Switch statement for presenting all the keys
        switch key {
        case 1:
            return "Shift"
        case 2:
            return "Control"
        case 3:
            return "Option"
        case 4:
            return "Caps Lock"
        default:
            return "Command"
        }
    }
}
