import Defaults
import SwiftUI

struct WindowPreviewHoverContainer: View {
    let appName: String
    let windows: [WindowInfo]
    let onWindowTap: (() -> Void)?
    let dockPosition: DockPosition
    let mouseLocation: CGPoint?
    let bestGuessMonitor: NSScreen

    @ObservedObject var windowSwitcherCoordinator: ScreenCenteredFloatingWindowCoordinator

    @Default(.uniformCardRadius) var uniformCardRadius
    @Default(.showAppName) var showAppName
    @Default(.appNameStyle) var appNameStyle
    @Default(.windowTitlePosition) var windowTitlePosition

    @State private var showWindows: Bool = false
    @State private var hasAppeared: Bool = false
    @State private var appIcon: NSImage? = nil

    var maxWindowDimension: CGPoint {
        let thickness = SharedPreviewWindowCoordinator.shared.windowSize.height
        var maxWidth: CGFloat = 300
        var maxHeight: CGFloat = 300
        let isHorizontal = dockPosition == .bottom || windowSwitcherCoordinator.windowSwitcherActive

        for window in windows {
            if let cgImage = window.image {
                let cgSize = CGSize(width: cgImage.width, height: cgImage.height)
                let widthBasedOnHeight = (cgSize.width * thickness) / cgSize.height
                let heightBasedOnWidth = (cgSize.height * thickness) / cgSize.width

                if isHorizontal {
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
            if let mouseLocation {
                WindowDismissalContainer(appName: appName, mouseLocation: mouseLocation,
                                         bestGuessMonitor: bestGuessMonitor, dockPosition: dockPosition)
            }
            gridContainer()
        }
        .padding(.top, (!windowSwitcherCoordinator.windowSwitcherActive && appNameStyle == .default && showAppName) ? 25 : 0) // Provide space above the window preview for the Embedded (default) title style when hovering over the Dock.
        .dockStyle(cornerRadius: 16)
        .overlay(alignment: .topLeading) {
            hoverTitleBaseView(labelSize: measureString(appName, fontSize: 14))
        }
        .padding(.top, (!windowSwitcherCoordinator.windowSwitcherActive && appNameStyle == .popover && showAppName) ? 30 : 0) // Provide empty space above the window preview for the Popover title style when hovering over the Dock
        .padding(.all, 24)
        .frame(maxWidth: bestGuessMonitor.visibleFrame.width - 15, maxHeight: bestGuessMonitor.visibleFrame.height - 15)
    }

    private func gridContainer() -> some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.vertical, showsIndicators: false) {
                Group {
                    if GridLayoutVertical() {
                        LazyHGrid(rows: calculateGridInfo(), spacing: 25) {
                            gridContent
                        }
                    } else {
                        LazyVGrid(columns: calculateGridInfo(), spacing: 25) {
                            gridContent
                        }
                    }
                }.padding(14)
                    .onAppear {
                        if !hasAppeared {
                            hasAppeared.toggle()
                            runUIUpdates()
                        }
                    }
                    .onChange(of: windowSwitcherCoordinator.currIndex) { newIndex in
                        withAnimation {
                            scrollProxy.scrollTo("\(appName)-\(newIndex)", anchor: .center)
                        }
                    }
                    .onChange(of: windows) { _ in
                        runUIUpdates()
                    }
            }
            .opacity(showWindows ? 1 : 0.8)
        }
    }

    private var gridContent: some View {
        ForEach(windows.indices, id: \.self) { index in
            WindowPreview(windowInfo: windows[index],
                          onTap: onWindowTap,
                          index: index,
                          dockPosition: dockPosition,
                          maxWindowDimension: maxWindowDimension,
                          bestGuessMonitor: bestGuessMonitor,
                          uniformCardRadius: uniformCardRadius,
                          currIndex: windowSwitcherCoordinator.currIndex,
                          windowSwitcherActive: windowSwitcherCoordinator.windowSwitcherActive)
                .id("\(appName)-\(index)")
        }
    }

    @ViewBuilder
    private func hoverTitleBaseView(labelSize: CGSize) -> some View {
        if !windowSwitcherCoordinator.windowSwitcherActive, showAppName {
            switch appNameStyle {
            case .default:
                HStack(spacing: 2) {
                    if let appIcon {
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
            case .shadowed:
                HStack(spacing: 2) {
                    if let appIcon {
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
            case .popover:
                HStack {
                    Spacer()
                    HStack(spacing: 2) {
                        if let appIcon {
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
            }
        }
    }

    @ViewBuilder
    private func hoverTitleLabelView(labelSize: CGSize) -> some View {
        switch appNameStyle {
        case .shadowed:
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
                                                    Color.white.opacity(0.35),
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
        case .default, .popover:
            Text(appName)
        }
    }

    private func runUIUpdates() {
        runAnimation()
        loadAppIcon()
    }

    private func runAnimation() {
        showWindows = false

        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            showWindows = true
        }
    }

    private func loadAppIcon() {
        if let app = windows.first?.app, let icon = app.icon {
            DispatchQueue.main.async {
                appIcon = icon
            }
        }
    }

    private func GridLayoutVertical() -> Bool {
        var isVerticalGrid = false
        if windowSwitcherCoordinator.windowSwitcherActive {
            isVerticalGrid = false
        } else if mouseLocation != nil, dockPosition == .left || dockPosition == .right {
            isVerticalGrid = true
        } else if mouseLocation != nil, dockPosition == .bottom || dockPosition == .top {
            isVerticalGrid = false
        }
        return isVerticalGrid
    }

    private func calculateGridInfo() -> [GridItem] {
        let isVerticalGrid = GridLayoutVertical()
        let availablePixels = isVerticalGrid ? bestGuessMonitor.visibleFrame.height - 15 : bestGuessMonitor.visibleFrame.width - 15
        let maxColumnWidth = isVerticalGrid ? maxWindowDimension.y : maxWindowDimension.x
        var numberOfColumns = 0
        let maxNumberOfColumns = Int(availablePixels / maxColumnWidth)
        if windows.count < maxNumberOfColumns {
            numberOfColumns = windows.count
        } else {
            numberOfColumns = maxNumberOfColumns
        }
        return mouseLocation == nil ? Array(repeating: GridItem(.fixed(maxColumnWidth), spacing: 16), count: numberOfColumns) :
            Array(repeating: GridItem(.flexible(), spacing: 16), count: numberOfColumns)
    }
}
