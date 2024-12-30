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

    @State var windowStates: [WindowInfo]
    @State private var draggedWindowIndex: Int? = nil
    @State private var isDragging = false

    @State private var showWindows: Bool = false
    @State private var hasAppeared: Bool = false
    @State private var appIcon: NSImage? = nil
    @State private var hoveringAppIcon: Bool = false
    @State private var hoveringWindowTitle: Bool = false

    init(appName: String,
         windows: [WindowInfo],
         onWindowTap: (() -> Void)?,
         dockPosition: DockPosition,
         mouseLocation: CGPoint?,
         bestGuessMonitor: NSScreen,
         windowSwitcherCoordinator: ScreenCenteredFloatingWindowCoordinator)
    {
        self.appName = appName
        self.windows = windows
        _windowStates = State(initialValue: windows)
        self.onWindowTap = onWindowTap
        self.dockPosition = dockPosition
        self.mouseLocation = mouseLocation
        self.bestGuessMonitor = bestGuessMonitor
        self.windowSwitcherCoordinator = windowSwitcherCoordinator
    }

    var maxWindowDimension: CGPoint {
        let thickness = SharedPreviewWindowCoordinator.shared.windowSize.height
        var maxWidth: CGFloat = 300
        var maxHeight: CGFloat = 300

        let orientationIsHorizontal = dockPosition == .bottom || windowSwitcherCoordinator.windowSwitcherActive
        let maxAspectRatio: CGFloat = 1.5

        for window in windows {
            if let cgImage = window.image {
                let cgSize = CGSize(width: cgImage.width, height: cgImage.height)

                if orientationIsHorizontal {
                    // For horizontal layout (width based on height)
                    let rawWidthBasedOnHeight = (cgSize.width * thickness) / cgSize.height
                    // Limit width to maxAspectRatio times the height
                    let widthBasedOnHeight = min(rawWidthBasedOnHeight, thickness * maxAspectRatio)

                    maxWidth = max(maxWidth, widthBasedOnHeight)
                    maxHeight = thickness
                } else {
                    // For vertical layout (height based on width)
                    let rawHeightBasedOnWidth = (cgSize.height * thickness) / cgSize.width
                    // Limit height to maxAspectRatio times the width
                    let heightBasedOnWidth = min(rawHeightBasedOnWidth, thickness * maxAspectRatio)

                    maxHeight = max(maxHeight, heightBasedOnWidth)
                    maxWidth = thickness
                }
            }
        }

        return CGPoint(x: maxWidth, y: maxHeight)
    }

    var body: some View {
        let orientationIsHorizontal = dockPosition == .bottom || windowSwitcherCoordinator.windowSwitcherActive

        ScrollViewReader { scrollProxy in
            buildFlowStack(windows: windowStates, scrollProxy: scrollProxy, orientationIsHorizontal)
                .padding(.top, (!windowSwitcherCoordinator.windowSwitcherActive && appNameStyle == .default && showAppName) ? 25 : 0)
                .overlay(alignment: .topLeading) {
                    hoverTitleBaseView(labelSize: measureString(appName, fontSize: 14))
                        .onHover { isHovered in
                            withAnimation(.snappy) { hoveringWindowTitle = isHovered }
                        }
                }
                .dockStyle(cornerRadius: 16)
                .padding(.top, (!windowSwitcherCoordinator.windowSwitcherActive && appNameStyle == .popover && showAppName) ? 30 : 0)
                .overlay {
                    if let mouseLocation, !isDragging {
                        WindowDismissalContainer(appName: appName, mouseLocation: mouseLocation,
                                                 bestGuessMonitor: bestGuessMonitor, dockPosition: dockPosition)
                            .allowsHitTesting(false)
                    }
                }
                .padding(.all, 24)
                .frame(maxWidth: bestGuessMonitor.visibleFrame.width, maxHeight: bestGuessMonitor.visibleFrame.height)
                .opacity(showWindows ? 1 : 0.35)
        }
    }

    private func handleWindowDrop(at location: CGPoint, for index: Int) {
        guard index < windowStates.count else { return }
        let window = windowStates[index]

        // Get the screen containing the drop location
        let currentScreen = NSScreen.screenContainingMouse(location)

        // Convert drop location to global coordinates
        let globalLocation = DockObserver.cgPointFromNSPoint(location, forScreen: currentScreen)

        // Calculate position (placing from top left corner)
        let finalPosition = CGPoint(
            x: globalLocation.x,
            y: globalLocation.y
        )

        // Move the window
        if let positionValue = AXValue.from(point: finalPosition) {
            try? window.axElement.setAttribute(kAXPositionAttribute, positionValue)
            WindowUtil.bringWindowToFront(windowInfo: window)
            onWindowTap?()
        }
    }

    @ViewBuilder
    private func hoverTitleBaseView(labelSize: CGSize) -> some View {
        if !windowSwitcherCoordinator.windowSwitcherActive, showAppName {
            Group {
                switch appNameStyle {
                case .default:
                    HStack(alignment: .center) {
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

                        massOperations(hoveringAppIcon)
                    }
                    .padding(.top, 10)
                    .padding(.leading)
                    .animation(.spring(response: 0.3), value: hoveringAppIcon)

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

                        massOperations(hoveringAppIcon)
                    }
                    .padding(EdgeInsets(top: -11.5, leading: 15, bottom: -1.5, trailing: 1.5))
                    .animation(.spring(response: 0.3), value: hoveringAppIcon)

                case .popover:
                    HStack {
                        Spacer()
                        HStack(alignment: .center, spacing: 2) {
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

                            massOperations(hoveringAppIcon)
                        }
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .dockStyle(cornerRadius: 10)
                        Spacer()
                    }
                    .offset(y: -30)
                    .animation(.spring(response: 0.3), value: hoveringAppIcon)
                }
            }
            .onHover { hover in
                hoveringAppIcon = hover
            }
        }
    }

    @ViewBuilder
    func massOperations(_ shouldDisplay: Bool) -> some View {
        if shouldDisplay {
            Group {
                Button("Close All") {
                    closeAllWindows()
                }
                .buttonStyle(AccentButtonStyle(small: true))

                Button("Minimize All") {
                    minimizeAllWindows()
                }
                .buttonStyle(AccentButtonStyle(small: true))
            }
            .transition(.opacity)
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

    @ViewBuilder
    private func buildFlowStack(windows: [WindowInfo], scrollProxy: ScrollViewProxy, _ isHorizontal: Bool) -> some View {
        let dimensionsMap = precomputeWindowDimensions()
        let layout = calculateOptimalLayout(windowDimensions: dimensionsMap, isHorizontal: isHorizontal)

        ScrollView(isHorizontal ? .horizontal : .vertical, showsIndicators: false) {
            DynStack(direction: isHorizontal ? .vertical : .horizontal, spacing: 16) {
                ForEach(Array(layout.windowsPerStack.enumerated()), id: \.offset) { _, range in
                    DynStack(direction: isHorizontal ? .horizontal : .vertical, spacing: 16) {
                        ForEach(windowStates.indices, id: \.self) { index in
                            if range.contains(index) {
                                WindowPreview(
                                    windowInfo: windowStates[index],
                                    onTap: onWindowTap,
                                    index: index,
                                    dockPosition: dockPosition,
                                    maxWindowDimension: maxWindowDimension,
                                    bestGuessMonitor: bestGuessMonitor,
                                    uniformCardRadius: uniformCardRadius,
                                    handleWindowAction: { action in
                                        handleWindowAction(action, at: index)
                                    },
                                    currIndex: windowSwitcherCoordinator.currIndex,
                                    windowSwitcherActive: windowSwitcherCoordinator.windowSwitcherActive,
                                    dimensions: getDimensions(for: index, dimensionsMap: dimensionsMap)
                                )
                                .id("\(appName)-\(index)")
                                .animation(.snappy(duration: 0.175), value: windowStates)
                                .gesture(
                                    DragGesture(minimumDistance: 3, coordinateSpace: .global)
                                        .onChanged { value in
                                            if draggedWindowIndex == nil {
                                                draggedWindowIndex = index
                                                isDragging = true
                                                DragPreviewCoordinator.shared.startDragging(
                                                    windowInfo: windowStates[index],
                                                    at: NSEvent.mouseLocation
                                                )
                                            }
                                            if draggedWindowIndex == index {
                                                DragPreviewCoordinator.shared.updatePreviewPosition(to: NSEvent.mouseLocation)
                                            }
                                        }
                                        .onEnded { value in
                                            if draggedWindowIndex == index {
                                                handleWindowDrop(at: NSEvent.mouseLocation, for: index)
                                                DragPreviewCoordinator.shared.endDragging()
                                                draggedWindowIndex = nil
                                                isDragging = false
                                            }
                                        }
                                )
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .onAppear {
            if !hasAppeared {
                hasAppeared.toggle()
                runUIUpdates(preventOpacityChange: false)
            }
        }
        .onChange(of: windowSwitcherCoordinator.currIndex) { newIndex in
            withAnimation {
                scrollProxy.scrollTo("\(appName)-\(newIndex)", anchor: .center)
            }
        }
        .onChange(of: windows) { _ in
            runUIUpdates(preventOpacityChange: true)
        }
    }

    // Helper function to create window preview with dimensions
    @ViewBuilder
    private func createWindowPreview(index: Int, scrollProxy: ScrollViewProxy, dimensions: WindowDimensions) -> some View {
        WindowPreview(
            windowInfo: windowStates[index],
            onTap: onWindowTap,
            index: index,
            dockPosition: dockPosition,
            maxWindowDimension: maxWindowDimension,
            bestGuessMonitor: bestGuessMonitor,
            uniformCardRadius: uniformCardRadius,
            handleWindowAction: { action in
                handleWindowAction(action, at: index)
            },
            currIndex: windowSwitcherCoordinator.currIndex,
            windowSwitcherActive: windowSwitcherCoordinator.windowSwitcherActive,
            dimensions: dimensions
        )
        .opacity(draggedWindowIndex == index ? 0.3 : 1.0)
        .id("\(appName)-\(index)")
        .gesture(
            DragGesture(minimumDistance: 3, coordinateSpace: .global)
                .onChanged { value in
                    if draggedWindowIndex == nil {
                        draggedWindowIndex = index
                        isDragging = true
                        DragPreviewCoordinator.shared.startDragging(
                            windowInfo: windowStates[index],
                            at: NSEvent.mouseLocation
                        )
                    }
                    if draggedWindowIndex == index {
                        DragPreviewCoordinator.shared.updatePreviewPosition(to: NSEvent.mouseLocation)
                    }
                }
                .onEnded { value in
                    if draggedWindowIndex == index {
                        handleWindowDrop(at: NSEvent.mouseLocation, for: index)
                        DragPreviewCoordinator.shared.endDragging()
                        draggedWindowIndex = nil
                        isDragging = false
                    }
                }
        )
    }

    private func runUIUpdates(preventOpacityChange: Bool) {
        if !preventOpacityChange { runAnimation() }
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

    private func closeAllWindows() {
        windowStates.removeAll()
        windows.forEach { WindowUtil.closeWindow(windowInfo: $0) }
    }

    private func minimizeAllWindows() {
        windowStates.removeAll()
        windows.forEach { _ = WindowUtil.toggleMinimize(windowInfo: $0) }
    }

    private func handleWindowAction(_ action: WindowAction, at index: Int) {
        guard index < windowStates.count else { return }
        var window = windowStates[index]

        withAnimation(.snappy(duration: 0.175)) {
            switch action {
            case .quit:
                WindowUtil.quitApp(windowInfo: window, force: NSEvent.modifierFlags.contains(.option))
                onWindowTap?()

            case .close:
                WindowUtil.closeWindow(windowInfo: window)
                windowStates.remove(at: index)

                if windowStates.isEmpty {
                    onWindowTap?()
                }

            case .minimize:
                if let newMinimizedState = WindowUtil.toggleMinimize(windowInfo: window) {
                    window.isMinimized = newMinimizedState
                    windowStates[index] = window
                }

            case .toggleFullScreen:
                WindowUtil.toggleFullScreen(windowInfo: window)
                onWindowTap?()

            case .hide:
                if let newHiddenState = WindowUtil.toggleHidden(windowInfo: window) {
                    window.isHidden = newHiddenState
                    windowStates[index] = window
                }
            }
        }
    }
}
