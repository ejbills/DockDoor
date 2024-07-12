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
    @Default(.bufferFromDock) var bufferFromDock
    
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
            
            Divider()
            
            HStack {
                Text("Hover Window Open Delay")
                    .layoutPriority(1)
                Spacer()
                Slider(value: $hoverWindowOpenDelay, in: 0...2, step: 0.1)
                TextField("", value: $hoverWindowOpenDelay, formatter: decimalFormatter)
                    .frame(width: 38)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Text("seconds")
            }
            
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
            
            HStack {
                Text("Window Cache Lifespan")
                    .layoutPriority(1)
                Spacer()
                Slider(value: $screenCaptureCacheLifespan, in: 0...60, step: 5)
                TextField("", value: $screenCaptureCacheLifespan, formatter: NumberFormatter())
                    .frame(width: 38)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Text("seconds")
            }
            
            Picker("Preview Hover Action", selection: $previewHoverAction) {
                ForEach(PreviewHoverAction.allCases, id: \.self) { action in
                    Text(action.localizedName).tag(action)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .scaledToFit()
            
            HStack {
                Text("Preview Hover Delay")
                Spacer()
                Slider(value: $tapEquivalentInterval, in: 0...2, step: 0.1)
                TextField("", value: $tapEquivalentInterval, formatter: NumberFormatter())
                    .frame(width: 38)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Text("seconds")
            }
            .disabled(previewHoverAction == .none)
        }
        .padding(20)
        .frame(minWidth: 650)
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
                SharedPreviewWindowCoordinator.shared.windowSize = getWindowSize()
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
