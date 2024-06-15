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

            HStack(spacing: 10) {
                ForEach(1...7, id: \.self) { size in
                    Button(action: {
                        sizingMultiplier = CGFloat(size)
                        MessageUtil.showMessage(title: "Restart required.", message: "Please restart the application to apply your changes. Click OK to quit the app.", completion: { _ in quitApp() })
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .frame(width: CGFloat(100 / size), height: CGFloat(100 / size))

                            Text("\(size)")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                }
            }
        }
        .padding()
    }
}

