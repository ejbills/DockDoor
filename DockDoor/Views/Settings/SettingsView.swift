//
//  SettingsView.swift
//  DockDoor
//
//  Created by Ethan Bills on 6/13/24.
//

import SwiftUI
import Defaults
import LaunchAtLogin

struct SettingsView: View {
    @Default(.openDelay) var openDelay
    @Default(.showAnimations) var showAnimations
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Section {
                HStack {
                    Text("Want to support development?")
                    Link("Buy me a coffee here, thank you!", destination: URL(string: "https://www.buymeacoffee.com/keplercafe")!)
                }
            }
            
            Divider()
            
            LaunchAtLogin.Toggle("Launch DockDoor at login")
            Toggle(isOn: $showAnimations, label: {
                Text("Enable Hover Window Sliding Animation")
            })

            SizePickerView()
            
            HStack {
                Text("Hover Window Open Delay: \(openDelay, specifier: "%.2f") seconds")
                Spacer()
                Slider(value: $openDelay, in: 0...2, step: 0.1)
            }
        }
        .padding(20)
        .frame(minWidth: 600)
    }
}

struct SizePickerView: View {
    @Default(.sizingMultiplier) var sizingMultiplier
    @Default(.windowPadding) var windowPadding
    
    var body: some View {
        VStack(spacing: 20) {
            Slider(value: $windowPadding, in: -200...200, step: 20) {
                Text("Window Buffer (adjust if hover window is misaligned with dock)")
            }.buttonStyle(PlainButtonStyle())
            
            Picker("Window Size", selection: $sizingMultiplier) {
                ForEach(2...9, id: \.self) { size in
                    Text(getLabel(for: CGFloat(size))).tag(CGFloat(size))
                }
            }
            .onChange(of: sizingMultiplier) { _, newValue in
                MessageUtil.showMessage(title: "Restart required.", message: "Please restart the application to apply your changes. Click OK to quit the app.", completion: { result in
                    if result == .ok {
                        quitApp()
                    }
                })
            }
        }
    }
    
    private func getLabel(for size: CGFloat) -> String {
        switch size {
        case 2:
            return "Large"
        case 3:
            return "Default (Medium Large)"
        case 4:
            return "Medium"
        case 5:
            return "Small"
        case 6:
            return "Extra Small"
        case 7:
            return "Extra Extra Small"
        case 8:
            return "What is this? A window for ANTS?"
        case 9:
            return "Subatomic"
        default:
            return "Unknown Size"
        }
    }
}
