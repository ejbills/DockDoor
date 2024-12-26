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

    @State private var windowStates: [WindowInfo]
    @State private var draggedWindowIndex: Int? = nil
    @State private var isDragging = false

    @State private var showWindows: Bool = false
    @State private var hasAppeared: Bool = false
    @State private var appIcon: NSImage? = nil
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
            if let mouseLocation, !isDragging {
                WindowDismissalContainer(appName: appName, mouseLocation: mouseLocation,
                                         bestGuessMonitor: bestGuessMonitor, dockPosition: dockPosition)
            }

            ScrollViewReader { scrollProxy in
                buildFlowStack(windows: windowStates, scrollProxy: scrollProxy, orientationIsHorizontal)
                    .padding(.top, (!windowSwitcherCoordinator.windowSwitcherActive && appNameStyle == .default && showAppName) ? 25 : 0)
                    .dockStyle(cornerRadius: 16)
                    .overlay(alignment: .topLeading) {
                        hoverTitleBaseView(labelSize: measureString(appName, fontSize: 14))
                            .onHover { isHovered in
                                withAnimation(.snappy) { hoveringWindowTitle = isHovered }
                            }
                    }
                    .padding(.top, (!windowSwitcherCoordinator.windowSwitcherActive && appNameStyle == .popover && showAppName) ? 30 : 0)
                    .padding(.all, 24)
                    .frame(maxWidth: bestGuessMonitor.visibleFrame.width, maxHeight: bestGuessMonitor.visibleFrame.height)
            }
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
                                .opacity(draggedWindowIndex == index ? 0.3 : 1.0)
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
        .opacity(showWindows ? 1 : 0.8)
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

// Extension to handle window size calculations
extension WindowPreviewHoverContainer {
    struct WindowDimensions {
        let size: CGSize
        let maxDimensions: CGSize
    }

    func precomputeWindowDimensions() -> [Int: WindowDimensions] {
        var dimensionsMap: [Int: WindowDimensions] = [:]
        let maxAllowedWidth = maxWindowDimension.x
        let maxAllowedHeight = maxWindowDimension.y
        let calculatedMaxDimensions = CGSize(
            width: bestGuessMonitor.frame.width * 0.75,
            height: bestGuessMonitor.frame.height * 0.75
        )

        for (index, windowInfo) in windowStates.enumerated() {
            guard let cgImage = windowInfo.image else {
                dimensionsMap[index] = WindowDimensions(size: .zero, maxDimensions: calculatedMaxDimensions)
                continue
            }

            let cgSize = CGSize(width: cgImage.width, height: cgImage.height)
            let aspectRatio = cgSize.width / cgSize.height

            var targetWidth = maxAllowedWidth
            var targetHeight = targetWidth / aspectRatio

            if targetHeight > maxAllowedHeight {
                targetHeight = maxAllowedHeight
                targetWidth = aspectRatio * targetHeight
            }

            dimensionsMap[index] = WindowDimensions(
                size: CGSize(width: targetWidth, height: targetHeight),
                maxDimensions: calculatedMaxDimensions
            )
        }

        return dimensionsMap
    }

    // Helper method to get dimensions for a specific window
    func getDimensions(for index: Int, dimensionsMap: [Int: WindowDimensions]) -> WindowDimensions {
        dimensionsMap[index] ?? WindowDimensions(
            size: .zero,
            maxDimensions: CGSize(
                width: bestGuessMonitor.frame.width * 0.75,
                height: bestGuessMonitor.frame.height * 0.75
            )
        )
    }
}

extension WindowPreviewHoverContainer {
    // Calculate optimal number of stacks and window distribution
    func calculateOptimalLayout(windowDimensions: [Int: WindowDimensions], isHorizontal: Bool) -> (stackCount: Int, windowsPerStack: [Range<Int>]) {
        let activeWindowCount = windowStates.count

        // Handle case when all windows are closed
        guard activeWindowCount > 0 else {
            return (1, [0 ..< 0])
        }

        let visibleFrame = bestGuessMonitor.visibleFrame

        if isHorizontal {
            let maxStackHeight = windowDimensions.values.map(\.size.height).max() ?? 0
            let maxStacks = Int(visibleFrame.height / maxStackHeight)
            let optimalStacks = min(max(1, maxStacks), activeWindowCount)

            return distributeWindows(windowCount: activeWindowCount, stackCount: optimalStacks)
        } else {
            let maxStackHeight = windowDimensions.values.map(\.size.height).max() ?? 0
            let windowsPerColumn = max(1, Int(visibleFrame.height / maxStackHeight))

            let totalColumns = Int(ceil(Double(activeWindowCount) / Double(windowsPerColumn)))

            var ranges: [Range<Int>] = []
            var startIndex = 0

            for _ in 0 ..< totalColumns {
                let windowsInThisColumn = min(
                    windowsPerColumn,
                    activeWindowCount - startIndex
                )

                let endIndex = startIndex + windowsInThisColumn
                ranges.append(startIndex ..< endIndex)
                startIndex = endIndex

                if startIndex >= activeWindowCount {
                    break
                }
            }

            return (ranges.count, ranges)
        }
    }

    // Helper function to distribute windows evenly across stacks
    private func distributeWindows(windowCount: Int, stackCount: Int) -> (stackCount: Int, windowsPerStack: [Range<Int>]) {
        let baseWindowsPerStack = windowCount / stackCount
        let remainingWindows = windowCount % stackCount

        var ranges: [Range<Int>] = []
        var startIndex = 0

        for stack in 0 ..< stackCount {
            let extraWindow = stack < remainingWindows ? 1 : 0
            let stackSize = baseWindowsPerStack + extraWindow
            let endIndex = startIndex + stackSize
            ranges.append(startIndex ..< endIndex)
            startIndex = endIndex
        }

        return (stackCount, ranges)
    }
}
