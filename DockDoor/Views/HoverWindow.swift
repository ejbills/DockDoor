//
//  HoverWindow.swift
//  DockDoor
//
//  Created by Ethan Bills on 6/5/24.
//

import Cocoa
import SwiftUI
import Defaults

@Observable class CurrentWindow {
    static let shared = CurrentWindow()
    
    var currIndex: Int = 0
    var showingTabMenu: Bool = false
    
    func setShowing(toState: Bool) {
        DispatchQueue.main.async {
            withAnimation(.easeInOut) {
                self.showingTabMenu = toState
            }
        }
    }
    
    func setIndex(to: Int) {
        DispatchQueue.main.async {
            withAnimation(.easeInOut) {
                self.currIndex = to
            }
        }
    }
}

class HoverWindow: NSWindow {
    static let shared = HoverWindow()
    
    private var appName: String = ""
    private var windows: [WindowInfo] = []
    private var onWindowTap: (() -> Void)?
    private var hostingView: NSHostingView<HoverView>?
    
    var bestGuessMonitor: NSScreen? = NSScreen.main
    var windowSize: CGSize = getWindowSize()
    
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
    
    // Method to hide the window
    func hideWindow() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Remove the hostingView from the window's content view
            self.contentView = nil  // Clear the content view to release hostingView
            
            // Set the hostingView property to nil for proper deallocation
            self.hostingView = nil
            
            // Ensure other resources are released
            self.appName = ""
            self.windows.removeAll()
            CurrentWindow.shared.setIndex(to: 0)
            
            self.orderOut(nil) // Hide the window
        }
    }
    
    // Mouse exited tracking area - hide the window
    override func mouseExited(with event: NSEvent) {
        if !CurrentWindow.shared.showingTabMenu { hideWindow() }
    }
    
    // Calculate hover window's size and position based on content and mouse location
    private func updateContentViewSizeAndPosition(mouseLocation: CGPoint? = nil, animated: Bool, centerOnScreen: Bool = false) {
        guard let hostingView = hostingView else { return }
        guard !windows.isEmpty else {
            hideWindow()
            return
        }
        
        CurrentWindow.shared.setShowing(toState: centerOnScreen)
        
        // 1. Check if window size needs updating
        let newHoverWindowSize = hostingView.fittingSize
        let sizeChanged = newHoverWindowSize != frame.size // Compare new and current size
        if sizeChanged {
            hostingView.rootView = HoverView(appName: self.appName, windows: self.windows, onWindowTap: self.onWindowTap) // Only update if size has changed
        }
        
        var hoverWindowOrigin: CGPoint
        
        if centerOnScreen {
            // Center the window on the screen
            guard let screen = self.bestGuessMonitor else { return }
            
            let screenFrame = screen.frame
            hoverWindowOrigin = CGPoint(
                x: screenFrame.midX - (newHoverWindowSize.width / 2),
                y: screenFrame.midY - (newHoverWindowSize.height / 2)
            )
        } else if let mouseLocation = mouseLocation, let screen = screenContainingPoint(mouseLocation) {
            // Use mouse location for initial placement
            hoverWindowOrigin = mouseLocation
            
            let screenFrame = screen.frame
            let dockPosition = DockUtils.shared.getDockPosition()
            let dockHeight = DockUtils.shared.calculateDockHeight(screen)
            
            // Position window above/below dock depending on position
            switch dockPosition {
                case .bottom:
                    hoverWindowOrigin.y = screenFrame.minY + dockHeight
                case .left, .right:
                    hoverWindowOrigin.y -= newHoverWindowSize.height / 2
                    if dockPosition == .left {
                        hoverWindowOrigin.x = screenFrame.minX + dockHeight
                    } else { // dockPosition == .right
                        hoverWindowOrigin.x = screenFrame.maxX - newHoverWindowSize.width - dockHeight
                    }
                case .unknown:
                    break
            }
            
            // Adjust horizontal position if the window is wider than the screen and the dock is on the side
            if dockPosition == .left || dockPosition == .right, newHoverWindowSize.width > screenFrame.width - dockHeight {
                hoverWindowOrigin.x = dockPosition == .left ? screenFrame.minX : screenFrame.maxX - newHoverWindowSize.width
            }
            
            // Center the window horizontally if the dock is at the bottom
            if dockPosition == .bottom {
                hoverWindowOrigin.x -= newHoverWindowSize.width / 2
            }
            
            // Ensure the window stays within screen bounds
            hoverWindowOrigin.x = max(screenFrame.minX, min(hoverWindowOrigin.x, screenFrame.maxX - newHoverWindowSize.width))
            hoverWindowOrigin.y = max(screenFrame.minY, min(hoverWindowOrigin.y, screenFrame.maxY - newHoverWindowSize.height))
        } else {
            return
        }
        
        let finalFrame = NSRect(origin: hoverWindowOrigin, size: newHoverWindowSize)
        
        // 2. Only animate if necessary (size or position change)
        if animated && (sizeChanged || finalFrame != frame) { // Animate only if there's a change
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.animator().setFrame(finalFrame, display: true)
            }, completionHandler: nil)
        } else { // Directly set the frame if not animated or no change
            setFrame(finalFrame, display: true)
        }
    }
    
    // Helper method to find the screen containing a given point
    private func screenContainingPoint(_ point: CGPoint) -> NSScreen? {
        self.bestGuessMonitor = DockObserver.screenContainingPoint(point)
        return self.bestGuessMonitor
    }
    
    func showWindow(appName: String, windows: [WindowInfo], mouseLocation: CGPoint, onWindowTap: (() -> Void)? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.appName = appName
            self.windows = windows
            self.onWindowTap = onWindowTap
            
            if self.hostingView == nil {
                // Create a new hosting view if we don't have one
                let hoverView = HoverView(appName: appName, windows: windows, onWindowTap: onWindowTap)
                let hostingView = NSHostingView(rootView: hoverView)
                self.contentView = hostingView
                self.hostingView = hostingView
            } else {
                // Update the existing hostingView's rootView
                self.hostingView?.rootView = HoverView(appName: appName, windows: windows, onWindowTap: onWindowTap)
            }
            
            let isMouseEvent = mouseLocation != .zero
            
            CurrentWindow.shared.setShowing(toState: !isMouseEvent)
            
            self.updateContentViewSizeAndPosition(mouseLocation: mouseLocation, animated: true, centerOnScreen: !isMouseEvent)
            self.makeKeyAndOrderFront(nil)
        }
    }
    
    func cycleWindows() {
        guard !windows.isEmpty else { return }
        
        let newIndex = CurrentWindow.shared.currIndex + 1
        CurrentWindow.shared.setIndex(to: newIndex >= windows.count ? 0 : newIndex)
    }
    
    private func updateWindowDisplay() {
        guard !windows.isEmpty else { return }
        
        // Update the rootView of the existing hostingView
        hostingView?.rootView = HoverView(appName: self.appName, windows: self.windows, onWindowTap: self.onWindowTap)
        
        // Do not use mouse location, center on screen only for cycling
        updateContentViewSizeAndPosition(animated: false, centerOnScreen: true)
        makeKeyAndOrderFront(nil)
    }
    
    // Method to select and bring the current window to the front
    func selectAndBringToFrontCurrentWindow() {
        guard !windows.isEmpty else { return }
        
        let selectedWindow = windows[CurrentWindow.shared.currIndex]
        WindowUtil.bringWindowToFront(windowInfo: selectedWindow)
        hideWindow()
    }
}

struct HoverView: View {
    let appName: String
    let windows: [WindowInfo]
    let onWindowTap: (() -> Void)?
    
    @State private var showWindows: Bool = false
    @State private var hasAppeared: Bool = false
    
    var scaleAnchor: UnitPoint {
        switch DockUtils.shared.getDockPosition() {
            case .bottom: .bottom
            case .left: .leading
            case .right: .trailing
            case .unknown: .bottom
        }
    }
    
    var body: some View {
        let dockSide = DockUtils.shared.getDockPosition()
        ZStack {
            ScrollViewReader { scrollProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    DynStack(direction: dockSide == .bottom ? .horizontal : .vertical, spacing: 16) {
                        ForEach(windows.indices, id: \.self) { index in
                            WindowPreview(windowInfo: windows[index], onTap: onWindowTap, index: index)
                                .id(index)
                        }
                    }
                    .padding(20)
                    .onAppear {
                        if !hasAppeared {
                            hasAppeared.toggle()
                            self.runAnimation()
                        }
                    }
                    .onChange(of: CurrentWindow.shared.currIndex) { _, newIndex in
                        // Smoothly scroll to the new index
                        withAnimation {
                            scrollProxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                    .onChange(of: self.windows) { _, _ in
                        self.runAnimation()
                    }
                }
                .frame(
                    maxWidth: HoverWindow.shared.bestGuessMonitor?.visibleFrame.width ?? 2000
                )
//                .scaleEffect(showWindows ? 1 : 0.90, anchor: scaleAnchor)
                .opacity(showWindows ? 1 : 0.8)
            }
        }
//        .animation(.smooth, value: windows)
        .dockStyle()
        .overlay(alignment: .topLeading) {
            if !windows.isEmpty && !CurrentWindow.shared.showingTabMenu {
                HStack(spacing: 4) {
                    if let appIcon = windows.first?.appIcon {
                        Image(nsImage: appIcon).resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                    }
                    Text(appName)
                }
                .shadow(color: .black.opacity(0.35), radius: 12, y: 8)
                .padding(EdgeInsets(top: -10, leading: 12, bottom: 0, trailing: 0))
            }
        }
        .padding(.all, 24)
    }
    
    private func runAnimation() {
        self.showWindows = false
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            showWindows = true
        }
    }
}

struct WindowPreview: View {
    let windowInfo: WindowInfo
    let onTap: (() -> Void)?
    let index: Int
    
    @State private var isHovering = false
    
    var body: some View {
        let dockSide = DockUtils.shared.getDockPosition()
        let isHighlighted = (index == CurrentWindow.shared.currIndex && CurrentWindow.shared.showingTabMenu)
        VStack {
            if let cgImage = windowInfo.image {
                let image = Image(decorative: cgImage, scale: 1.0)
                let selected = isHovering || isHighlighted
                
                image
                    .resizable()
                    .scaledToFit()
//                    .frame(
//                        width: dockSide == .bottom ? nil : 150,
//                        height:  dockSide != .bottom ? nil : 150
//                    )
                    .frame(
                        height:  HoverWindow.shared.windowSize.height
                    )
                    .overlay {
                        AnimatedGradientOverlay(shouldDisplay: selected)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    .background {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(.clear.shadow(.drop(
                                color: .black.opacity(selected ? 0.35 : 0.25),
                                radius: selected ? 12 : 8,
                                y: selected ? 6 : 4
                            )))
                    }
                    .scaleEffect(selected ? 1.05 : 1)
                //                        .overlay(
                //                            VStack {
                //                                if let name = windowInfo.windowName, !name.isEmpty {
                //                                    Text(name)
                //                                        .padding(4)
                //                                        .background(.thickMaterial)
                //                                        .foregroundColor(.white)
                //                                        .cornerRadius(8)
                //                                        .padding(8)
                //                                        .lineLimit(1)
                //                                }
                //                            },
                //                            alignment: .topTrailing
                //                        )
                
            } else {
                ProgressView()
            }
        }
        .onHover { over in
            if !CurrentWindow.shared.showingTabMenu { withAnimation(.smooth(duration: 0.225, extraBounce: 0.35)) { isHovering = over }}
        }
        .onTapGesture {
            WindowUtil.bringWindowToFront(windowInfo: windowInfo)
            onTap?()
        }
    }
}
