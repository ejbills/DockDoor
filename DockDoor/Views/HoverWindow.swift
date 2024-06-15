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
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        backgroundColor = .clear
        hasShadow = false
        
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
        let trackingArea = NSTrackingArea(rect: self.frame, options: options, owner: self, userInfo: nil)
        contentView?.addTrackingArea(trackingArea)
    }
    
    func hideWindow() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.contentView = nil
            self.hostingView = nil
            self.appName = ""
            self.windows.removeAll()
            CurrentWindow.shared.setIndex(to: 0)
            CurrentWindow.shared.setShowing(toState: false)
            self.orderOut(nil)
        }
    }
    
    override func mouseExited(with event: NSEvent) { if !CurrentWindow.shared.showingTabMenu { hideWindow() }}
    
    private func updateContentViewSizeAndPosition(mouseLocation: CGPoint? = nil, animated: Bool, centerOnScreen: Bool = false) {
        guard let hostingView = hostingView else { return }
        
        CurrentWindow.shared.setShowing(toState: centerOnScreen)
        
        let newHoverWindowSize = hostingView.fittingSize
        let sizeChanged = newHoverWindowSize != frame.size
        if sizeChanged {
            hostingView.rootView = HoverView(appName: self.appName, windows: self.windows, onWindowTap: self.onWindowTap, dockPosition: DockUtils.shared.getDockPosition(), bestGuessMonitor: self.bestGuessMonitor ?? NSScreen.main!)
        }
        
        var hoverWindowOrigin: CGPoint = .zero
        
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
        
        if animated && (sizeChanged || finalFrame != frame) {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.animator().setFrame(finalFrame, display: true)
            }, completionHandler: nil)
        } else {
            setFrame(finalFrame, display: true)
        }
    }
    
    private func screenContainingPoint(_ point: CGPoint) -> NSScreen? {
        return NSScreen.screens.first { $0.frame.contains(point) }
    }
    
    func showWindow(appName: String, windows: [WindowInfo], mouseLocation: CGPoint? = nil, onWindowTap: (() -> Void)? = nil) {
        let isMouseEvent = mouseLocation != nil
        CurrentWindow.shared.setShowing(toState: !isMouseEvent)
        
        guard !windows.isEmpty else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.appName = appName
            self.windows = windows
            self.onWindowTap = onWindowTap
            
            if self.hostingView == nil {
                let hoverView = HoverView(appName: appName, windows: windows, onWindowTap: onWindowTap, dockPosition: DockUtils.shared.getDockPosition(), bestGuessMonitor: self.bestGuessMonitor ?? NSScreen.main!)
                let hostingView = NSHostingView(rootView: hoverView)
                self.contentView = hostingView
                self.hostingView = hostingView
            } else {
                self.hostingView?.rootView = HoverView(appName: appName, windows: windows, onWindowTap: onWindowTap, dockPosition: DockUtils.shared.getDockPosition(), bestGuessMonitor: self.bestGuessMonitor ?? NSScreen.main!)
            }
            
            self.updateContentViewSizeAndPosition(mouseLocation: mouseLocation, animated: true, centerOnScreen: !isMouseEvent)
            self.makeKeyAndOrderFront(nil)
        }
    }
    
    func cycleWindows() {
        guard !windows.isEmpty else { return }
        
        let newIndex = CurrentWindow.shared.currIndex + 1
        CurrentWindow.shared.setIndex(to: newIndex % windows.count)
    }
    
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
    let dockPosition: DockPosition
    let bestGuessMonitor: NSScreen
    
    @State private var showWindows: Bool = false
    @State private var hasAppeared: Bool = false
    
    var scaleAnchor: UnitPoint {
        switch dockPosition {
        case .bottom: return .bottom
        case .left: return .leading
        case .right: return .trailing
        default: return .bottom
        }
    }
    
    var maxWindowDimension: CGFloat {
        let thickness = HoverWindow.shared.windowSize.height
        var maxDimension: CGFloat = 0
        
        for window in windows {
            if let cgImage = window.image {
                let cgSize = CGSize(width: Double(cgImage.width), height: Double(cgImage.height))
                let oppositeDimension = dockPosition == .bottom ? (cgSize.width * thickness) / cgSize.height : (cgSize.height * thickness) / cgSize.width
                maxDimension = max(maxDimension, oppositeDimension)
            }
        }
        return maxDimension
    }
    
    var body: some View {
        ZStack {
            ScrollViewReader { scrollProxy in
                ScrollView(dockPosition == .bottom || CurrentWindow.shared.showingTabMenu ? .horizontal : .vertical, showsIndicators: false) {
                    DynStack(direction: CurrentWindow.shared.showingTabMenu ? .horizontal : (dockPosition == .bottom ? .horizontal : .vertical), spacing: 16) {
                        ForEach(windows.indices, id: \.self) { index in
                            WindowPreview(windowInfo: windows[index], onTap: onWindowTap, index: index, dockPosition: dockPosition, maxWindowDimension: maxWindowDimension, bestGuessMonitor: bestGuessMonitor)
                                .id("\(appName)-\(index)")
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
                        withAnimation {
                            scrollProxy.scrollTo("\(appName)-\(newIndex)", anchor: .center)
                        }
                    }
                    .onChange(of: self.windows) { _, _ in
                        self.runAnimation()
                    }
                }
                .frame(maxWidth: bestGuessMonitor.visibleFrame.width)
                .opacity(showWindows ? 1 : 0.8)
            }
        }
        .dockStyle(cornerRadius: 26)
        .overlay(alignment: .topLeading) {
            if !CurrentWindow.shared.showingTabMenu {
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
    let dockPosition: DockPosition
    let maxWindowDimension: CGFloat
    let bestGuessMonitor: NSScreen
    
    @State private var isHovering = false
    
    var body: some View {
        // Determine if the current preview is highlighted
        let isHighlighted = (index == CurrentWindow.shared.currIndex && CurrentWindow.shared.showingTabMenu)
        let selected = isHovering || isHighlighted
        
        // Determine if height scaling should be favored
        let favorHeightScaling: Bool = CurrentWindow.shared.showingTabMenu || dockPosition == .bottom
        
        VStack {
            if let cgImage = windowInfo.image {
                let image = Image(decorative: cgImage, scale: 1.0)
                
                // Desired height for horizontal dock and width for vertical dock
                let thickness = HoverWindow.shared.windowSize.height
                
                // Get the size of CGImage with Double values
                let cgSize = CGSize(width: Double(cgImage.width), height: Double(cgImage.height))
                
                // Calculate the proportional value maintaining the aspect ratio
                let oppositeDimension = favorHeightScaling ? (cgSize.width * thickness) / cgSize.height : (cgSize.height * thickness) / cgSize.width
                
                // Maximum width and height constraints for docks
                let maxAllowedWidth: CGFloat = HoverWindow.shared.windowSize.width
                let maxAllowedHeight: CGFloat = HoverWindow.shared.windowSize.height
                
                // Calculate the initial width and height based on constraints
                let inFlightFinalWidth = favorHeightScaling ? min(max(oppositeDimension, thickness), maxAllowedWidth) : min(thickness, maxAllowedWidth)
                let inFlightFinalHeight = favorHeightScaling ? min(max(oppositeDimension, thickness), maxAllowedHeight) : min(thickness, maxAllowedHeight)
                
                // Get the screen size
                let screenFrame = bestGuessMonitor.visibleFrame
                
                // Check if the width or height exceeds the screen size
                let violatedWidth: Bool = cgSize.width > screenFrame.width
                let violatedHeight: Bool = cgSize.height > screenFrame.height
                
                // Final dimensions clamped based on screen size violations
                let finalWidth = violatedWidth ? maxAllowedWidth : inFlightFinalWidth
                let finalHeight = violatedHeight ? maxAllowedHeight : inFlightFinalHeight

                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(
                        width: favorHeightScaling ? (violatedWidth ? finalWidth : nil) : finalWidth,
                        height: favorHeightScaling ? finalHeight : (violatedHeight ? finalHeight : nil),
                        alignment: .center
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .background {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(.clear.shadow(.drop(
                                color: .black.opacity(selected ? 0.35 : 0.25),
                                radius: selected ? 12 : 8,
                                y: selected ? 6 : 4
                            )))
                    }
                    .scaleEffect(selected ? 0.95 : 1)
                
            } else {
                ProgressView()
            }
        }
        .overlay {
            AnimatedGradientOverlay(shouldDisplay: selected)
        }
        .onHover { over in
            if !CurrentWindow.shared.showingTabMenu {
                withAnimation(.snappy(duration: 0.175)) {
                    isHovering = over
                }
            }
        }
        .onTapGesture {
            WindowUtil.bringWindowToFront(windowInfo: windowInfo)
            onTap?()
        }
    }
}
