import Defaults
import SwiftUI

struct WindowPreviewHoverContainer: View {
    let appName: String
    let windows: [WindowInfo]
    let onWindowTap: (() -> Void)?
    let dockPosition: DockPosition
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

        for window in windows {
            if let cgImage = window.image {
                let cgSize = CGSize(width: cgImage.width, height: cgImage.height)
                let widthBasedOnHeight = (cgSize.width * thickness) / cgSize.height
                let heightBasedOnWidth = (cgSize.height * thickness) / cgSize.width

                if dockPosition == .bottom || windowSwitcherCoordinator.windowSwitcherActive {
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
        let orientationIsHorizontal = dockPosition == .bottom || windowSwitcherCoordinator.windowSwitcherActive
        ZStack {
            ScrollViewReader { scrollProxy in
                ScrollView(orientationIsHorizontal ? .horizontal : .vertical, showsIndicators: false) {
                    DynStack(direction: orientationIsHorizontal ? .horizontal : .vertical, spacing: 16) {
                        ForEach(windows.indices, id: \.self) { index in
                            WindowPreview(windowInfo: windows[index], onTap: onWindowTap, index: index,
                                          dockPosition: dockPosition, maxWindowDimension: maxWindowDimension,
                                          bestGuessMonitor: bestGuessMonitor, uniformCardRadius: uniformCardRadius,
                                          currIndex: windowSwitcherCoordinator.currIndex, windowSwitcherActive: windowSwitcherCoordinator.windowSwitcherActive)
                                .id("\(appName)-\(index)")
                        }
                    }
                    .padding(14)
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
        .padding(.top, (!windowSwitcherCoordinator.windowSwitcherActive && appNameStyle == .embedded && showAppName) ? 25 : 0) // Provide space above the window preview for the Embedded title style when hovering over the Dock.
        .dockStyle(cornerRadius: 16)
        .overlay(alignment: .topLeading) {
            hoverTitleBaseView(labelSize: measureString(appName, fontSize: 14))
        }
        .padding(.top, (!windowSwitcherCoordinator.windowSwitcherActive && appNameStyle == .popover && showAppName) ? 30 : 0) // Provide empty space above the window preview for the Popover title style when hovering over the Dock
        .padding(.all, 24)
        .frame(maxWidth: bestGuessMonitor.visibleFrame.width, maxHeight: bestGuessMonitor.visibleFrame.height)
        .onHover { isHovering in
            let currentMouseLocation = DockObserver.getMousePosition()
            let dockIconFrame = DockObserver.shared.getDockIconFrameAtLocation(currentMouseLocation)

            let currentAppUnderMouse = DockObserver.shared.getCurrentAppUnderMouse()
            let lastAppUnderMouse = DockObserver.shared.lastAppUnderMouse

            print("isHovering: \(isHovering), Item: \(DockObserver.shared.getHoveredApplicationDockItem() != nil), current app: \(currentAppUnderMouse != nil), last app: \(lastAppUnderMouse != nil), dockIconFrame:  \(String(describing: dockIconFrame))")

            if !isHovering, currentAppUnderMouse == nil || currentAppUnderMouse != lastAppUnderMouse {
                SharedPreviewWindowCoordinator.shared.hideWindow()
                DockObserver.shared.lastAppUnderMouse = nil
            }
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
                .padding(EdgeInsets(top: -11.5, leading: 15, bottom: -1.5, trailing: 1.5))
            case .embedded:
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
        case .embedded, .popover:
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
}
