//
//  HoverWindow.swift
//  DockDoor
//
//  Created by Ethan Bills on 6/5/24.
//

import Cocoa
import SwiftUI

class HoverWindow: NSWindow {
    static let shared = HoverWindow()
    
    private var appName: String = ""
    private var windows: [WindowInfo] = []
    private var onWindowTap: (() -> Void)?
    
    private init() {
        super.init(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        level = .floating
        isMovableByWindowBackground = true // Allow dragging from anywhere
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary] // Show in all spaces and on top of fullscreen apps
        backgroundColor = .clear // Make window background transparent
        hasShadow = false // Remove shadow
        
        // Set up tracking area for mouse exit detection
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
        let trackingArea = NSTrackingArea(rect: self.frame, options: options, owner: self, userInfo: nil)
        contentView?.addTrackingArea(trackingArea)
    }
    
    // Method to configure and show the window
    func showWindow(appName: String, windows: [WindowInfo], mouseLocation: CGPoint, onWindowTap: (() -> Void)? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.appName = appName
            self.windows = windows
            self.onWindowTap = onWindowTap
            
            let hoverView = NSHostingView(rootView: HoverView(appName: appName, windows: windows, onWindowTap: onWindowTap))
            self.contentView = hoverView
            
            self.updateContentViewSizeAndPosition(mouseLocation: mouseLocation) // Recalculate size and position
            self.makeKeyAndOrderFront(nil)
        }
    }
    
    // Method to hide the window
    func hideWindow() {
        DispatchQueue.main.async { [weak self] in
            self?.orderOut(nil)
        }
    }
    
    // Mouse exited tracking area - hide the window
    override func mouseExited(with event: NSEvent) {
        hideWindow()
    }
    
    // Calculate hover window's size and position based on content and mouse location
    private func updateContentViewSizeAndPosition(mouseLocation: CGPoint) {
        guard let contentView = contentView else { return }
        guard !self.windows.isEmpty else {
            hideWindow()
            return
        }
        
        // Update content view based on new data
        let hoverView = contentView as! NSHostingView<HoverView>
        hoverView.rootView = HoverView(appName: self.appName, windows: self.windows, onWindowTap: self.onWindowTap)
        
        let hoverWindowSize = contentView.fittingSize
        
        // Calculate hover window origin
        var hoverWindowOrigin = mouseLocation
        let screen = screenContainingPoint(mouseLocation)
        let screenFrame = screen?.frame ?? .zero // Get the full screen area of the screen containing the mouse
        let dockPosition = DockUtils.shared.getDockPosition() // Get dock position
        let dockHeight = DockUtils.shared.calculateDockHeight(screen) // Get dock height
        
        // Position window above/below dock depending on position
        switch dockPosition {
        case .bottom:
            hoverWindowOrigin.y = dockHeight
        case .left, .right:
            hoverWindowOrigin.y -= hoverWindowSize.height / 2
            
            if dockPosition == .left {
                hoverWindowOrigin.x = screenFrame.minX + dockHeight
            } else { // dockPosition == .right
                hoverWindowOrigin.x = screenFrame.maxX - hoverWindowSize.width - dockHeight
            }
        case .unknown:
            // No action needed, retain the default or current position.
            break
        }
        
        // Adjust horizontal position if the window is wider than the screen and the dock is on the side
        if dockPosition == .left || dockPosition == .right, hoverWindowSize.width > screenFrame.width - dockHeight {
            hoverWindowOrigin.x = dockPosition == .left ? 0 : screenFrame.width - hoverWindowSize.width
        }
        
        // Center the window horizontally if the dock is at the bottom
        if dockPosition == .bottom {
            hoverWindowOrigin.x -= hoverWindowSize.width / 2
        }
        
        // Ensure the window stays within screen bounds
        hoverWindowOrigin.x = max(screenFrame.minX, min(hoverWindowOrigin.x, screenFrame.maxX - hoverWindowSize.width))
        hoverWindowOrigin.y = max(screenFrame.minY, min(hoverWindowOrigin.y, screenFrame.maxY - hoverWindowSize.height))
        
        setFrameOrigin(hoverWindowOrigin)
        setContentSize(hoverWindowSize)
    }
    
    // Helper method to find the screen containing a given point
    private func screenContainingPoint(_ point: CGPoint) -> NSScreen? {
        return NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
    }
}

struct HoverView: View {
    let appName: String
    let windows: [WindowInfo]
    let onWindowTap: (() -> Void)?
    
    @State private var showWindows: Bool = false
    
    var body: some View {
        HStack {
            ForEach(windows.indices, id: \.self) { index in
                WindowPreview(windowInfo: windows[index], onTap: onWindowTap)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.3)) {
                showWindows = true
            }
        }
        .scaleEffect(showWindows ? 1 : 0.90)
        .opacity(showWindows ? 1 : 0.8)
    }
}

struct WindowPreview: View {
    let windowInfo: WindowInfo
    let onTap: (() -> Void)?
    
    @State private var isHovering = false
    
    var body: some View {
        VStack {
            if let cgImage = windowInfo.image {
                let image = Image(decorative: cgImage, scale: 1.0)
                let aspectRatio = CGFloat(cgImage.width) / CGFloat(cgImage.height)
                
                image
                    .resizable()
                    .aspectRatio(aspectRatio, contentMode: .fit)
                    .frame(maxWidth: roughWidthCap, maxHeight: roughHeightCap)
                    .scaleEffect(isHovering ? 0.95 : 1.0)
                    .shadow(radius: 4.0)
                    .overlay(
                        VStack {
                            if let name = windowInfo.windowName, !name.isEmpty {
                                Text(name)
                                    .padding(4)
                                    .background(.ultraThinMaterial)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                    .padding(8)
                                    .lineLimit(1)
                            }
                        },
                        alignment: .topTrailing
                    )
                    .padding()
            } else {
                ProgressView()
            }
        }
        .background(.thinMaterial)
        .cornerRadius(16)
        .opacity(isHovering ? 0.75 : 1.0)
        .onHover { over in
            withAnimation(.smooth) { isHovering = over }
        }
        .onTapGesture {
            WindowUtil.bringWindowToFront(windowInfo: windowInfo)
            onTap?()
        }
        
    }
}
