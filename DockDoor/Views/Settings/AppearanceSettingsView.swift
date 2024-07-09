//
//  AppearanceSettingsView.swift
//  DockDoor
//
//  Created by ShlomoCode on 09/07/2024.
//

import SwiftUI
import Defaults
import LaunchAtLogin

struct AppearanceSettingsView: View {
    @Default(.showAnimations) var showAnimations
    @Default(.uniformCardRadius) var uniformCardRadius
    @Default(.hoverTitleStyle) var hoverTitleStyle
    @Default(.windowPadding) var windowPadding
    @Default(.windowTitleAlignment) var windowTitleAlignment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $showAnimations, label: {
                Text("Enable Hover Window Sliding Animation")
            })
            
            Toggle(isOn: $uniformCardRadius, label: {
                Text("Use Uniform Image Preview Radius")
            })
            
            Slider(value: $windowPadding, in: -200...200, step: 20) {
                Text("Window Buffer (if misaligned with dock)")
            }.buttonStyle(PlainButtonStyle())
            
            SizePickerView()
            
            Picker("Hover Window Title Style", selection: $hoverTitleStyle) {
                ForEach(HoverView.TitleStyle.allCases, id: \.self) { style in
                    Text(style.titleString)
                        .tag(style.rawValue)
                }
            }
            
            Picker("Window Title Alignment", selection: $windowTitleAlignment) {
                Text("Left").tag(true)
                Text("Right").tag(false)
            }
            .pickerStyle(SegmentedPickerStyle())
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
        }
    }
    
    private func getLabel(for size: CGFloat) -> String {
        switch size {
        case 2:
            return String(localized: "Large", comment: "Window size option")
        case 3:
            return String(localized: "Default (Medium Large)", comment: "Window size option")
        case 4:
            return String(localized:"Medium", comment: "Window size option")
        case 5:
            return String(localized:"Small", comment: "Window size option")
        case 6:
            return String(localized:"Extra Small", comment: "Window size option")
        case 7:
            return String(localized:"Extra Extra Small", comment: "Window size option")
        case 8:
            return String(localized:"What is this? A window for ANTS?", comment: "Window size option")
        case 9:
            return String(localized:"Subatomic", comment: "Window size option")
        case 10:
            return String(localized:"Can you even see this?", comment: "Window size option")
        default:
            return "Unknown Size"
        }
    }
}
