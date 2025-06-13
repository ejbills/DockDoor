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
    let onWindowTap: (() -> Void)?
    let dockPosition: DockPosition
    let mouseLocation: CGPoint?
    let bestGuessMonitor: NSScreen
    var mockPreviewActive: Bool
    let updateAvailable: Bool
    let embeddedContentType: EmbeddedContentType

    @ObservedObject var previewStateCoordinator: PreviewStateCoordinator

    @Default(.uniformCardRadius) var uniformCardRadius
    @Default(.showAppName) var showAppTitleData
    @Default(.showAppIconOnly) var showAppIconOnly
    @Default(.appNameStyle) var appNameStyle
    @Default(.windowTitlePosition) var windowTitlePosition
    @Default(.aeroShakeAction) var aeroShakeAction
    @Default(.previewWrap) var previewWrap
    @Default(.switcherWrap) var switcherWrap
    @Default(.gradientColorPalette) var gradientColorPalette
    @Default(.showSpecialAppControls) var showSpecialAppControls
    @Default(.showAnimations) var showAnimations

    @State private var draggedWindowIndex: Int? = nil
    @State private var isDragging = false

    @State private var hasAppeared: Bool = false
    @State private var appIcon: NSImage? = nil
    @State private var hoveringAppIcon: Bool = false
    @State private var hoveringWindowTitle: Bool = false

    @State private var dragPoints: [CGPoint] = []
    @State private var lastShakeCheck: Date = .init()

    init(appName: String,
         onWindowTap: (() -> Void)?,
         dockPosition: DockPosition,
         mouseLocation: CGPoint?,
         bestGuessMonitor: NSScreen,
         windowSwitcherCoordinator: PreviewStateCoordinator,
         mockPreviewActive: Bool,
         updateAvailable: Bool,
         embeddedContentType: EmbeddedContentType = .none)
    {
        self.appName = appName
        self.onWindowTap = onWindowTap
        self.dockPosition = dockPosition
        self.mouseLocation = mouseLocation
        self.bestGuessMonitor = bestGuessMonitor
        previewStateCoordinator = windowSwitcherCoordinator
        self.mockPreviewActive = mockPreviewActive
        self.updateAvailable = updateAvailable
        self.embeddedContentType = embeddedContentType
    }

    var body: some View {
        let calculatedMaxDimension = previewStateCoordinator.overallMaxPreviewDimension
        let calculatedDimensionsMap = previewStateCoordinator.windowDimensionsMap

        let orientationIsHorizontal = dockPosition.isHorizontalFlow || previewStateCoordinator.windowSwitcherActive

        BaseHoverContainer(bestGuessMonitor: bestGuessMonitor, mockPreviewActive: mockPreviewActive) {
            ScrollViewReader { scrollProxy in
                buildFlowStack(
                    scrollProxy: scrollProxy,
                    orientationIsHorizontal,
                    currentMaxDimensionForPreviews: calculatedMaxDimension,
                    currentDimensionsMapForPreviews: calculatedDimensionsMap
                )
                .padding(.top, (!previewStateCoordinator.windowSwitcherActive && appNameStyle == .default && showAppTitleData) ? 25 : 0)
                .overlay(alignment: .topLeading) {
                    hoverTitleBaseView(labelSize: measureString(appName, fontSize: 14))
                        .onHover { isHovered in
                            withAnimation(.snappy) { hoveringWindowTitle = isHovered }
                        }
                }
                .padding(.top, (!previewStateCoordinator.windowSwitcherActive && appNameStyle == .popover && showAppTitleData) ? 30 : 0)
                .overlay {
                    if !mockPreviewActive, !isDragging {
                        WindowDismissalContainer(appName: appName,
                                                 bestGuessMonitor: bestGuessMonitor,
                                                 dockPosition: dockPosition,
                                                 minimizeAllWindowsCallback: { minimizeAllWindows() })
                            .allowsHitTesting(false)
                    }
                }
            }
        }
        .onAppear {
            loadAppIcon()
        }
    }

    private func handleWindowDrop(at location: CGPoint, for index: Int) {
        guard index < previewStateCoordinator.windows.count else { return }
        let window = previewStateCoordinator.windows[index]

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
        if !previewStateCoordinator.windowSwitcherActive, showAppTitleData {
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
                        let shouldShowUpdateElements = updateAvailable && !mockPreviewActive
                        if shouldShowUpdateElements { Spacer() }
                        update(shouldShowUpdateElements)
                        massOperations(hoveringAppIcon && !updateAvailable)
                    }
                    .padding(.top, 10)
                    .padding(.horizontal)
                    .animation(.smooth(duration: 0.15), value: hoveringAppIcon)

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
                        let shouldShowUpdateElements = updateAvailable && !mockPreviewActive
                        if shouldShowUpdateElements { Spacer() }
                        update(shouldShowUpdateElements)
                        massOperations(hoveringAppIcon && !updateAvailable)
                    }
                    .padding(EdgeInsets(top: -11.5, leading: 15, bottom: -1.5, trailing: 1.5))
                    .animation(.smooth(duration: 0.15), value: hoveringAppIcon)

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
                            let shouldShowUpdateElements = updateAvailable && !mockPreviewActive
                            if shouldShowUpdateElements { Spacer() }
                            update(shouldShowUpdateElements)
                            massOperations(hoveringAppIcon && !updateAvailable)
                        }
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .dockStyle(cornerRadius: 10)
                        Spacer()
                    }
                    .offset(y: -30)
                    .animation(.smooth(duration: 0.15), value: hoveringAppIcon)
                }
            }
            .onHover { hover in
                hoveringAppIcon = hover
            }
        }
    }

    @ViewBuilder
    func update(_ shouldDisplay: Bool) -> some View {
        if shouldDisplay {
            Button {
                if let appDelegate = NSApp.delegate as? AppDelegate {
                    appDelegate.updater.checkForUpdates()
                }
            } label: {
                Label("Update available", systemImage: "arrow.down.circle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        CustomizableFluidGradientView()
                            .opacity(appNameStyle == .shadowed ? 1 : 0.25)
                    )
                    .clipShape(Capsule())
                    .shadow(radius: 2)
                    .overlay(
                        Capsule()
                            .stroke(.secondary.opacity(0.4), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
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
            let trimmedAppName = appName.trimmingCharacters(in: .whitespaces)

            let baseText = Text(trimmedAppName)

            let rainbowGradientColors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]
            let rainbowGradientHighlights: [Color] = [.white.opacity(0.45), .yellow.opacity(0.35), .pink.opacity(0.4)]
            let rainbowGradientSpeed: CGFloat = 0.65
            let defaultBlur: CGFloat = 0.5

            Group {
                switch appNameStyle {
                case .shadowed:
                    if trimmedAppName == "DockDoor" {
                        FluidGradient(
                            blobs: rainbowGradientColors,
                            highlights: rainbowGradientHighlights,
                            speed: rainbowGradientSpeed,
                            blur: defaultBlur
                        )
                        .frame(width: labelSize.width, height: labelSize.height)
                        .mask(baseText)
                        .fontWeight(.medium)
                        .padding(.leading, 4)
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
                    } else {
                        baseText
                            .foregroundStyle(Color.primary)
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
                    }
                case .default, .popover:
                    if trimmedAppName == "DockDoor" {
                        FluidGradient(
                            blobs: rainbowGradientColors,
                            highlights: rainbowGradientHighlights,
                            speed: rainbowGradientSpeed,
                            blur: defaultBlur
                        )
                        .frame(width: labelSize.width, height: labelSize.height)
                        .mask(baseText)
                    } else {
                        baseText
                            .foregroundStyle(Color.primary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func embeddedContentView() -> some View {
        if showSpecialAppControls {
            switch embeddedContentType {
            case let .media(bundleIdentifier):
                MediaControlsView(
                    appName: appName,
                    bundleIdentifier: bundleIdentifier,
                    dockPosition: dockPosition,
                    bestGuessMonitor: bestGuessMonitor,
                    isEmbeddedMode: true
                )
            case let .calendar(bundleIdentifier):
                CalendarView(
                    appName: appName,
                    bundleIdentifier: bundleIdentifier,
                    dockPosition: dockPosition,
                    bestGuessMonitor: bestGuessMonitor,
                    isEmbeddedMode: true
                )
            case .none:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private func buildFlowStack(
        scrollProxy: ScrollViewProxy,
        _ isHorizontal: Bool,
        currentMaxDimensionForPreviews: CGPoint,
        currentDimensionsMapForPreviews: [Int: WindowDimensions]
    ) -> some View {
        let wrap = previewStateCoordinator.windowSwitcherActive ? switcherWrap : previewWrap
        let layout = calculateOptimalLayout(
            windowDimensions: currentDimensionsMapForPreviews,
            isHorizontal: isHorizontal,
            wrap: wrap,
            maxDimensionForLayout: currentMaxDimensionForPreviews
        )

        ScrollView(isHorizontal ? .horizontal : .vertical, showsIndicators: false) {
            DynStack(direction: isHorizontal ? .vertical : .horizontal, spacing: 16) {
                ForEach(Array(layout.windowsPerStack.enumerated()), id: \.offset) { stackIndex, range in
                    DynStack(direction: isHorizontal ? .horizontal : .vertical, spacing: 16) {
                        if stackIndex == 0, embeddedContentType != .none {
                            embeddedContentView()
                                .id("\(appName)-embedded")
                        }

                        ForEach(previewStateCoordinator.windows.indices, id: \.self) { index in
                            if range.contains(index) {
                                WindowPreview(
                                    windowInfo: previewStateCoordinator.windows[index],
                                    onTap: onWindowTap,
                                    index: index,
                                    dockPosition: dockPosition,
                                    maxWindowDimension: currentMaxDimensionForPreviews,
                                    bestGuessMonitor: bestGuessMonitor,
                                    uniformCardRadius: uniformCardRadius,
                                    handleWindowAction: { action in
                                        handleWindowAction(action, at: index)
                                    },
                                    currIndex: previewStateCoordinator.currIndex,
                                    windowSwitcherActive: previewStateCoordinator.windowSwitcherActive,
                                    dimensions: getDimensions(for: index, dimensionsMap: currentDimensionsMapForPreviews),
                                    showAppIconOnly: showAppIconOnly,
                                    mockPreviewActive: mockPreviewActive
                                )
                                .id("\(appName)-\(index)")
                                .gesture(
                                    DragGesture(minimumDistance: 3, coordinateSpace: .global)
                                        .onChanged { value in
                                            if draggedWindowIndex == nil {
                                                draggedWindowIndex = index
                                                isDragging = true
                                                DragPreviewCoordinator.shared.startDragging(
                                                    windowInfo: previewStateCoordinator.windows[index],
                                                    at: NSEvent.mouseLocation
                                                )
                                            }
                                            if draggedWindowIndex == index {
                                                let currentPoint = value.location
                                                if !previewStateCoordinator.windowSwitcherActive, aeroShakeAction != .none,
                                                   checkForShakeGesture(currentPoint: currentPoint)
                                                {
                                                    DragPreviewCoordinator.shared.endDragging()
                                                    draggedWindowIndex = nil
                                                    isDragging = false

                                                    switch aeroShakeAction {
                                                    case .all:
                                                        minimizeAllWindows()
                                                    case .except:
                                                        minimizeAllWindows(previewStateCoordinator.windows[index])
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
        .animation(.smooth(duration: 0.1), value: previewStateCoordinator.windows)
        .onChange(of: previewStateCoordinator.currIndex) { newIndex in
            if showAnimations {
                withAnimation(.snappy) {
                    scrollProxy.scrollTo("\(appName)-\(newIndex)", anchor: .center)
                }
            } else {
                scrollProxy.scrollTo("\(appName)-\(newIndex)", anchor: .center)
            }
        }
    }

    private func loadAppIcon() {
        if let app = previewStateCoordinator.windows.first?.app, let icon = app.icon {
            DispatchQueue.main.async {
                if appIcon != icon {
                    appIcon = icon
                }
            }
        } else if appIcon != nil {
            DispatchQueue.main.async {
                appIcon = nil
            }
        }
    }

    private func closeAllWindows() {
        onWindowTap?()
        let windowsToClose = previewStateCoordinator.windows
        previewStateCoordinator.removeAllWindows()

        DispatchQueue.concurrentPerform(iterations: windowsToClose.count) { index in
            let window = windowsToClose[index]
            WindowUtil.closeWindow(windowInfo: window)
        }
    }

    private func minimizeAllWindows(_ except: WindowInfo? = nil) {
        onWindowTap?()
        let originalWindows = previewStateCoordinator.windows
        var modifiedWindows = originalWindows
        var didMinimizeAny = false

        if let except { WindowUtil.bringWindowToFront(windowInfo: except) }

        for i in 0 ..< modifiedWindows.count {
            if modifiedWindows[i] == except { continue }
            if !modifiedWindows[i].isMinimized {
                if WindowUtil.toggleMinimize(windowInfo: modifiedWindows[i]) == true {
                    modifiedWindows[i].isMinimized = true
                    didMinimizeAny = true
                }
            }
        }
        if didMinimizeAny || except == nil { // If we are minimizing all, or some were minimized
            if except == nil {
                previewStateCoordinator.setWindows([], dockPosition: dockPosition, bestGuessMonitor: bestGuessMonitor, isMockPreviewActive: mockPreviewActive)
            } else {
                var windowsToKeep: [WindowInfo] = []
                for var window in originalWindows {
                    if window == except {
                        windowsToKeep.append(window)
                        continue
                    }
                    if WindowUtil.toggleMinimize(windowInfo: window) == true {
                        window.isMinimized = true
                    } else {
                        windowsToKeep.append(window)
                    }
                }
                previewStateCoordinator.setWindows(windowsToKeep, dockPosition: dockPosition, bestGuessMonitor: bestGuessMonitor, isMockPreviewActive: mockPreviewActive)
            }
        }
    }

    private func handleWindowAction(_ action: WindowAction, at index: Int) {
        guard index < previewStateCoordinator.windows.count else { return }
        var window = previewStateCoordinator.windows[index]

        switch action {
        case .quit:
            WindowUtil.quitApp(windowInfo: window, force: NSEvent.modifierFlags.contains(.option))
            onWindowTap?()

        case .close:
            WindowUtil.closeWindow(windowInfo: window)
            previewStateCoordinator.removeWindow(at: index)

        case .minimize:
            if let newMinimizedState = WindowUtil.toggleMinimize(windowInfo: window) {
                window.isMinimized = newMinimizedState
                previewStateCoordinator.updateWindow(at: index, with: window)
            }

        case .toggleFullScreen:
            WindowUtil.toggleFullScreen(windowInfo: window)
            onWindowTap?()

        case .hide:
            if let newHiddenState = WindowUtil.toggleHidden(windowInfo: window) {
                window.isHidden = newHiddenState
                previewStateCoordinator.updateWindow(at: index, with: window)
            }

        case .openNewWindow:
            WindowUtil.openNewWindow(app: window.app)
            onWindowTap?()
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
