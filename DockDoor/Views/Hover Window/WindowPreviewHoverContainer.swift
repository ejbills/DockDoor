import Defaults
import ScreenCaptureKit
import SwiftUI

class MockPreviewWindow: WindowPropertiesProviding {
    var windowID: CGWindowID
    var frame: CGRect
    var title: String?
    var owningApplicationBundleIdentifier: String?
    var owningApplicationProcessID: pid_t?
    var isOnScreen: Bool
    var windowLayer: Int

    init(windowID: CGWindowID, frame: CGRect, title: String?, owningApplicationBundleIdentifier: String?, owningApplicationProcessID: pid_t?, isOnScreen: Bool, windowLayer: Int) {
        self.windowID = windowID
        self.frame = frame
        self.title = title
        self.owningApplicationBundleIdentifier = owningApplicationBundleIdentifier
        self.owningApplicationProcessID = owningApplicationProcessID
        self.isOnScreen = isOnScreen
        self.windowLayer = windowLayer
    }
}

struct WindowPreviewHoverContainer: View {
    let appName: String
    let windows: [WindowInfo]
    let onWindowTap: (() -> Void)?
    let dockPosition: DockPosition
    let mouseLocation: CGPoint?
    let bestGuessMonitor: NSScreen
    var mockPreviewActive: Bool

    @ObservedObject var windowSwitcherCoordinator: ScreenCenteredFloatingWindowCoordinator

    @Default(.uniformCardRadius) var uniformCardRadius
    @Default(.showAppName) var showAppTitleData
    @Default(.showAppIconOnly) var showAppIconOnly
    @Default(.appNameStyle) var appNameStyle
    @Default(.windowTitlePosition) var windowTitlePosition
    @Default(.aeroShakeAction) var aeroShakeAction
    @Default(.previewWrap) var previewWrap
    @Default(.switcherWrap) var switcherWrap

    @State var windowStates: [WindowInfo]
    @State private var draggedWindowIndex: Int? = nil
    @State private var isDragging = false

    @State private var hasAppeared: Bool = false
    @State private var appIcon: NSImage? = nil
    @State private var hoveringAppIcon: Bool = false
    @State private var hoveringWindowTitle: Bool = false

    @State private var dragPoints: [CGPoint] = []
    @State private var lastShakeCheck: Date = .init()

    init(appName: String,
         windows: [WindowInfo],
         onWindowTap: (() -> Void)?,
         dockPosition: DockPosition,
         mouseLocation: CGPoint?,
         bestGuessMonitor: NSScreen,
         windowSwitcherCoordinator: ScreenCenteredFloatingWindowCoordinator,
         mockPreviewActive: Bool)
    {
        self.appName = appName
        self.windows = windows
        _windowStates = State(initialValue: windows)
        self.onWindowTap = onWindowTap
        self.dockPosition = dockPosition
        self.mouseLocation = mouseLocation
        self.bestGuessMonitor = bestGuessMonitor
        self.windowSwitcherCoordinator = windowSwitcherCoordinator
        self.mockPreviewActive = mockPreviewActive
    }

    var maxWindowDimension: CGPoint {
        let thickness = mockPreviewActive ? 200 : SharedPreviewWindowCoordinator.shared.windowSize.height
        var maxWidth: CGFloat = 300
        var maxHeight: CGFloat = 300

        let orientationIsHorizontal = dockPosition == .bottom || windowSwitcherCoordinator.windowSwitcherActive
        let maxAspectRatio: CGFloat = 1.5

        for window in windows {
            if let cgImage = window.image {
                let cgSize = CGSize(width: cgImage.width, height: cgImage.height)

                if orientationIsHorizontal {
                    let rawWidthBasedOnHeight = (cgSize.width * thickness) / cgSize.height
                    let widthBasedOnHeight = min(rawWidthBasedOnHeight, thickness * maxAspectRatio)

                    maxWidth = max(maxWidth, widthBasedOnHeight)
                    maxHeight = thickness
                } else {
                    let rawHeightBasedOnWidth = (cgSize.height * thickness) / cgSize.width
                    let heightBasedOnWidth = min(rawHeightBasedOnWidth, thickness * maxAspectRatio)

                    maxHeight = max(maxHeight, heightBasedOnWidth)
                    maxWidth = thickness
                }
            }
        }

        return CGPoint(x: maxWidth, y: maxHeight)
    }

    var body: some View {
        let orientationIsHorizontal = dockPosition.isHorizontalFlow || windowSwitcherCoordinator.windowSwitcherActive

        ScrollViewReader { scrollProxy in
            buildFlowStack(windows: windowStates, scrollProxy: scrollProxy, orientationIsHorizontal)
                .padding(.top, (!windowSwitcherCoordinator.windowSwitcherActive && appNameStyle == .default && showAppTitleData) ? 25 : 0)
                .overlay(alignment: .topLeading) {
                    hoverTitleBaseView(labelSize: measureString(appName, fontSize: 14))
                        .onHover { isHovered in
                            withAnimation(.snappy) { hoveringWindowTitle = isHovered }
                        }
                }
                .dockStyle(cornerRadius: 16)
                .padding(.top, (!windowSwitcherCoordinator.windowSwitcherActive && appNameStyle == .popover && showAppTitleData) ? 30 : 0)
                .overlay {
                    if !mockPreviewActive, !isDragging {
                        WindowDismissalContainer(appName: appName,
                                                 bestGuessMonitor: bestGuessMonitor,
                                                 dockPosition: dockPosition,
                                                 minimizeAllWindowsCallback: { minimizeAllWindows() })
                            .allowsHitTesting(false)
                    }
                }
                .padding(.all, mockPreviewActive ? 0 : 24)
                .frame(maxWidth: bestGuessMonitor.visibleFrame.width, maxHeight: bestGuessMonitor.visibleFrame.height)
        }
    }

    private func handleWindowDrop(at location: CGPoint, for index: Int) {
        guard index < windowStates.count else { return }
        let window = windowStates[index]

        let currentScreen = NSScreen.screenContainingMouse(location)
        let globalLocation = DockObserver.cgPointFromNSPoint(location, forScreen: currentScreen)

        let finalPosition = CGPoint(
            x: globalLocation.x,
            y: globalLocation.y
        )

        if let positionValue = AXValue.from(point: finalPosition) {
            try? window.axElement.setAttribute(kAXPositionAttribute, positionValue)
            WindowUtil.bringWindowToFront(windowInfo: window)
            onWindowTap?()
        }
    }

    @ViewBuilder
    private func hoverTitleBaseView(labelSize: CGSize) -> some View {
        if !windowSwitcherCoordinator.windowSwitcherActive, showAppTitleData {
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
        if !showAppIconOnly {
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
    }

    @ViewBuilder
    private func buildFlowStack(windows: [WindowInfo], scrollProxy: ScrollViewProxy, _ isHorizontal: Bool) -> some View {
        let dimensionsMap = precomputeWindowDimensions()
        let wrap = windowSwitcherCoordinator.windowSwitcherActive ? switcherWrap : previewWrap
        let layout = calculateOptimalLayout(windowDimensions: dimensionsMap, isHorizontal: isHorizontal, wrap: wrap)

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
                                    dimensions: getDimensions(for: index, dimensionsMap: dimensionsMap),
                                    showAppIconOnly: showAppIconOnly,
                                    mockPreviewActive: mockPreviewActive
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
                                                let currentPoint = value.location
                                                if !windowSwitcherCoordinator.windowSwitcherActive, aeroShakeAction != .none,
                                                   checkForShakeGesture(currentPoint: currentPoint)
                                                {
                                                    DragPreviewCoordinator.shared.endDragging()
                                                    draggedWindowIndex = nil
                                                    isDragging = false

                                                    switch aeroShakeAction {
                                                    case .all:
                                                        minimizeAllWindows()
                                                    case .except:
                                                        minimizeAllWindows(windowStates[index])
                                                    default: break
                                                    }
                                                } else {
                                                    DragPreviewCoordinator.shared.updatePreviewPosition(to: NSEvent.mouseLocation)
                                                }
                                            }
                                        }
                                        .onEnded { value in
                                            if draggedWindowIndex == index {
                                                handleWindowDrop(at: NSEvent.mouseLocation, for: index)
                                                DragPreviewCoordinator.shared.endDragging()
                                                draggedWindowIndex = nil
                                                isDragging = false
                                                dragPoints.removeAll()
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
            loadAppIcon()
        }
        .onChange(of: windowSwitcherCoordinator.currIndex) { newIndex in
            withAnimation {
                scrollProxy.scrollTo("\(appName)-\(newIndex)", anchor: .center)
            }
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
        onWindowTap?()
        windowStates.removeAll()

        DispatchQueue.concurrentPerform(iterations: windows.count) { index in
            let window = windows[index]
            WindowUtil.closeWindow(windowInfo: window)
        }
    }

    private func minimizeAllWindows(_ except: WindowInfo? = nil) {
        onWindowTap?()

        if let except {
            WindowUtil.bringWindowToFront(windowInfo: except)

            windowStates.removeAll { $0 != except }

            DispatchQueue.concurrentPerform(iterations: windows.count) { index in
                let window = windows[index]
                guard !window.isMinimized else { return }
                if window != except {
                    _ = WindowUtil.toggleMinimize(windowInfo: window)
                }
            }

        } else {
            windowStates.removeAll()

            DispatchQueue.concurrentPerform(iterations: windows.count) { index in
                let window = windows[index]
                guard !window.isMinimized else { return }
                _ = WindowUtil.toggleMinimize(windowInfo: window)
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

    private func checkForShakeGesture(currentPoint: CGPoint) -> Bool {
        let now = Date()
        guard now.timeIntervalSince(lastShakeCheck) > 0.05 else { return false }
        lastShakeCheck = now

        dragPoints.append(currentPoint)

        if dragPoints.count > 20 {
            dragPoints.removeFirst(dragPoints.count - 20)
        }

        guard dragPoints.count >= 8 else { return false }

        var directionChanges = 0
        var velocities: [(dx: CGFloat, dy: CGFloat)] = []

        for i in 1 ..< dragPoints.count {
            let prev = dragPoints[i - 1]
            let curr = dragPoints[i]
            let dx = curr.x - prev.x
            let dy = curr.y - prev.y
            velocities.append((dx: dx, dy: dy))
        }

        for i in 1 ..< velocities.count {
            let prev = velocities[i - 1]
            let curr = velocities[i]

            let significantX = abs(prev.dx) > 5 && abs(curr.dx) > 5
            let significantY = abs(prev.dy) > 5 && abs(curr.dy) > 5

            if (significantX && prev.dx.sign != curr.dx.sign) ||
                (significantY && prev.dy.sign != curr.dy.sign)
            {
                directionChanges += 1
            }
        }

        var totalDistance: CGFloat = 0
        for i in 1 ..< dragPoints.count {
            let prev = dragPoints[i - 1]
            let curr = dragPoints[i]
            let dx = curr.x - prev.x
            let dy = curr.y - prev.y
            totalDistance += sqrt(dx * dx + dy * dy)
        }

        let isShake = directionChanges >= 4 && totalDistance > 100

        if isShake {
            dragPoints.removeAll()
        }

        return isShake
    }
}
