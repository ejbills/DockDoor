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
    @Default(.screenCaptureCacheLifespan) var screenCaptureCacheLifespan
    @Default(.showAnimations) var showAnimations
    @Default(.showMenuBarIcon) var showMenuBarIcon
    @Default(.uniformCardRadius) var uniformCardRadius
    
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
            
            Toggle(isOn: $uniformCardRadius, label: {
                Text("Use Uniform Image Preview Radius")
            })
            
            Toggle(isOn: $showMenuBarIcon, label: {
                Text("Show Menu Bar Icon")
            })
            .onChange(of: showMenuBarIcon) { _, isOn in
                let delegate = NSApplication.shared.delegate as! AppDelegate
                delegate.updateMenuBarIconStatus()
                
                if !isOn {
                    MessageUtil.showMessage(title: "Menu Bar Icon Hidden", message: "If you need to access the menu bar icon, launch the app to reveal it for 10 seconds.", completion: { result in
                        if result == .cancel {
                            showMenuBarIcon = true
                        }
                    })
                }
            }

            SizePickerView()
            
            HStack {
                Text("Hover Window Open Delay: \(openDelay, specifier: "%.1f") seconds")
                Spacer()
                Slider(value: $openDelay, in: 0...2, step: 0.1)
            }
            
            HStack {
                Text("Window Cache Lifespan: \(screenCaptureCacheLifespan, specifier: "%.0f") seconds")
                Spacer()
                Slider(value: $screenCaptureCacheLifespan, in: 0...60, step: 5)
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
            Picker("Window Size", selection: $sizingMultiplier) {
                ForEach(2...10, id: \.self) { size in
                    Text(getLabel(for: CGFloat(size))).tag(CGFloat(size))
                }
            }
            .onChange(of: sizingMultiplier) { _, newValue in
                HoverWindow.shared.windowSize = getWindowSize()
            }
            
            Slider(value: $windowPadding, in: -200...200, step: 20) {
                Text("Window Buffer (if misaligned with dock)")
            }.buttonStyle(PlainButtonStyle())
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
        case 10:
            return "Can you even see this?"
        default:
            return "Unknown Size"
        }
    }
}
