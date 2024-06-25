//
//  WindowSwitcher.swift
//  DockDoor
//
//  Created by Hasan Sultan on 6/25/24.
//


import SwiftUI
import Defaults

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

        }
        .padding(20)
        .frame(minWidth: 600)
    }
}
