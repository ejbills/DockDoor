//
//  SharedPreviewWindowCoordinator.swift
//  DockDoor
//
//  Created by Ethan Bills on 6/5/24.
//

import SwiftUI
import Defaults
import FluidGradient

@Observable class ScreenCenteredFloatingWindow {
    static let shared = ScreenCenteredFloatingWindow()
    
    var currIndex: Int = 0
    var windowSwitcherActive: Bool = false
    var fullWindowPreviewActive: Bool = false
    
    enum WindowState {
        case windowSwitcher
        case fullWindowPreview
        case both
    }
    
    func setShowing(_ state: WindowState? = .both, toState: Bool) {
        switch state {
        case .windowSwitcher:
            self.windowSwitcherActive = toState
        case .fullWindowPreview:
            self.fullWindowPreviewActive = toState
        case .both:
            self.windowSwitcherActive = toState
            self.fullWindowPreviewActive = toState
        case .none:
            return
        }
    }
    
    func setIndex(to: Int) {
        withAnimation(.easeInOut) {
            self.currIndex = to
        }
    }
}

final class SharedPreviewWindowCoordinator: NSWindow {
    static let shared = SharedPreviewWindowCoordinator()
    
    private var appName: String = ""
    private var windows: [Window] = []
    private var onWindowTap: (() -> Void)?
    private var hostingView: NSHostingView<WindowPreviewHoverContainer>?
    private var fullPreviewWindow: NSWindow?
    
    var windowSize: CGSize = getWindowSize()
    
    private var previousHoverWindowOrigin: CGPoint?
    
    private let debounceDelay: TimeInterval = 0.1
    private var debounceWorkItem: DispatchWorkItem?
    private var lastShowTime: Date?
    
    private init() {
        super.init(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        setupWindow()
    }
    
    // Setup window properties
    private func setupWindow() {
        level = .floating
        isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        backgroundColor = .clear
        hasShadow = false
        
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
        let trackingArea = NSTrackingArea(rect: self.frame, options: options, owner: self, userInfo: nil)
        contentView?.addTrackingArea(trackingArea)
    }
    
    // Hide the window and reset its state
    func hidePreviewWindow() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isVisible else { return }
            
            self.hideFullPreviewWindow()
            self.contentView = nil
            self.hostingView = nil
            self.appName = ""
            self.windows.removeAll()
            ScreenCenteredFloatingWindow.shared.setIndex(to: 0)
            ScreenCenteredFloatingWindow.shared.setShowing(.both, toState: false)
            self.orderOut(nil)
        }
    }
    
    // Update the content view size and position
    private func updateContentViewSizeAndPosition(mouseLocation: CGPoint? = nil, mouseScreen: NSScreen,
                                                  animated: Bool, centerOnScreen: Bool = false,
                                                  centeredHoverWindowState: ScreenCenteredFloatingWindow.WindowState? = nil) {
        guard hostingView != nil else { return }
        
        ScreenCenteredFloatingWindow.shared.setShowing(centeredHoverWindowState, toState: centerOnScreen)

        // Reset the hosting view
        let hoverView = WindowPreviewHoverContainer(appName: appName, windows: windows, onWindowTap: onWindowTap,
                                  dockPosition: DockUtils.shared.getDockPosition(), bestGuessMonitor: mouseScreen)
        let newHostingView = NSHostingView(rootView: hoverView)
        self.contentView = newHostingView
        self.hostingView = newHostingView

        let newHoverWindowSize = newHostingView.fittingSize
        
        let position = centerOnScreen ?
            centerWindowOnScreen(size: newHoverWindowSize, screen: mouseScreen) :
            calculateWindowPosition(mouseLocation: mouseLocation, windowSize: newHoverWindowSize, screen: mouseScreen)

        let finalFrame = CGRect(origin: position, size: newHoverWindowSize)
        applyWindowFrame(finalFrame, animated: animated)

        previousHoverWindowOrigin = position
    }

    // Show full preview window for a given window
    private func showFullPreviewWindow(for window: Window, on screen: NSScreen) {
        if fullPreviewWindow == nil {
            fullPreviewWindow = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
            fullPreviewWindow?.level = .floating
            fullPreviewWindow?.isOpaque = false
            fullPreviewWindow?.backgroundColor = .clear
            fullPreviewWindow?.hasShadow = true
        }
        
        let padding: CGFloat = 40
        let maxSize = CGSize(
            width: screen.visibleFrame.width - padding * 2,
            height: screen.visibleFrame.height - padding * 2
        )
        
        let previewView = FullSizePreviewView(window: window, maxSize: maxSize)
        let hostingView = NSHostingView(rootView: previewView)
        fullPreviewWindow?.contentView = hostingView
        
        let centerPoint = centerWindowOnScreen(size: maxSize, screen: screen)
        fullPreviewWindow?.setFrame(CGRect(origin: centerPoint, size: maxSize), display: true)
        fullPreviewWindow?.makeKeyAndOrderFront(nil)
    }
    
    func hideFullPreviewWindow() {
        fullPreviewWindow?.orderOut(nil)
        fullPreviewWindow = nil
    }
    
    // Center window on screen
    private func centerWindowOnScreen(size: CGSize, screen: NSScreen) -> CGPoint {
        return CGPoint(
            x: screen.frame.midX - (size.width / 2),
            y: screen.frame.midY - (size.height / 2)
        )
    }
    
    // Calculate window position based on the given dock icon frame and dock position
    private func calculateWindowPosition(mouseLocation: CGPoint?, windowSize: CGSize, screen: NSScreen) -> CGPoint {
        guard let mouseLocation = mouseLocation else { return .zero }
        
        let dockIconFrame = DockObserver.shared.getDockIconFrameAtLocation(mouseLocation) ?? .zero
        
        var xPosition = dockIconFrame.isEmpty ? mouseLocation.x : dockIconFrame.midX
        var yPosition = dockIconFrame.isEmpty ? mouseLocation.y : dockIconFrame.midY
        
        let screenFrame = screen.frame
        let dockPosition = DockUtils.shared.getDockPosition()
        let dockHeight = DockUtils.shared.calculateDockHeight(screen)
        
        // Adjust position based on dock position
           switch dockPosition {
           case .bottom:
               yPosition = screenFrame.minY + dockHeight
               xPosition -= (windowSize.width / 2)
           case .left:
               xPosition = screenFrame.minX + dockHeight
               yPosition = screenFrame.height - yPosition - (windowSize.height / 2)
           case .right:
               xPosition = screenFrame.maxX - dockHeight - windowSize.width
               yPosition = screenFrame.height - yPosition - (windowSize.height / 2)
           default:
               xPosition -= (windowSize.width / 2)
               yPosition -= (windowSize.height / 2)
           }
        
        // Ensure window stays within screen bounds
        xPosition = max(screenFrame.minX, min(xPosition, screenFrame.maxX - windowSize.width)) + (dockPosition != .bottom ? Defaults[.bufferFromDock] : 0)
        yPosition = max(screenFrame.minY, min(yPosition, screenFrame.maxY - windowSize.height)) + (dockPosition == .bottom ? Defaults[.bufferFromDock] : 0)
        
        return CGPoint(x: xPosition, y: yPosition)
    }
    
    
    // Apply window frame with optional animation
    private func applyWindowFrame(_ frame: CGRect, animated: Bool) {
        let shouldAnimate = animated && frame != self.frame
        
        if shouldAnimate {
            let distanceThreshold: CGFloat = 1800
            let distance = previousHoverWindowOrigin.map { frame.origin.distance(to: $0) } ?? distanceThreshold + 1
            
            if distance > distanceThreshold || !Defaults[.showAnimations] {
                setFrame(frame, display: true)
            } else {
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.2
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    self.animator().setFrame(frame, display: true)
                }, completionHandler: nil)
            }
        } else {
            setFrame(frame, display: true)
        }
    }
    
    // Show window with debounce logic
    func showPreviewWindow(appName: String, windows: [Window], mouseLocation: CGPoint? = nil, mouseScreen: NSScreen? = nil,
                    overrideDelay: Bool = false, centeredHoverWindowState: ScreenCenteredFloatingWindow.WindowState? = nil,
                    onWindowTap: (() -> Void)? = nil) {
        let now = Date()
        let delay = overrideDelay ? 0.0 : Defaults[.hoverWindowOpenDelay]
        
        debounceWorkItem?.cancel()
        
        let isHoverWindowShowing = self.isVisible
        
        if let lastShowTime = lastShowTime, now.timeIntervalSince(lastShowTime) < debounceDelay {
            let workItem = DispatchWorkItem { [weak self] in
                self?.performShowWindow(appName: appName, windows: windows, mouseLocation: mouseLocation, mouseScreen: mouseScreen, centeredHoverWindowState: centeredHoverWindowState, onWindowTap: onWindowTap)
            }
            
            debounceWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + debounceDelay, execute: workItem)
        } else {
            if isHoverWindowShowing || delay == 0.0 {
                performShowWindow(appName: appName, windows: windows, mouseLocation: mouseLocation, mouseScreen: mouseScreen, centeredHoverWindowState: centeredHoverWindowState, onWindowTap: onWindowTap)
            } else {
                let workItem = DispatchWorkItem { [weak self] in
                    self?.performShowWindow(appName: appName, windows: windows, mouseLocation: mouseLocation, mouseScreen: mouseScreen, centeredHoverWindowState: centeredHoverWindowState, onWindowTap: onWindowTap)
                }
                
                debounceWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
            }
        }
        
        lastShowTime = now
    }
    
    // Perform the actual window showing
    private func performShowWindow(appName: String, windows: [Window], mouseLocation: CGPoint?, mouseScreen: NSScreen?,
                                   centeredHoverWindowState: ScreenCenteredFloatingWindow.WindowState? = nil,
                                   onWindowTap: (() -> Void)?) {
        let shouldCenterOnScreen = centeredHoverWindowState != .none
        
        guard !windows.isEmpty else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let screen = mouseScreen ?? NSScreen.main!
            
            hideFullPreviewWindow() // clean up any lingering fullscreen previews before presenting a new one

            // If in full window preview mode, show the full preview window and return early
            if centeredHoverWindowState == .fullWindowPreview, let window = windows.first {
                showFullPreviewWindow(for: window, on: screen)
            } else {
                self.appName = appName
                self.windows = windows
                self.onWindowTap = onWindowTap
                
                self.updateHostingView(appName: appName, windows: windows, onWindowTap: onWindowTap, screen: screen)
                
                self.updateContentViewSizeAndPosition(mouseLocation: mouseLocation, mouseScreen: screen, animated: true,
                                                      centerOnScreen: shouldCenterOnScreen, centeredHoverWindowState: centeredHoverWindowState)
            }
                        
            self.makeKeyAndOrderFront(nil)
        }
    }
    
    // Update or create the hosting view
    private func updateHostingView(appName: String, windows: [Window], onWindowTap: (() -> Void)?, screen: NSScreen) {
        let hoverView = WindowPreviewHoverContainer(appName: appName, windows: windows, onWindowTap: onWindowTap,
                                                    dockPosition: DockUtils.shared.getDockPosition(), bestGuessMonitor: screen)
        
        if let existingHostingView = self.hostingView {
            existingHostingView.rootView = hoverView
        } else {
            let newHostingView = NSHostingView(rootView: hoverView)
            self.contentView = newHostingView
            self.hostingView = newHostingView
        }
    }
    
    // Cycle through windows
    func cycleWindows(goBackwards: Bool) {
        guard !windows.isEmpty else { return }
        
        let currentIndex = ScreenCenteredFloatingWindow.shared.currIndex
        let newIndex = (currentIndex + (goBackwards ? -1 : 1) + windows.count) % windows.count
        ScreenCenteredFloatingWindow.shared.setIndex(to: newIndex)
    }
    
    // Select and bring to front the current window
    func selectAndBringToFrontCurrentWindow() {
        guard !windows.isEmpty else { return }
        let selectedWindow = windows[ScreenCenteredFloatingWindow.shared.currIndex]
        selectedWindow.focus()
        hidePreviewWindow()
    }
}
