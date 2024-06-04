//
//  ContentView.swift
//  DockDoor
//
//  Created by Ethan Bills on 6/3/24.
//

import SwiftUI

struct ContentView: View {
    @State private var applicationWindows: [String: [WindowInfo]] = [:]
    @State private var selectedApplication: String?

    var body: some View {
        NavigationView {
            List(Array(applicationWindows.keys), id: \.self) { appName in
                Button(appName) {
                    selectedApplication = appName
                }
            }
            .navigationTitle("Applications")
            .onAppear {
                Task {
                    applicationWindows = await WindowUtil.listDockApplicationWindows()
                }
            }

            if let selectedApp = selectedApplication, let windows = applicationWindows[selectedApp] {
                WindowListView(windows: windows)
            } else {
                Text("Select an application to view its windows.")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

struct WindowListView: View {
    var windows: [WindowInfo]

    var body: some View {
        List(windows, id: \.id) { windowInfo in
            WindowView(windowInfo: windowInfo)
                .frame(height: 200)
                .padding()
        }
    }
}

struct WindowView: View {
    let windowInfo: WindowInfo
    @State private var image: Image?

    var body: some View {
        VStack {
            if let image = image {
                Button(action: {
                    WindowUtil.bringWindowToFront(windowInfo: windowInfo)
                }) {
                    image
                        .resizable()
                        .scaledToFit()
                }
            } else {
                Text("Loading...")
                    .onAppear {
                        Task {
                            do {
                                let cgImage = try await WindowUtil().captureWindowImage(windowInfo: windowInfo)
                                image = Image(decorative: cgImage, scale: 1.0)
                            } catch {
                                print("Error capturing window image: \(error)")
                            }
                        }
                    }
            }
        }
    }
}
