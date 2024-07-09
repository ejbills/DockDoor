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
    @Default(.hoverTitleStyle) var hoverTitleStyle
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Section {
                HStack {
                    Text("Want to support development?")
                    Link("Buy me a coffee here, thank you!", destination: URL(string: "https://www.buymeacoffee.com/keplercafe")!)
                }
            }
            
            Divider()
            
            LaunchAtLogin.Toggle(String(localized: "Launch DockDoor at login"))
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
            
            Picker("Hover Window Title Style", selection: $hoverTitleStyle) {
                ForEach(HoverView.TitleStyle.allCases, id: \.self) { style in
                    Text(style.titleString)
                        .tag(style.rawValue)
                }
            }
            
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
            return String(localized: "Large", comment: "Window Size Option")
        case 3:
            return String(localized: "Default (Medium Large)", comment: "Window Size Option")
        case 4:
            return String(localized:"Medium", comment: "Window Size Option")
        case 5:
            return String(localized:"Small", comment: "Window Size Option")
        case 6:
            return String(localized:"Extra Small", comment: "Window Size Option")
        case 7:
            return String(localized:"Extra Extra Small", comment: "Window Size Option")
        case 8:
            return String(localized:"What is this? A window for ANTS?", comment: "Window Size Option")
        case 9:
            return String(localized:"Subatomic", comment: "Window Size Option")
        case 10:
            return String(localized:"Can you even see this?", comment: "Window Size Option")
        default:
            return "Unknown Size"
        }
    }
}
