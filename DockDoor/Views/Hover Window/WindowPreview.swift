//
//  WindowPreview.swift
//  DockDoor
//
//  Created by Ethan Bills on 7/4/24.
//

import SwiftUI
import Defaults
import FluidGradient

struct WindowPreview: View {
    let windowInfo: WindowInfo
    let onTap: (() -> Void)?
    let index: Int
    let dockPosition: DockPosition
    let maxWindowDimension: CGPoint
    let bestGuessMonitor: NSScreen
    let uniformCardRadius: Bool
    
    @Default(.windowTitlePosition) var windowTitlePosition
    @Default(.showWindowTitle) var showWindowTitle
    @Default(.windowTitleDisplayCondition) var windowTitleDisplayCondition
    @Default(.trafficLightButtonsVisibility) var trafficLightButtonsVisibility
    
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
    
    private func fluidGradient() -> some View {
        FluidGradient(
            blobs: [.purple, .blue, .green, .yellow, .red, .purple].shuffled(),
            highlights: [.red, .orange, .pink, .blue, .purple].shuffled(),
            speed: 0.45,
            blur: 0.75
        )
        .opacity(0.125)
    }
    
    private func windowContent(isMinimized: Bool, isHidden: Bool, isSelected: Bool) -> some View {
        Group {
            if isMinimized || isHidden {
                let width = maxWindowDimension.x > 300 ? maxWindowDimension.x : 300
                let labelText = isMinimized ? "Minimized" : "Hidden"
                
                HStack(spacing: 16) {
                    Image(systemName: "eye.slash.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                    
                    Divider()
                    
                    VStack(alignment: .leading) {
                        Text(labelText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        TheMarquee(width: width - 100, secsBeforeLooping: 2, speedPtsPerSec: 30, nonMovingAlignment: .leading) {
                            Text(windowInfo.windowName ?? "\(labelText) window")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding()
                .frame(width: width)
                .frame(height: 60)
                .overlay { if isSelected { fluidGradient() }}
            } else if let cgImage = windowInfo.image {
                let image = Image(decorative: cgImage, scale: 1.0).resizable().aspectRatio(contentMode: .fill)
                image.overlay(!isSelected ? nil : fluidGradient().mask(image))
            }
        }
        .frame(width: isMinimized || isHidden ? nil : calculatedSize.width,
               height: isMinimized || isHidden ? nil : calculatedSize.height,
               alignment: .center)
        .frame(maxWidth: calculatedMaxDimensions?.width, maxHeight: calculatedMaxDimensions?.height)
    }
    
    var body: some View {
        let isHighlighted = (index == CurrentWindow.shared.currIndex && CurrentWindow.shared.showingTabMenu)
        let selected = isHovering || isHighlighted
        
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                windowContent(isMinimized: windowInfo.isMinimized, isHidden: windowInfo.isHidden, isSelected: selected)
                    .overlay { Color.white.opacity(isHoveringOverTabMenu ? 0.1 : 0) }
                    .shadow(radius: selected || isHoveringOverTabMenu ? 0 : 3)
                    .background {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.clear.shadow(.drop(color: .black.opacity(selected ? 0.35 : 0.25), radius: selected ? 12 : 8, y: selected ? 6 : 4)))
                    }
                    .clipShape(uniformCardRadius ? AnyShape(RoundedRectangle(cornerRadius: 6, style: .continuous)) : AnyShape(Rectangle()))
            }
            .overlay(alignment: windowTitlePosition == .bottomLeft ? .bottomLeading : .bottomTrailing) {
                if  showWindowTitle && ((windowTitleDisplayCondition == .always) || (windowTitleDisplayCondition == .windowSwitcherOnly && CurrentWindow.shared.showingTabMenu) || (windowTitleDisplayCondition == .dockPreviewsOnly && !CurrentWindow.shared.showingTabMenu)) {
                    windowTitleOverlay(selected: selected)
                }
            }
            .overlay(alignment: .topLeading) {
                if !windowInfo.isMinimized, !windowInfo.isHidden, let _ = windowInfo.closeButton {
                    TrafficLightButtons(windowInfo: windowInfo,
                                        displayMode: trafficLightButtonsVisibility,
                                        hoveringOverParentWindow: selected || isHoveringOverTabMenu,
                                        onAction: { onTap?() })
                }
            }
        }
        .scaleEffect(selected ? 1.015 : 1)
        .contentShape(Rectangle())
        .onHover { over in
            withAnimation(.snappy(duration: 0.175)) {
                if (!CurrentWindow.shared.showingTabMenu) {
                    isHovering = over
                } else {
                    isHoveringOverTabMenu = over
                }
            }
        }
        .onTapGesture {
            handleWindowTap()
        }
    }
    
    private func handleWindowTap() {
        if (windowInfo.isMinimized) {
            WindowUtil.toggleMinimize(windowInfo: windowInfo)
        } else if (windowInfo.isHidden) {
            WindowUtil.toggleHidden(windowInfo: windowInfo)
        } else {
            WindowUtil.bringWindowToFront(windowInfo: windowInfo)
        }
        onTap?()
    }
    
    @ViewBuilder
    private func windowTitleOverlay(selected: Bool) -> some View {
        if selected, let windowTitle = windowInfo.window?.title, !windowTitle.isEmpty, windowTitle != windowInfo.appName {
            let maxLabelWidth = calculatedSize.width - 50
            let stringMeasurementWidth = measureString(windowTitle, fontSize: 12).width + 5
            let width = maxLabelWidth > stringMeasurementWidth ? stringMeasurementWidth : maxLabelWidth
            
            TheMarquee(width: width, secsBeforeLooping: 1, speedPtsPerSec: 20, nonMovingAlignment: .leading) {
                Text(windowInfo.windowName ?? "Hidden window")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .padding(4)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(.ultraThinMaterial))
            .padding(4)
        }
    }
}
