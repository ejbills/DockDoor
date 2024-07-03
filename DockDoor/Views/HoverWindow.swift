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
    
    @State private var showWindows: Bool = false
    @State private var hasAppeared: Bool = false
    @State private var appIcon: NSImage? = nil
    
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
                        if !minimizedWindows.isEmpty {
                            minimizedWindowsView
                        }
                        
                        ForEach(nonMinimizedWindows.indices, id: \.self) { index in
                            WindowPreview(windowInfo: nonMinimizedWindows[index], onTap: onWindowTap, index: index, dockPosition: dockPosition, maxWindowDimension: maxWindowDimension, bestGuessMonitor: bestGuessMonitor)
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
                let appNameLabelSize = measureString(appName, fontSize: 14)
                
                HStack(spacing: 2) {
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
                                .frame(width: appNameLabelSize.width + 30)
                        )
                }
                .padding(.horizontal, 3)
                .padding(.vertical, 1.5)
                .padding(EdgeInsets(top: -13, leading: 6, bottom: 0, trailing: 0))
            }
        }
        .padding(.all, 24)
        .frame(maxWidth: self.bestGuessMonitor.visibleFrame.width, maxHeight: self.bestGuessMonitor.visibleFrame.height)
    }
    
    private var minimizedWindows: [WindowInfo] {
        windows.filter { $0.isMinimized }
    }
    
    private var nonMinimizedWindows: [WindowInfo] {
        windows.filter { !$0.isMinimized }
    }
    
    private var minimizedWindowsView: some View {
        ScrollView(dockPosition == .bottom ? .vertical : .horizontal) {
            DynStack(direction: dockPosition == .bottom ? .vertical : .horizontal, spacing: 4) {
                ForEach(minimizedWindows.indices, id: \.self) { index in
                    WindowPreview(
                        windowInfo: minimizedWindows[index],
                        onTap: onWindowTap,
                        index: index,
                        dockPosition: dockPosition,
                        maxWindowDimension: maxWindowDimension,
                        bestGuessMonitor: bestGuessMonitor
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

struct WindowPreview: View {
    let windowInfo: WindowInfo
    let onTap: (() -> Void)?
    let index: Int
    let dockPosition: DockPosition
    let maxWindowDimension: CGPoint
    let bestGuessMonitor: NSScreen
    
    @State private var isHovering = false
    @State private var isHoveringOverTabMenu = false
    
    private var calculatedMaxDimensions: CGSize? {
        CGSize(width: self.bestGuessMonitor.frame.width * 0.75, height: self.bestGuessMonitor.frame.height * 0.75)
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
    
    private func windowContent(isMinimized: Bool) -> some View {
        Group {
            if isMinimized {
                let width = maxWindowDimension.x > 300 ? maxWindowDimension.x : 300
                
                HStack(spacing: 16) {
                    Image(systemName: "eye.slash.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                    
                    Divider()
                    
                    VStack(alignment: .leading) {
                        Text("Minimized")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        TheMarquee(width: width - 100, secsBeforeLooping: 2, speedPtsPerSec: 30, nonMovingAlignment: .leading) {
                            Text(windowInfo.windowName ?? "Hidden window")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding()
                .frame(width: width)
                .frame(height: 60)
            } else if let cgImage = windowInfo.image {
                Image(decorative: cgImage, scale: 1.0)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
        }
        .frame(width: isMinimized ? nil : calculatedSize.width, height: isMinimized ? nil : calculatedSize.height, alignment: .center)
        .frame(maxWidth: calculatedMaxDimensions?.width, maxHeight: calculatedMaxDimensions?.height)
    }
    
    var body: some View {
        let isHighlighted = (index == CurrentWindow.shared.currIndex && CurrentWindow.shared.showingTabMenu)
        let selected = isHovering || isHighlighted
        
        ZStack(alignment: .topTrailing) {
            windowContent(isMinimized: windowInfo.isMinimized)
                .overlay { AnimatedGradientOverlay(shouldDisplay: selected) }
                .overlay { Color.white.opacity(isHoveringOverTabMenu ? 0.1 : 0) }
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .shadow(radius: selected || isHoveringOverTabMenu ? 0 : 3)
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.clear.shadow(.drop(color: .black.opacity(selected ? 0.35 : 0.25), radius: selected ? 12 : 8, y: selected ? 6 : 4)))
                }
            
            if !windowInfo.isMinimized, let closeButton = windowInfo.closeButton {
                HStack(alignment:.top, spacing: 6) {
                    Button(action: {
                        WindowUtil.quitApp(windowInfo: windowInfo, force: NSEvent.modifierFlags.contains(.option))
                        onTap?()
                    }) {
                        ZStack {
                            Image(systemName: "circle.fill")
                                .foregroundStyle(.secondary)
                            Image(systemName: "power.circle.fill")
                        }
                    }
                    .buttonBorderShape(.roundedRectangle)
                    .foregroundStyle(.purple)
                    .buttonStyle(.plain)
                    .font(.system(size: 13))
                    
                    Button(action: {
                        WindowUtil.closeWindow(closeButton: closeButton)
                        onTap?()
                    }) {
                        ZStack {
                            Image(systemName: "circle.fill")
                                .foregroundStyle(.secondary)
                            Image(systemName: "xmark.circle.fill")
                        }
                    }
                    .buttonBorderShape(.roundedRectangle)
                    .foregroundStyle(.red)
                    .buttonStyle(.plain)
                    .font(.system(size: 13))
                    
                    Button(action: {
                        WindowUtil.toggleMinimize(windowInfo: windowInfo)
                        onTap?()
                    }) {
                        ZStack {
                            Image(systemName: "circle.fill")
                                .foregroundStyle(.secondary)
                            Image(systemName: "minus.circle.fill")
                        }
                    }
                    .buttonBorderShape(.roundedRectangle)
                    .foregroundStyle(.yellow)
                    .shadow(radius: 3)
                    .buttonStyle(.plain)
                    .font(.system(size: 13))
                    
                    Button(action: {
                        WindowUtil.toggleFullScreen(windowInfo: windowInfo)
                        onTap?()
                    }) {
                        ZStack {
                            Image(systemName: "circle.fill")
                                .foregroundStyle(.secondary)
                            Image(systemName: "arrow.up.left.and.arrow.down.right.circle.fill")
                        }
                    }
                    .buttonBorderShape(.roundedRectangle)
                    .foregroundStyle(.green)
                    .shadow(radius: 3)
                    .buttonStyle(.plain)
                    .font(.system(size: 13))
                    
                    Spacer()
                    
                    if selected, let windowTitle = windowInfo.window?.title, !windowTitle.isEmpty, windowTitle != windowInfo.appName {
                        let maxLabelWidth = calculatedSize.width - 150
                        let stringMeasurementWidth = measureString(windowTitle, fontSize: 12).width + 5
                        let width = maxLabelWidth > stringMeasurementWidth ? stringMeasurementWidth : maxLabelWidth
                        
                        TheMarquee(width: width, secsBeforeLooping: 3, speedPtsPerSec: 30, nonMovingAlignment: .leading) {
                            Text(windowInfo.windowName ?? "Hidden window")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.primary)
                        }
                        .padding(4)
                        .dockStyle(cornerRadius: 6)
                    }
                }
                .frame(alignment: .leading)
                .padding([.horizontal, .top], 6)
            }
        }
        .contentShape(Rectangle())
        .onHover { over in
            withAnimation(.snappy(duration: 0.175)) {
                if !CurrentWindow.shared.showingTabMenu {
                    isHovering = over
                } else {
                    isHoveringOverTabMenu = over
                }
            }
        }
        .onTapGesture {
            if windowInfo.isMinimized {
                WindowUtil.toggleMinimize(windowInfo: windowInfo)
            } else {
                WindowUtil.bringWindowToFront(windowInfo: windowInfo)
            }
            onTap?()
        }
    }
}
