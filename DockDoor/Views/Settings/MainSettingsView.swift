//
//  MainSettingsView.swift
//  DockDoor
//
//  Created by Ethan Bills on 6/13/24.
//

import SwiftUI
import Defaults
import LaunchAtLogin

var decimalFormatter: NumberFormatter {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 1
    return formatter
}

struct MainSettingsView: View {
    @Default(.hoverWindowOpenDelay) var hoverWindowOpenDelay
    @Default(.screenCaptureCacheLifespan) var screenCaptureCacheLifespan
    @Default(.showMenuBarIcon) var showMenuBarIcon
    @Default(.tapEquivalentInterval) var tapEquivalentInterval
    @Default(.previewHoverAction) var previewHoverAction
    
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
            
            Toggle(isOn: $showMenuBarIcon, label: {
                Text("Show Menu Bar Icon")
            })
            .onChange(of: showMenuBarIcon) { _, isOn in
                let delegate = NSApplication.shared.delegate as! AppDelegate
                delegate.updateMenuBarIconStatus()
                
                if !isOn {
                    MessageUtil.showMessage(title: String(localized: "Menu Bar Icon Hidden"), message: String(localized: "If you need to access the menu bar icon, launch the app to reveal it for 10 seconds."), completion: { result in
                        if result == .cancel {
                            showMenuBarIcon = true
                        }
                    })
                }
            }
            
            HStack {
                Text("Hover Window Open Delay")
                    .layoutPriority(1)
                Spacer()
                Slider(value: $hoverWindowOpenDelay, in: 0...2, step: 0.1)
                TextField("", value: $hoverWindowOpenDelay, formatter: decimalFormatter)
                .frame(width: 40)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                Text("seconds")
            }
            
            HStack {
                Text("Window Cache Lifespan")
                    .layoutPriority(1)
                Spacer()
                Slider(value: $screenCaptureCacheLifespan, in: 0...60, step: 5)
                TextField("", value: $screenCaptureCacheLifespan, formatter: NumberFormatter())
                .frame(width: 35)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                Text("seconds")
            }
            
            HStack {
                Text("Preview Hover Delay: \(tapEquivalentInterval, specifier: "%.1f") seconds")
                Spacer()
                Slider(value: $tapEquivalentInterval, in: 0...2, step: 0.1)
            }
            
            HStack {
                Picker("Preview Hover Action", selection: $previewHoverAction) {
                    ForEach(HoverTimerActions.allCases, id: \.self) { action in
                        Text(action.localizedName).tag(action)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
        }
        .padding(20)
        .frame(minWidth: 600)
    }
}
