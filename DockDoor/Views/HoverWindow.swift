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
    
    var windowSize: CGSize = getWindowSize()
    
    private var previousHoverWindowOrigin: CGPoint? // Store previous origin
    
    private let debounceDelay: TimeInterval = 0.1
    private var debounceWorkItem: DispatchWorkItem?
    private var lastShowTime: Date?
    
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
        guard self.hostingView != nil else { return }
        
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
    
    private func updateContentViewSizeAndPosition(mouseLocation: CGPoint? = nil, mouseScreen: NSScreen, animated: Bool, centerOnScreen: Bool = false) {
        guard let hostingView else { return }
        
        if centerOnScreen {
            CurrentWindow.shared.setShowing(toState: true)
            let newHoverWindowSize = hostingView.fittingSize
            let position = CGPoint(
                x: mouseScreen.frame.midX - (newHoverWindowSize.width / 2),
                y: mouseScreen.frame.midY - (newHoverWindowSize.height / 2)
            )
            let finalFrame = CGRect(origin: position, size: newHoverWindowSize)
            
            setFrame(finalFrame, display: true)
            previousHoverWindowOrigin = position
            return
        }
        
        guard let mouseLocation else { return }
        
        CurrentWindow.shared.setShowing(toState: centerOnScreen)
        
        let newHoverWindowSize = hostingView.fittingSize
        let sizeChanged = newHoverWindowSize != frame.size
        if sizeChanged {
            hostingView.rootView = HoverView(
                appName: self.appName,
                windows: self.windows,
                onWindowTap: self.onWindowTap,
                dockPosition: DockUtils.shared.getDockPosition(),
                bestGuessMonitor: mouseScreen)
        }
        
        // Detect the screen where the dock is positioned
        let screenFrame = mouseScreen.frame
        let dockPosition = DockUtils.shared.getDockPosition()
        let dockHeight = DockUtils.shared.calculateDockHeight(mouseScreen)
        
        var position = CGPoint.zero
        
        var xPosition: CGFloat = mouseLocation.x
        var yPosition: CGFloat = mouseLocation.y
        
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
    
    func showWindow(appName: String, windows: [WindowInfo], mouseLocation: CGPoint? = nil, mouseScreen: NSScreen? = nil, onWindowTap: (() -> Void)? = nil) {
        let now = Date()
        
        if let lastShowTime = lastShowTime, now.timeIntervalSince(lastShowTime) < debounceDelay {
            debounceWorkItem?.cancel()
            
            let workItem = DispatchWorkItem { [weak self] in
                self?.performShowWindow(appName: appName, windows: windows, mouseLocation: mouseLocation, mouseScreen: mouseScreen, onWindowTap: onWindowTap)
            }
            
            debounceWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + debounceDelay, execute: workItem)
        } else {
            performShowWindow(appName: appName, windows: windows, mouseLocation: mouseLocation, mouseScreen: mouseScreen, onWindowTap: onWindowTap)
        }
        
        lastShowTime = now
    }
    
    private func performShowWindow(appName: String, windows: [WindowInfo], mouseLocation: CGPoint?, mouseScreen: NSScreen?, onWindowTap: (() -> Void)?) {
        let isMouseEvent = mouseLocation != nil
        CurrentWindow.shared.setShowing(toState: !isMouseEvent)
        
        guard !windows.isEmpty else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.appName = appName
            self.windows = windows
            self.onWindowTap = onWindowTap
            
            let screen = mouseScreen ?? NSScreen.main!
            
            if self.hostingView == nil {
                let hoverView = HoverView(appName: appName, windows: windows, onWindowTap: onWindowTap,
                                          dockPosition: DockUtils.shared.getDockPosition(), bestGuessMonitor: screen)
                let hostingView = NSHostingView(rootView: hoverView)
                self.contentView = hostingView
                self.hostingView = hostingView
            } else {
                self.hostingView?.rootView = HoverView(appName: appName, windows: windows, onWindowTap: onWindowTap,
                                                       dockPosition: DockUtils.shared.getDockPosition(), bestGuessMonitor: screen)
            }
            
            self.updateContentViewSizeAndPosition(mouseLocation: mouseLocation, mouseScreen: screen, animated: true, centerOnScreen: !isMouseEvent)
            self.makeKeyAndOrderFront(nil)
        }
    }
    
    func cycleWindows(goBackwards: Bool) {
        guard !windows.isEmpty else { return }
        
        let newIndex: Int
        if goBackwards {
            newIndex = CurrentWindow.shared.currIndex - 1
        } else {
            newIndex = CurrentWindow.shared.currIndex + 1
        }
        
        // Ensure the index wraps around
        let wrappedIndex = (newIndex + windows.count) % windows.count
        CurrentWindow.shared.setIndex(to: wrappedIndex)
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
    @State private var appIcon: NSImage? = nil
    
    var maxWindowDimension: CGPoint {
        let thickness = HoverWindow.shared.windowSize.height
        var maxWidth: CGFloat = 0
        var maxHeight: CGFloat = 0
        
        for window in windows {
            if let cgImage = window.image {
                let cgSize = CGSize(width: Double(cgImage.width), height: Double(cgImage.height))
                
                // Calculate the dimensions based on the dock position
                let widthBasedOnHeight = (cgSize.width * thickness) / cgSize.height
                let heightBasedOnWidth = (cgSize.height * thickness) / cgSize.width
                
                if dockPosition == .bottom || CurrentWindow.shared.showingTabMenu {
                    maxWidth = max(maxWidth, widthBasedOnHeight)
                    maxHeight = thickness  // consistent height if dock is on the bottom
                } else {
                    maxHeight = max(maxHeight, heightBasedOnWidth)
                    maxWidth = thickness  // consistent width if dock is on the sides
                }
            }
        }
        
        return CGPoint(x: maxWidth, y: maxHeight)
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
                    .padding(14)
                    .onAppear {
                        if !hasAppeared {
                            hasAppeared.toggle()
                            self.runUIUpdates()
                        }
                    }
                    .onChange(of: CurrentWindow.shared.currIndex) { _, newIndex in
                        withAnimation {
                            scrollProxy.scrollTo("\(appName)-\(newIndex)", anchor: .center)
                        }
                    }
                    .onChange(of: self.windows) { _, _ in
                        self.runUIUpdates()
                    }
                }
                .frame(maxWidth: bestGuessMonitor.visibleFrame.width)
                .opacity(showWindows ? 1 : 0.8)
            }
        }
        .dockStyle(cornerRadius: 16)
        .overlay(alignment: .topLeading) {
            if !CurrentWindow.shared.showingTabMenu {
                HStack(spacing: 4) {
                    if let appIcon = appIcon {
                        Image(nsImage: appIcon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                    } else {
                        ProgressView()
                            .frame(width: 24, height: 24)
                    }
                    Text(appName)
                        .padding(3)
                        .bold()
                        .shadow(radius: 4)
                }
                .padding(EdgeInsets(top: -10, leading: 12, bottom: 0, trailing: 0))
            }
        }
        .padding(.all, 24)
        .frame(
            maxWidth: self.bestGuessMonitor.visibleFrame.width,
            maxHeight: self.bestGuessMonitor.visibleFrame.height
        )
    }
    
    private func runUIUpdates() {
        self.runAnimation()
        self.loadAppIcon()
    }
    
    private func runAnimation() {
        self.showWindows = false
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            showWindows = true
        }
    }
    
    private func loadAppIcon() {
        if let bundleID = windows.first?.bundleID,
           let icon = AppIconUtil.getIcon(bundleID: bundleID) {
            DispatchQueue.main.async {
                self.appIcon = icon
            }
        }
    }
}


struct WindowPreview: View {
    let windowInfo: WindowInfo
    let onTap: (() -> Void)?
    let index: Int
    let dockPosition: DockPosition
    let maxWindowDimension: CGPoint
    let bestGuessMonitor: NSScreen
    
    @State private var isHovering = false
    
    private var calculatedMaxDimensions: CGSize? {
        return CGSize(width: self.bestGuessMonitor.frame.width * 0.75, height: self.bestGuessMonitor.frame.height * 0.75)
    }
    
    var calculatedSize: CGSize {
        guard let cgImage = windowInfo.image else { return .zero }
        
        let cgSize = CGSize(width: cgImage.width, height: cgImage.height)
        let aspectRatio = cgSize.width / cgSize.height
        let maxAllowedWidth = maxWindowDimension.x
        let maxAllowedHeight = maxWindowDimension.y
        
        var targetWidth = maxAllowedWidth
        var targetHeight = targetWidth / aspectRatio
        
        if targetHeight > maxAllowedHeight {
            targetHeight = maxAllowedHeight
            targetWidth = aspectRatio * targetHeight
        }
        
        return CGSize(width: targetWidth, height: targetHeight)
    }
    
    var body: some View {
        // Determine if the current preview is highlighted
        let isHighlighted = (index == CurrentWindow.shared.currIndex && CurrentWindow.shared.showingTabMenu)
        let selected = isHovering || isHighlighted
        
        VStack {
            if let cgImage = windowInfo.image {
                ZStack(alignment: .topTrailing) {
                    Image(decorative: cgImage, scale: 1.0)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(
                            width: calculatedSize.width,
                            height: calculatedSize.height,
                            alignment: .center
                        )
                        .frame(maxWidth: calculatedMaxDimensions?.width, maxHeight: calculatedMaxDimensions?.height)
                        .overlay { AnimatedGradientOverlay(shouldDisplay: selected) }
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .shadow(radius: selected ? 0 : 2)
                        .background {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.clear.shadow(.drop(
                                    color: .black.opacity(selected ? 0.35 : 0.25),
                                    radius: selected ? 12 : 8,
                                    y: selected ? 6 : 4
                                )))
                        }
                    
                    if !CurrentWindow.shared.showingTabMenu {
                        Button(action: {
                            WindowUtil.closeWindow(windowInfo: windowInfo)
                            onTap?()
                        }) {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                            }
                        }
                        .buttonBorderShape(.roundedRectangle)
                        .padding([.top, .trailing], 8)
                    }
                }
                .scaleEffect(selected ? 1.025 : 1)
                
            } else {
                ProgressView()
            }
        }
        .contentShape(Rectangle())
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
