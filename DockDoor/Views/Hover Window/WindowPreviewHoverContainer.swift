//
//  HoverView.swift
//  DockDoor
//
//  Created by Ethan Bills on 7/11/24.
//

import SwiftUI
import Defaults

struct WindowPreviewHoverContainer: View {
    let appName: String
    let windows: [WindowInfo]
    let onWindowTap: (() -> Void)?
    let dockPosition: DockPosition
    let bestGuessMonitor: NSScreen
    
    @Default(.uniformCardRadius) var uniformCardRadius
    @Default(.windowTitleStyle) var windowTitleStyle
    @Default(.windowTitlePosition) var windowTitlePosition
    
    @State private var showWindows: Bool = false
    @State private var hasAppeared: Bool = false
    @State private var appIcon: NSImage? = nil
    
    var maxWindowDimension: CGPoint {
        let thickness = SharedPreviewWindowCoordinator.shared.windowSize.height
        var maxWidth: CGFloat = 300
        var maxHeight: CGFloat = 300
        
        for window in windows {
            if let cgImage = window.image {
                let cgSize = CGSize(width: cgImage.width, height: cgImage.height)
                let widthBasedOnHeight = (cgSize.width * thickness) / cgSize.height
                let heightBasedOnWidth = (cgSize.height * thickness) / cgSize.width
                
                if dockPosition == .bottom || ScreenCenteredFloatingWindow.shared.windowSwitcherActive {
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
        let orientationIsHorizontal = dockPosition == .bottom || ScreenCenteredFloatingWindow.shared.windowSwitcherActive
        ZStack {
            ScrollViewReader { scrollProxy in
                ScrollView(orientationIsHorizontal ? .horizontal : .vertical, showsIndicators: false) {
                    DynStack(direction: orientationIsHorizontal ? .horizontal : .vertical, spacing: 16) {
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
                    .onChange(of: ScreenCenteredFloatingWindow.shared.currIndex) { _, newIndex in
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
        .padding(.top, (!ScreenCenteredFloatingWindow.shared.windowSwitcherActive && windowTitleStyle == .embedded) ? 25 : 0) // Provide space above the window preview for the Embedded title style when hovering over the Dock.
        .dockStyle(cornerRadius: 16)
        .overlay(alignment: .topLeading) {
            hoverTitleBaseView(labelSize: measureString(appName, fontSize: 14))
        }
        .padding(.top, (!ScreenCenteredFloatingWindow.shared.windowSwitcherActive && windowTitleStyle == .popover) ? 30 : 0) // Provide empty space above the window preview for the Popover title style when hovering over the Dock
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
        if !ScreenCenteredFloatingWindow.shared.windowSwitcherActive {
            switch windowTitleStyle {
            case .default:
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
            case .embedded:
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
            case .popover:
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
        switch windowTitleStyle {
        case .default:
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
        case .embedded, .popover:
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
