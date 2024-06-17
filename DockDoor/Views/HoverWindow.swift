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
    
    private var previousHoverWindowOrigin: CGPoint? // Store previous origin
    
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
    
    override func mouseExited(with event: NSEvent) {
        if !CurrentWindow.shared.showingTabMenu {
            hideWindow()
        }
    }
    
    private func updateContentViewSizeAndPosition(mouseLocation: CGPoint? = nil, animated: Bool, centerOnScreen: Bool = false) {
        guard let hostingView else { return }
        
        if centerOnScreen {
            CurrentWindow.shared.setShowing(toState: true)
            guard let bestGuessMonitor = self.bestGuessMonitor else { return }
                        
            let newHoverWindowSize = hostingView.fittingSize
            let position = CGPoint(
                x: bestGuessMonitor.frame.midX - (newHoverWindowSize.width / 2),
                y: bestGuessMonitor.frame.midY - (newHoverWindowSize.height / 2)
            )
            let finalFrame = CGRect(origin: position, size: newHoverWindowSize)
            
            setFrame(finalFrame, display: true)
            previousHoverWindowOrigin = position
            return
        }
        
        guard let mouseLocation else { return }
        
        self.bestGuessMonitor = DockObserver.screenContainingPoint(mouseLocation)
        
        guard let screenWithMouse = self.bestGuessMonitor else { return }
        
        CurrentWindow.shared.setShowing(toState: centerOnScreen)
        
        let newHoverWindowSize = hostingView.fittingSize
        let sizeChanged = newHoverWindowSize != frame.size
        if sizeChanged {
            hostingView.rootView = HoverView(
                appName: self.appName,
                windows: self.windows,
                onWindowTap: self.onWindowTap,
                dockPosition: DockUtils.shared.getDockPosition(),
                bestGuessMonitor: screenWithMouse)
        }
        
        // Detect the screen where the dock is positioned
        let screenFrame = screenWithMouse.frame
        let dockPosition = DockUtils.shared.getDockPosition()
        let dockHeight = DockUtils.shared.calculateDockHeight(screenWithMouse)
        
        var position = CGPoint.zero
        
        // Convert icon position to the dock screen's coordinate system
        let convertedMouseLocation = DockObserver.nsPointFromCGPoint(mouseLocation, forScreen: screenWithMouse)
        
        var xPosition: CGFloat = convertedMouseLocation.x
        var yPosition: CGFloat = convertedMouseLocation.y
        
        // Adjust the window position based on dock position
        switch dockPosition {
        case .bottom:
            yPosition = screenFrame.minY + dockHeight
            xPosition -= (newHoverWindowSize.width / 2)
        case .left:
            xPosition = screenFrame.minX + dockHeight
            yPosition -= (newHoverWindowSize.height / 2)
        case .right:
            xPosition = screenFrame.maxX - dockHeight - newHoverWindowSize.width
            yPosition -= (newHoverWindowSize.height / 2)
        default:
            xPosition -= (newHoverWindowSize.width / 2)
            yPosition -= (newHoverWindowSize.height / 2)
        }
        
        // Ensure the hover window stays within the dock screen bounds
        xPosition = max(screenFrame.minX, min(xPosition, screenFrame.maxX - newHoverWindowSize.width))
        yPosition = max(screenFrame.minY, min(yPosition, screenFrame.maxY - newHoverWindowSize.height))
        
        position = CGPoint(x: xPosition, y: yPosition)
        
        let finalFrame = CGRect(origin: position, size: newHoverWindowSize)
        
        let shouldAnimate = animated && (sizeChanged || finalFrame != frame)
        
        if shouldAnimate {
            let distanceThreshold: CGFloat = 1800
            let distance = previousHoverWindowOrigin.map { position.distance(to: $0) } ?? distanceThreshold + 1
            
            if distance > distanceThreshold {
                setFrame(finalFrame, display: true)
            } else {
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.2
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    self.animator().setFrame(finalFrame, display: true)
                }, completionHandler: nil)
            }
        } else {
            setFrame(finalFrame, display: true)
        }
        
        previousHoverWindowOrigin = position
    }
    
    func showWindow(appName: String, windows: [WindowInfo], mouseLocation: CGPoint? = nil, onWindowTap: (() -> Void)? = nil) {
        let isMouseEvent = mouseLocation != nil
        print("is this a mouse event? :\(isMouseEvent)")
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
                        .padding(6)
                        .dockStyle()
                }
                .padding(EdgeInsets(top: -10, leading: 12, bottom: 0, trailing: 0))
            }
        }
        .padding(.all, 24)
        .frame(
            maxWidth: HoverWindow.shared.bestGuessMonitor?.visibleFrame.width ?? 2000,
            maxHeight: HoverWindow.shared.bestGuessMonitor?.visibleFrame.height ?? 1500
        )
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
                let violatedWidth: Bool = cgSize.width > screenFrame.width * 0.75
                let violatedHeight: Bool = cgSize.height > screenFrame.height * 0.75
                
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
