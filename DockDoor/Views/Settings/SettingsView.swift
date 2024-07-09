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
    @Default(.showMenuBarIcon) var showMenuBarIcon
    
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
