//
//  HoverWindow.swift
//  DockDoor
//
//  Created by Ethan Bills on 6/5/24.
//

import Cocoa
import SwiftUI

class HoverWindow: NSWindow {
    let appName: String
    let onWindowTap: (() -> Void)?

    init(appName: String, windows: [WindowInfo], onWindowTap: (() -> Void)? = nil) {
        self.appName = appName
        self.onWindowTap = onWindowTap
        // Ensure the closure is passed to HoverView
        let hoverView = NSHostingView(rootView: HoverView(appName: appName, windows: windows, onWindowTap: onWindowTap))
        
        // Initialize the NSWindow
        super.init(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: true)

        // Set window level and make it clickable
        level = .statusBar + 1
        isMovableByWindowBackground = true

        // Set the content view
        contentView = hoverView
    }
}


struct HoverView: View {
    let appName: String
    let windows: [WindowInfo]
    let onWindowTap: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading) {
            ForEach(windows) { window in
                WindowPreview(windowInfo: window, onTap: onWindowTap)
            }
        }
        .padding()
        .background(.thinMaterial)
        .cornerRadius(10)
    }
}

struct WindowPreview: View {
    let windowInfo: WindowInfo
    let onTap: (() -> Void)?
    @State private var image: Image? = nil
    @State private var imageSize: CGSize = .zero

    var body: some View {
        VStack {
            if let image = image {
                Button(action: {
                    WindowUtil.bringWindowToFront(windowInfo: windowInfo)
                    onTap?()
                }) {
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: min(imageSize.width, roughWidthCap), height: min(imageSize.height, roughHeightCap), alignment: .center)
                }
            } else {
                ProgressView()
                    .frame(width: 300, height: 200)  // Placeholder size
                    .onAppear {
                        loadWindowImage()
                    }
            }

            if let name = windowInfo.windowName {
                Text(name)
                    .padding(4)
                    .cornerRadius(5)
            }
        }
        .cornerRadius(5)
    }

    private func loadWindowImage() {
        Task {
            do {
                let cgImage = try await WindowUtil().captureWindowImage(windowInfo: windowInfo)
                print("Captured Image Size in WindowPreview: \(cgImage.width) x \(cgImage.height)")  // Debug print
                DispatchQueue.main.async {
                    image = Image(decorative: cgImage, scale: 1.0)
                    imageSize = CGSize(width: cgImage.width, height: cgImage.height)
                }
            } catch {
                print("Error capturing window image: \(error)")
            }
        }
    }

    private func updateWindowSize(_ size: CGSize) {
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first(where: { $0 is HoverWindow }) {
                window.setContentSize(size)
            }
        }
    }
}
