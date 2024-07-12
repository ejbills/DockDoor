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
            
            Picker("Hover Window Title Style", selection: $windowTitleStyle) {
                ForEach(WindowTitleStyle.allCases, id: \.self) { style in
                    Text(style.localizedName)
                        .tag(style)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .scaledToFit()
            .layoutPriority(1)
            
            Picker("Traffic Light Buttons Visibility", selection: $trafficLightButtonsVisibility) {
                ForEach(TrafficLightButtonsVisibility.allCases, id: \.self) { visibility in
                    Text(visibility.localizedName)
                        .tag(visibility)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .scaledToFit()
            
            Divider()
            
            Toggle(isOn: $showWindowTitle) {
                Text("Show Window Titles on Previews")
            }
            
            Group {
                Picker("Show Window Titles", selection: $windowTitleDisplayCondition) {
                    ForEach(WindowTitleDisplayCondition.allCases, id: \.self) { condtion in
                        if condtion == .always {
                            Text(condtion.localizedName)
                                .tag(condtion)
                            Divider() // Separate from Window Switcher & Dock Previews
                        } else {
                            Text(condtion.localizedName)
                                .tag(condtion)
                        }
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .scaledToFit()
                
                Picker("Window Title Position", selection: $windowTitlePosition) {
                    ForEach(WindowTitlePosition.allCases, id: \.self) { position in
                        Text(position.localizedName)
                            .tag(position)
                    }
                }
                .scaledToFit()
                .pickerStyle(SegmentedPickerStyle())
            }
            .disabled(!showWindowTitle)
        }
        .padding(20)
        .frame(minWidth: 650)
    }
}
