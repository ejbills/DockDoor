//
//  SettingsView.swift
//  DockDoor
//
//  Created by Ethan Bills on 6/13/24.
//

import SwiftUI
import Defaults

struct SettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            SizePickerView()
        }
        .padding()
    }
}

struct SizePickerView: View {
    @Default(.sizingMultiplier) var sizingMultiplier

    var body: some View {
        VStack {
            Text("Select Size:")
                .font(.headline)

            Picker("Size", selection: $sizingMultiplier) {
                ForEach(2...7, id: \.self) { size in
                    Text("\(size)").tag(CGFloat(size))
                }
            }
            .pickerStyle(MenuPickerStyle())
            .onChange(of: sizingMultiplier) { _, newValue in
                MessageUtil.showMessage(title: "Restart required.", message: "Please restart the application to apply your changes. Click OK to quit the app.", completion: { _ in quitApp() })
            }

            Text("Current Size: \(Int(sizingMultiplier))")
                .font(.subheadline)
                .padding(.top, 10)
        }
        .padding()
    }
}

