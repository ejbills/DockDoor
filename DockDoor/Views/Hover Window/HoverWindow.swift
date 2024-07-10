//
//  HoverWindow.swift
//  DockDoor
//
//  Created by Ethan Bills on 6/5/24.
//

import SwiftUI
import Defaults
import FluidGradient

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

final class HoverWindow: NSWindow {
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
        isMovableByWindowBackground = false
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
            
            // Check if the window is already hidden
            if !self.isVisible {
                return
            }
            
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
        guard let hostingView = hostingView else { return }
        
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
        xPosition = max(screenFrame.minX, min(xPosition, screenFrame.maxX - newHoverWindowSize.width)) + (dockPosition != .bottom ? Defaults[.windowPadding] : 0)
        yPosition = max(screenFrame.minY, min(yPosition, screenFrame.maxY - newHoverWindowSize.height)) + (dockPosition == .bottom ? Defaults[.windowPadding] : 0)
        
        position = CGPoint(x: xPosition, y: yPosition)
        
        let finalFrame = CGRect(origin: position, size: newHoverWindowSize)
        
        let shouldAnimate = animated && (sizeChanged || finalFrame != frame)
        
        if shouldAnimate {
            let distanceThreshold: CGFloat = 1800
            let distance = previousHoverWindowOrigin.map { position.distance(to: $0) } ?? distanceThreshold + 1
            
            if distance > distanceThreshold || !Defaults[.showAnimations] {
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
    
    func showWindow(appName: String, windows: [WindowInfo], mouseLocation: CGPoint? = nil, mouseScreen: NSScreen? = nil, overrideDelay: Bool = false, onWindowTap: (() -> Void)? = nil) {
        let now = Date()
        let delay = overrideDelay ? 0.0 : Defaults[.openDelay]
        
        // Cancel any existing debounce work item
        debounceWorkItem?.cancel()
        
        // Check if the hover window is already showing
        let isHoverWindowShowing = self.isVisible
        
        // Check if the current time is within the debounce delay period
        if let lastShowTime = lastShowTime, now.timeIntervalSince(lastShowTime) < debounceDelay {
            let workItem = DispatchWorkItem { [weak self] in
                self?.performShowWindow(appName: appName, windows: windows, mouseLocation: mouseLocation, mouseScreen: mouseScreen, onWindowTap: onWindowTap)
            }
            
            debounceWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + debounceDelay, execute: workItem)
        } else {
            // Handle the open delay only if the hover window is not already showing
            if isHoverWindowShowing || delay == 0.0 {
                performShowWindow(appName: appName, windows: windows, mouseLocation: mouseLocation, mouseScreen: mouseScreen, onWindowTap: onWindowTap)
            } else {
                let workItem = DispatchWorkItem { [weak self] in
                    self?.performShowWindow(appName: appName, windows: windows, mouseLocation: mouseLocation, mouseScreen: mouseScreen, onWindowTap: onWindowTap)
                }
                
                debounceWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
            }
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
    
    @Default(.uniformCardRadius) var uniformCardRadius
    @Default(.hoverTitleStyle) var hoverTitleStyle
    @Default(.windowTitleAlignment) var windowTitleAlignment
    
    @State private var showWindows: Bool = false
    @State private var hasAppeared: Bool = false
    @State private var appIcon: NSImage? = nil
    
    enum TitleStyle: Int, CaseIterable {
        case `default` = 0
        case embedded = 1
        case popover = 2
        case hidden = -1
        
        var titleString: String {
            switch self {
            case .default:
                return String(localized: "Default", comment: "Preview title style option")
            case .embedded:
                return String(localized: "Embedded", comment: "Preview title style option")
            case .popover:
                return String(localized: "Popover", comment: "Preview title style option")
            case .hidden:
                return String(localized: "Hidden", comment: "Preview title style option")
            }
        }
    }
    
    var maxWindowDimension: CGPoint {
        let thickness = HoverWindow.shared.windowSize.height
        var maxWidth: CGFloat = 300
        var maxHeight: CGFloat = 300
        
        for window in windows {
            if let cgImage = window.image {
                let cgSize = CGSize(width: cgImage.width, height: cgImage.height)
                let widthBasedOnHeight = (cgSize.width * thickness) / cgSize.height
                let heightBasedOnWidth = (cgSize.height * thickness) / cgSize.width
                
                if dockPosition == .bottom || CurrentWindow.shared.showingTabMenu {
                    maxWidth = max(maxWidth, widthBasedOnHeight)
                    maxHeight = thickness
                } else {
                    maxHeight = max(maxHeight, heightBasedOnWidth)
                    maxWidth = thickness
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
                        if !minimizedOrHiddenWindows.isEmpty {
                            minimizedOrHiddenWindowsView
                        }
                        
                        ForEach(activeWindows.indices, id: \.self) { index in
                            WindowPreview(windowInfo: activeWindows[index], onTap: onWindowTap, index: index,
                                          dockPosition: dockPosition, maxWindowDimension: maxWindowDimension,
                                          bestGuessMonitor: bestGuessMonitor, uniformCardRadius: uniformCardRadius)
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
                .opacity(showWindows ? 1 : 0.8)
            }
        }
        .padding(.top, (!CurrentWindow.shared.showingTabMenu && hoverTitleStyle == 1) ? 25 : 0) // Provide space above the window preview for the Embedded title style when hovering over the Dock.
        .dockStyle(cornerRadius: 16)
        .overlay(alignment: .topLeading) {
            hoverTitleBaseView(labelSize: measureString(appName, fontSize: 14))
        }
        .padding(.top, (!CurrentWindow.shared.showingTabMenu && hoverTitleStyle == 2) ? 30 : 0) // Provide empty space above the window preview for the Popover title style when hovering over the Dock
        .padding(.all, 24)
        .frame(maxWidth: self.bestGuessMonitor.visibleFrame.width, maxHeight: self.bestGuessMonitor.visibleFrame.height)
    }
    
    private var minimizedOrHiddenWindows: [WindowInfo] {
        windows.filter { $0.isMinimized || $0.isHidden }
    }

    private var activeWindows: [WindowInfo] {
        windows.filter { !$0.isMinimized && !$0.isHidden }
    }
    
    @ViewBuilder
    private func hoverTitleBaseView(labelSize: CGSize) -> some View {
        if !CurrentWindow.shared.showingTabMenu {
            switch hoverTitleStyle {
            case 0: // Default
                HStack(spacing: 2) {
                    if let appIcon = appIcon {
                        Image(nsImage: appIcon)
                            .resizable()
                            .scaledToFit()
                            .zIndex(1)
                            .frame(width: 24, height: 24)
                    } else {
                        ProgressView()
                            .frame(width: 24, height: 24)
                    }
                    hoverTitleLabelView(labelSize: labelSize)
                }
                .padding(EdgeInsets(top: -11.5, leading: 15, bottom: -1.5, trailing: 1.5))
            case 1: // Embedded
                HStack(spacing: 2) {
                    if let appIcon = appIcon {
                        Image(nsImage: appIcon)
                            .resizable()
                            .scaledToFit()
                            .zIndex(1)
                            .frame(width: 24, height: 24)
                    } else {
                        ProgressView()
                            .frame(width: 24, height: 24)
                    }
                    hoverTitleLabelView(labelSize: labelSize)
                }
                .padding(.top, 10)
                .padding(.leading)
            case 2: // Popover
                HStack {
                    Spacer()
                    HStack(spacing: 2) {
                        if let appIcon = appIcon {
                            Image(nsImage: appIcon)
                                .resizable()
                                .scaledToFit()
                                .zIndex(1)
                                .frame(width: 24, height: 24)
                        } else {
                            ProgressView()
                                .frame(width: 24, height: 24)
                        }
                        hoverTitleLabelView(labelSize: labelSize)
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .dockStyle(cornerRadius: 10)
                    Spacer()
                }
                .offset(y: -30)
            default:
                EmptyView()
            }
        }
    }
    
    @ViewBuilder
    private func hoverTitleLabelView(labelSize: CGSize) -> some View {
        switch hoverTitleStyle {
        case 0: // Default
            Text(appName)
                .lineLimit(1)
                .padding(3)
                .fontWeight(.medium)
                .font(.system(size: 14))
                .padding(.horizontal, 4)
                .shadow(stacked: 2, radius: 6)
                .background(
                    ZStack {
                        MaterialBlurView(material: .hudWindow)
                            .mask(
                                Ellipse()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(
                                                colors: [
                                                    Color.white.opacity(1.0),
                                                    Color.white.opacity(0.35)
                                                ]
                                            ),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            )
                            .blur(radius: 5)
                    }
                        .frame(width: labelSize.width + 30)
                )
        case 1, 2: // Embed + Popover
            Text(appName)
        default:
            EmptyView()
        }
    }

    private var minimizedOrHiddenWindowsView: some View {
        ScrollView(dockPosition == .bottom ? .vertical : .horizontal) {
            DynStack(direction: dockPosition == .bottom ? .vertical : .horizontal, spacing: 4) {
                ForEach(minimizedOrHiddenWindows.indices, id: \.self) { index in
                    WindowPreview(
                        windowInfo: minimizedOrHiddenWindows[index],
                        onTap: onWindowTap,
                        index: index,
                        dockPosition: dockPosition,
                        maxWindowDimension: maxWindowDimension,
                        bestGuessMonitor: bestGuessMonitor, 
                        uniformCardRadius: true // force it to be rounded, since these have no image previews
                    )
                }
            }
        }
        .frame(maxWidth: dockPosition != .bottom ? maxWindowDimension.x : nil, maxHeight: dockPosition == .bottom ? maxWindowDimension.y : nil)
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
        if let bundleID = windows.first?.bundleID, let icon = AppIconUtil.getIcon(bundleID: bundleID) {
            DispatchQueue.main.async {
                self.appIcon = icon
            }
        }
    }
}
