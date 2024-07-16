//
//  WindowPreview.swift
//  DockDoor
//
//  Created by Ethan Bills on 7/4/24.
//

import SwiftUI
import Defaults

struct WindowPreview: View {
    let window: Window
    let onTap: (() -> Void)?
    let index: Int
    let dockPosition: DockPosition
    let maxWindowDimension: CGPoint
    let bestGuessMonitor: NSScreen
    let uniformCardRadius: Bool
    
    @Default(.windowTitlePosition) var windowTitlePosition
    @Default(.showWindowTitle) var showWindowTitle
    @Default(.windowTitleDisplayCondition) var windowTitleDisplayCondition
    @Default(.windowTitleVisibility) var windowTitleVisibility
    @Default(.trafficLightButtonsVisibility) var trafficLightButtonsVisibility
    @Default(.trafficLightButtonsPosition) var trafficLightButtonsPosition
    
    // preview popup action handlers
    @Default(.tapEquivalentInterval) var tapEquivalentInterval
    @Default(.previewHoverAction) var previewHoverAction
    
    @State private var isHoveringOverDockPeekPreview = false
    @State private var isHoveringOverWindowSwitcherPreview = false
    @State private var fullPreviewTimer: Timer?
    
    private var calculatedMaxDimensions: CGSize {
        CGSize(width: self.bestGuessMonitor.frame.width * 0.75, height: self.bestGuessMonitor.frame.height * 0.75)
    }
    
    var calculatedSize: CGSize {
        guard let cgImage = window.image else { return .zero }
        
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
    
    private func windowContent(isSelected: Bool) -> some View {
        Group {
            if let cgImage = window.image {
                let image = Image(decorative: cgImage, scale: 1.0).resizable().aspectRatio(contentMode: .fill)
                image.overlay(!isSelected ? nil : fluidGradient().opacity(0.125).mask(image))
            }
        }
        .frame(width: calculatedSize.width,
               height: calculatedSize.height,
               alignment: .center)
        .frame(maxWidth: calculatedMaxDimensions.width, maxHeight: calculatedMaxDimensions.height)
    }
    
    var body: some View {
        let isHighlightedInWindowSwitcher = (index == ScreenCenteredFloatingWindow.shared.currIndex && ScreenCenteredFloatingWindow.shared.windowSwitcherActive)
        let selected = isHoveringOverDockPeekPreview || isHighlightedInWindowSwitcher
        
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                windowContent(isSelected: selected)
                    .overlay { Color.white.opacity(isHoveringOverWindowSwitcherPreview ? 0.1 : 0) }
                    .shadow(radius: selected || isHoveringOverWindowSwitcherPreview ? 0 : 3)
                    .background {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.clear.shadow(.drop(color: .black.opacity(selected ? 0.35 : 0.25), radius: selected ? 12 : 8, y: selected ? 6 : 4)))
                    }
                    .clipShape(uniformCardRadius ? AnyShape(RoundedRectangle(cornerRadius: 6, style: .continuous)) : AnyShape(Rectangle()))
            }
            .overlay(alignment: {
                switch windowTitlePosition {
                case .bottomLeft:
                    return .bottomLeading
                case .bottomRight:
                    return .bottomTrailing
                case .topRight:
                    return .topTrailing
                case .topLeft:
                    return .topLeading
                }
            }()) {
                if  showWindowTitle && (windowTitleDisplayCondition == .all || (windowTitleDisplayCondition == .windowSwitcherOnly && ScreenCenteredFloatingWindow.shared.windowSwitcherActive) || (windowTitleDisplayCondition == .dockPreviewsOnly && !ScreenCenteredFloatingWindow.shared.windowSwitcherActive)) {
                    windowTitleOverlay(selected: selected)
                }
            }
            .overlay(alignment: {
                switch trafficLightButtonsPosition {
                case .bottomLeft:
                    return .bottomLeading
                case .bottomRight:
                    return .bottomTrailing
                case .topRight:
                    return .topTrailing
                case .topLeft:
                    return .topLeading
                }
            }()) {
                if let _ = window.closeButton {
                    TrafficLightButtons(
                        window: window,
                        displayMode: trafficLightButtonsVisibility,
                        hoveringOverParentWindow: selected || isHoveringOverWindowSwitcherPreview,
                        onAction: {
                            onTap?()
                        }
                    )
                }
            }
        }
        .scaleEffect(selected ? 1.015 : 1)
        .contentShape(Rectangle())
        .onHover { over in
            withAnimation(.snappy(duration: 0.175)) {
                if (!ScreenCenteredFloatingWindow.shared.windowSwitcherActive) {
                    isHoveringOverDockPeekPreview = over
                    handleFullPreviewHover(isHovering: over, action: previewHoverAction)
                } else {
                    isHoveringOverWindowSwitcherPreview = over
                }
            }
        }
        .onTapGesture {
            handleWindowTap()
        }
    }
    
    private func handleFullPreviewHover(isHovering: Bool, action: PreviewHoverAction) {
        if isHovering && !ScreenCenteredFloatingWindow.shared.windowSwitcherActive {
            switch action {
            case .none:
                // Do nothing for .none
                break
                
            case .tap:
                // If the interval is 0, immediately trigger the tap action
                if tapEquivalentInterval == 0 {
                    handleWindowTap()
                } else {
                    // Set a timer to trigger the tap action after the specified interval
                    fullPreviewTimer = Timer.scheduledTimer(withTimeInterval: tapEquivalentInterval, repeats: false) { [self] _ in
                        DispatchQueue.main.async {
                            handleWindowTap()
                        }
                    }
                }
                
            case .previewFullSize:
                // If the interval is 0, show the full window preview immediately
                if tapEquivalentInterval == 0 {
                    DispatchQueue.main.async {
                        SharedPreviewWindowCoordinator.shared.showPreviewWindow(
                            appName: window.appName,
                            windows: [window],
                            mouseScreen: bestGuessMonitor,
                            overrideDelay: true,
                            centeredHoverWindowState: .fullWindowPreview
                        )
                    }
                } else {
                    // If the interval is greater than 0, set a timer to show the full window preview after the specified interval
                    fullPreviewTimer = Timer.scheduledTimer(withTimeInterval: tapEquivalentInterval, repeats: false) { [self] _ in
                        DispatchQueue.main.async {
                            SharedPreviewWindowCoordinator.shared.showPreviewWindow(
                                appName: window.appName,
                                windows: [window],
                                mouseScreen: bestGuessMonitor,
                                overrideDelay: true,
                                centeredHoverWindowState: .fullWindowPreview
                            )
                        }
                    }
                }
            }
        } else {
            // If the hover state is not active or the window switcher is active, invalidate the timer
            fullPreviewTimer?.invalidate()
            fullPreviewTimer = nil
        }
    }
    
    private func handleWindowTap() {
        if (window.isMinimized) {
            window.toggleMinimize()
        }
        window.focus()
        onTap?()
    }
    
    @ViewBuilder
    private func windowTitleOverlay(selected: Bool) -> some View {
        if (windowTitleVisibility == .alwaysVisible || selected), let windowTitle = window.title, !windowTitle.isEmpty, (windowTitle != window.appName || ScreenCenteredFloatingWindow.shared.windowSwitcherActive) {
            let maxLabelWidth = calculatedSize.width - 50
            let stringMeasurementWidth = measureString(windowTitle, fontSize: 12).width + 5
            let width = maxLabelWidth > stringMeasurementWidth ? stringMeasurementWidth : maxLabelWidth
            
            TheMarquee(width: width, secsBeforeLooping: 1, speedPtsPerSec: 20, nonMovingAlignment: .leading) {
                Text(window.title ?? "Hidden window")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .padding(4)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(.ultraThinMaterial))
            .padding(4)
        }
    }
}
