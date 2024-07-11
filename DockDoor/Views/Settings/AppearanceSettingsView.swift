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
    @Default(.windowTitleStyle) var windowTitleStyle
    @Default(.bufferFromDock) var bufferFromDock
    @Default(.windowTitlePosition) var windowTitlePosition
    @Default(.showWindowTitle) var showWindowTitle
    @Default(.windowTitleDisplayCondition) var windowTitleDisplayCondition
    @Default(.trafficLightButtonsVisibility) var trafficLightButtonsVisibility
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $showAnimations, label: {
                Text("Enable Hover Window Sliding Animation")
            })
            
            Toggle(isOn: $uniformCardRadius, label: {
                Text("Use Uniform Image Preview Radius")
            })
            
            VStack(alignment: .leading){
                HStack {
                    Slider(value: $bufferFromDock, in: -200...200, step: 20) {
                        Text("Window Buffer")
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: 400)
                    TextField("", value: $bufferFromDock, formatter: NumberFormatter())
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 50)
                }
                Text("Adjust this if the preview is misaligned with dock")
                    .font(.footnote)
                    .foregroundColor(.gray)
            }
            
            SizePickerView()
            
            Picker("Hover Window Title Style", selection: $windowTitleStyle) {
                ForEach(WindowTitleStyle.allCases, id: \.self) { style in
                    Text(style.localizedName)
                        .tag(style.rawValue)
                }
            }
            .scaledToFit()
            
            Toggle(isOn: $showWindowTitle) {
                Text("Show Window Titles on Previews")
            }
            
            Group {
                Picker("Show Window Titles", selection: $windowTitleDisplayCondition) {
                    ForEach(WindowTitleDisplayCondition.allCases, id: \.self) { condtion in
                        if condtion == .always {
                            Text(condtion.localizedName).tag(condtion)
                            Divider() // Separate from Window Switcher & Dock Previews
                        } else {
                            Text(condtion.localizedName).tag(condtion)
                        }
                    }
                }
                .scaledToFit()
                
                Picker("Window Title Position", selection: $windowTitlePosition) {
                    ForEach(WindowTitlePosition.allCases, id: \.self) { position in
                        Text(position.localizedName).tag(position).scaledToFit()
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            .disabled(!showWindowTitle)
            
            Picker("Traffic Light Buttons Visibility", selection: $trafficLightButtonsVisibility) {
                ForEach(TrafficLightButtonsVisibility.allCases, id: \.self) { visibility in
                    Text(visibility.localizedName)
                        .tag(visibility.rawValue)
                }
            }
            .scaledToFit()
        }
        .padding(20)
        .frame(minWidth: 600)
    }
}

struct SizePickerView: View {
    @Default(.sizingMultiplier) var sizingMultiplier
    @Default(.bufferFromDock) var bufferFromDock
    
    var body: some View {
        VStack(spacing: 20) {
            Picker("Window Size", selection: $sizingMultiplier) {
                ForEach(2...10, id: \.self) { size in
                    Text(getLabel(for: CGFloat(size))).tag(CGFloat(size))
                }
            }
            .scaledToFit()
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
