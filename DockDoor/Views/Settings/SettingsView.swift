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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            LaunchAtLogin.Toggle("Launch DockDoor at login")
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
    
    var body: some View {
        VStack(spacing: 20) {
            Picker("Window Size", selection: $sizingMultiplier) {
                ForEach(2...7, id: \.self) { size in
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
        .padding(.vertical, 20)
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
        default:
            return "Unknown Size"
        }
    }
}
