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
    @Default(.showAppName) var showAppName
    @Default(.appNameStyle) var appNameStyle
    @Default(.showWindowTitle) var showWindowTitle
    @Default(.windowTitleDisplayCondition) var windowTitleDisplayCondition
    @Default(.windowTitleVisibility) var windowTitleVisibility
    @Default(.windowTitlePosition) var windowTitlePosition
    @Default(.trafficLightButtonsVisibility) var trafficLightButtonsVisibility
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $showAnimations, label: {
                Text("Enable Hover Window Sliding Animation")
            })
            
            Toggle(isOn: $uniformCardRadius, label: {
                Text("Use Uniform Image Preview Radius")
            })
            
            Picker("Traffic Light Buttons Visibility", selection: $trafficLightButtonsVisibility) {
                ForEach(TrafficLightButtonsVisibility.allCases, id: \.self) { visibility in
                    Text(visibility.localizedName)
                        .tag(visibility)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .scaledToFit()
            .layoutPriority(1)
            
            Divider()
            
            Toggle(isOn: $showAppName) {
                Text("Show App Name in Dock Previews")
            }
            
            Picker(String(localized: "App Name Style"), selection: $appNameStyle) {
                ForEach(AppNameStyle.allCases, id: \.self) { style in
                    Text(style.localizedName)
                        .tag(style)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .scaledToFit()
            .layoutPriority(1)
            .disabled(!showAppName)
            
            Divider()
            
            Toggle(isOn: $showWindowTitle) {
                Text("Show Window Title in Previews")
            }
            
            Group {
                Picker("Show Window Title in", selection: $windowTitleDisplayCondition) {
                    ForEach(WindowTitleDisplayCondition.allCases, id: \.self) { condtion in
                        if condtion == .all {
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
                
                Picker("Window Title Visibility", selection: $windowTitleVisibility) {
                                    ForEach(WindowTitleVisibility.allCases, id: \.self) { visibility in
                                        Text(visibility.localizedName)
                                            .tag(visibility)
                                    }
                                }
                                .scaledToFit()
                                .pickerStyle(MenuPickerStyle())
                
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
