import AppKit
import Defaults
import ScreenCaptureKit
import SwiftUI

enum FlowItem: Hashable, Identifiable {
    case embedded
    case window(Int)

    var id: String {
        switch self {
        case .embedded:
            "embedded"
        case let .window(index):
            "window-\(index)"
        }
    }
}

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
    let dockItemElement: AXUIElement?
    var mockPreviewActive: Bool
    let updateAvailable: Bool
    let embeddedContentType: EmbeddedContentType
    let hasScreenRecordingPermission: Bool

    @ObservedObject var previewStateCoordinator: PreviewStateCoordinator

    @Default(.uniformCardRadius) var uniformCardRadius
    @Default(.showAppName) var showAppTitleData
    @Default(.showAppIconOnly) var showAppIconOnly
    @Default(.appNameStyle) var appNameStyle
    @Default(.windowTitlePosition) var windowTitlePosition
    @Default(.aeroShakeAction) var aeroShakeAction
    @Default(.previewMaxColumns) var previewMaxColumns
    @Default(.previewMaxRows) var previewMaxRows
    @Default(.switcherMaxRows) var switcherMaxRows
    @Default(.gradientColorPalette) var gradientColorPalette
    @Default(.showAnimations) var showAnimations
    @Default(.enableMouseHoverInSwitcher) var enableMouseHoverInSwitcher
    @Default(.windowSwitcherLivePreviewScope) var windowSwitcherLivePreviewScope

    // Compact mode thresholds (0 = disabled, 1+ = enable when window count >= threshold)
    @Default(.windowSwitcherCompactThreshold) var windowSwitcherCompactThreshold
    @Default(.dockPreviewCompactThreshold) var dockPreviewCompactThreshold
    @Default(.cmdTabCompactThreshold) var cmdTabCompactThreshold

    // Force list view settings
    @Default(.disableImagePreview) var disableImagePreview

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
         dockItemElement: AXUIElement?,
         windowSwitcherCoordinator: PreviewStateCoordinator,
         mockPreviewActive: Bool,
         updateAvailable: Bool,
         embeddedContentType: EmbeddedContentType = .none,
         hasScreenRecordingPermission: Bool)
    {
        self.appName = appName
        self.onWindowTap = onWindowTap
        self.dockPosition = dockPosition
        self.mouseLocation = mouseLocation
        self.bestGuessMonitor = bestGuessMonitor
        self.dockItemElement = dockItemElement
        previewStateCoordinator = windowSwitcherCoordinator
        self.mockPreviewActive = mockPreviewActive
        self.updateAvailable = updateAvailable
        self.embeddedContentType = embeddedContentType
        self.hasScreenRecordingPermission = hasScreenRecordingPermission
    }

    private var minimumEmbeddedWidth: CGFloat {
        let calculatedDimensionsMap = previewStateCoordinator.windowDimensionsMap

        guard !calculatedDimensionsMap.isEmpty else {
            // Fallback to skeleton width if no windows
            return MediaControlsLayout.embeddedArtworkSize + MediaControlsLayout.artworkTextSpacing + 165
        }

        var minWidth = 0.0

        for dimension in calculatedDimensionsMap {
            let width = dimension.value.size.width
            if minWidth == 0 || width < minWidth {
                minWidth = width
            }
        }

        return min(300, minWidth)
    }

    private var shouldUseCompactMode: Bool {
        if mockPreviewActive { return false }

        // Force list view if image preview is disabled or screen recording permission is not granted
        if disableImagePreview || !hasScreenRecordingPermission {
            return true
        }

        let windowCount = previewStateCoordinator.windows.count

        if previewStateCoordinator.windowSwitcherActive {
            return windowSwitcherCompactThreshold > 0 && windowCount >= windowSwitcherCompactThreshold
        } else if dockPosition == .cmdTab {
            return cmdTabCompactThreshold > 0 && windowCount >= cmdTabCompactThreshold
        } else {
            return dockPreviewCompactThreshold > 0 && windowCount >= dockPreviewCompactThreshold
        }
    }

    private func handleHoverIndexChange(_ hoveredIndex: Int?, _ location: CGPoint?) -> Bool {
        guard enableMouseHoverInSwitcher else { return false }
        guard !previewStateCoordinator.isKeyboardScrolling else { return false }

        if let location, !previewStateCoordinator.hasMovedSinceOpen {
            if previewStateCoordinator.initialHoverLocation == nil {
                previewStateCoordinator.initialHoverLocation = location
                return false
            }

            if let initial = previewStateCoordinator.initialHoverLocation {
                let distance = hypot(location.x - initial.x, location.y - initial.y)
                if distance > 1 {
                    previewStateCoordinator.hasMovedSinceOpen = true
                } else if previewStateCoordinator.lastInputWasKeyboard {
                    return false
                }
            }
        }

        guard previewStateCoordinator.hasMovedSinceOpen else { return false }

        if let hoveredIndex, hoveredIndex != previewStateCoordinator.currIndex {
            previewStateCoordinator.setIndex(to: hoveredIndex, shouldScroll: true, fromKeyboard: false)
        }
        return true
    }

    var body: some View {
        BaseHoverContainer(bestGuessMonitor: bestGuessMonitor, mockPreviewActive: mockPreviewActive) {
            windowGridContent()
        }
        .padding(.top, (!previewStateCoordinator.windowSwitcherActive && appNameStyle == .popover && showAppTitleData) ? 30 : 0)
        .onAppear {
            loadAppIcon()
        }
        .onChange(of: previewStateCoordinator.windowSwitcherActive) { isActive in
            if !isActive {
                // Clear search when switcher is dismissed
                previewStateCoordinator.searchQuery = ""
            }
        }
    }

    @ViewBuilder
    private func windowGridContent() -> some View {
        let calculatedMaxDimension = previewStateCoordinator.overallMaxPreviewDimension
        let calculatedDimensionsMap = previewStateCoordinator.windowDimensionsMap
        let orientationIsHorizontal = dockPosition.isHorizontalFlow || previewStateCoordinator.windowSwitcherActive

        ScrollViewReader { scrollProxy in
            buildFlowStack(
                scrollProxy: scrollProxy,
                orientationIsHorizontal,
                currentMaxDimensionForPreviews: calculatedMaxDimension,
                currentDimensionsMapForPreviews: calculatedDimensionsMap
            )
            .fadeOnEdges(axis: shouldUseCompactMode ? .vertical : (orientationIsHorizontal ? .horizontal : .vertical), fadeLength: 20)
            .padding(.top, (!previewStateCoordinator.windowSwitcherActive && appNameStyle == .default && showAppTitleData) ? 25 : 0)
            .overlay(alignment: appNameStyle == .popover ? .top : .topLeading) {
                hoverTitleBaseView(labelSize: measureString(appName, fontSize: 14))
                    .onHover { isHovered in
                        hoveringWindowTitle = isHovered
                    }
            }
            .overlay {
                if !mockPreviewActive, !isDragging, dockPosition != .cmdTab {
                    WindowDismissalContainer(appName: appName,
                                             bestGuessMonitor: bestGuessMonitor,
                                             dockPosition: dockPosition,
                                             dockItemElement: dockItemElement,
                                             minimizeAllWindowsCallback: { wasAppActiveBeforeClick in
                                                 minimizeAllWindows(wasAppActiveBeforeClick: wasAppActiveBeforeClick)
                                             })
                                             .allowsHitTesting(false)
                }
            }
            .overlay {
                if dockPosition == .cmdTab,
                   Defaults[.enableCmdTabEnhancements],
                   !Defaults[.hasSeenCmdTabFocusHint],
                   !previewStateCoordinator.windowSwitcherActive,
                   previewStateCoordinator.currIndex < 0
                {
                    CmdTabFocusFullOverlayView()
                        .transition(.opacity)
                        .allowsHitTesting(false)
                        .clipShape(RoundedRectangle(cornerRadius: Defaults[.uniformCardRadius] ? 26 : 8, style: .continuous))
                }
            }
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
            window.bringToFront()
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
                        HStack(spacing: 6) {
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
                        .contentShape(Rectangle())

                        let shouldShowUpdateElements = updateAvailable && !mockPreviewActive

                        Group {
                            update(shouldShowUpdateElements)
                            massOperations(hoveringAppIcon && !updateAvailable)
                        }
                        .padding(.leading, 4)
                    }
                    .contentShape(Rectangle())
                    .onHover { hover in
                        hoveringAppIcon = hover
                    }
                    .shadow(radius: 2)
                    .padding(.top, 10)
                    .padding(.horizontal)

                case .shadowed:
                    HStack(spacing: 2) {
                        HStack(spacing: 6) {
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
                        .contentShape(Rectangle())

                        let shouldShowUpdateElements = updateAvailable && !mockPreviewActive

                        Group {
                            update(shouldShowUpdateElements)
                            massOperations(hoveringAppIcon && !updateAvailable)
                        }
                        .padding(.leading, 4)
                    }
                    .contentShape(Rectangle())
                    .onHover { hover in
                        hoveringAppIcon = hover
                    }
                    .padding(EdgeInsets(top: -11.5, leading: 15, bottom: -1.5, trailing: 1.5))

                case .popover:
                    HStack(alignment: .center, spacing: 2) {
                        HStack(spacing: 6) {
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

                        let shouldShowUpdateElements = updateAvailable && !mockPreviewActive

                        Group {
                            update(shouldShowUpdateElements)
                            massOperations(hoveringAppIcon && !updateAvailable)
                        }
                        .padding(.leading, 4)
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .dockStyle(cornerRadius: 10, frostedTranslucentLayer: true)
                    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .onHover { hover in
                        hoveringAppIcon = hover
                    }
                    .offset(y: -30)
                }
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
                    .font(.caption2.weight(.medium))
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
                Button {
                    closeAllWindows()
                } label: {
                    MarqueeText(text: "Close All", startDelay: 1)
                        .font(.caption)
                        .lineLimit(1)
                }
                .buttonStyle(AccentButtonStyle(small: true))

                Button {
                    minimizeAllWindows()
                } label: {
                    MarqueeText(text: "Minimize All", startDelay: 1)
                        .font(.caption)
                        .lineLimit(1)
                }
                .buttonStyle(AccentButtonStyle(small: true))
            }
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
            .lineLimit(1)
        }
    }

    @ViewBuilder
    private func embeddedContentView() -> some View {
        switch embeddedContentType {
        case let .media(bundleIdentifier):
            MediaControlsView(
                appName: appName,
                bundleIdentifier: bundleIdentifier,
                dockPosition: dockPosition,
                bestGuessMonitor: bestGuessMonitor,
                dockItemElement: dockItemElement,
                isEmbeddedMode: true,
                idealWidth: minimumEmbeddedWidth
            )
            .pinnable(appName: appName, bundleIdentifier: bundleIdentifier, type: .media)
        case let .calendar(bundleIdentifier):
            CalendarView(
                appName: appName,
                bundleIdentifier: bundleIdentifier,
                dockPosition: dockPosition,
                bestGuessMonitor: bestGuessMonitor,
                dockItemElement: dockItemElement,
                isEmbeddedMode: true,
                idealWidth: minimumEmbeddedWidth
            )
            .pinnable(appName: appName, bundleIdentifier: bundleIdentifier, type: .calendar)
        case .none:
            EmptyView()
        }
    }

    @ViewBuilder
    private func buildFlowStack(
        scrollProxy: ScrollViewProxy,
        _ isHorizontal: Bool,
        currentMaxDimensionForPreviews: CGPoint,
        currentDimensionsMapForPreviews: [Int: WindowDimensions]
    ) -> some View {
        ScrollView(shouldUseCompactMode ? .vertical : (isHorizontal ? .horizontal : .vertical), showsIndicators: false) {
            Group {
                // Show no results view when search is active and no results found
                if shouldShowNoResultsView() {
                    noResultsView()
                } else if shouldUseCompactMode {
                    // Compact mode: simple vertical list
                    VStack(spacing: 4) {
                        ForEach(createFlowItems(), id: \.id) { item in
                            buildFlowItem(
                                item: item,
                                currentMaxDimensionForPreviews: currentMaxDimensionForPreviews,
                                currentDimensionsMapForPreviews: currentDimensionsMapForPreviews
                            )
                        }
                    }
                } else if isHorizontal {
                    let chunkedItems = createChunkedItems()
                    VStack(alignment: .leading, spacing: 24) {
                        ForEach(Array(chunkedItems.enumerated()), id: \.offset) { index, rowItems in
                            HStack(spacing: 24) {
                                ForEach(rowItems, id: \.id) { item in
                                    buildFlowItem(
                                        item: item,
                                        currentMaxDimensionForPreviews: currentMaxDimensionForPreviews,
                                        currentDimensionsMapForPreviews: currentDimensionsMapForPreviews
                                    )
                                }
                            }
                        }
                    }
                } else {
                    let chunkedItems = createChunkedItems()
                    HStack(alignment: .top, spacing: 24) {
                        ForEach(Array(chunkedItems.enumerated()), id: \.offset) { index, colItems in
                            VStack(spacing: 24) {
                                ForEach(colItems, id: \.id) { item in
                                    buildFlowItem(
                                        item: item,
                                        currentMaxDimensionForPreviews: currentMaxDimensionForPreviews,
                                        currentDimensionsMapForPreviews: currentDimensionsMapForPreviews
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .frame(alignment: .topLeading)
            .globalPadding(20)
        }
        .padding(2)
        .animation(.smooth(duration: 0.1), value: previewStateCoordinator.windows)
        .onChange(of: previewStateCoordinator.currIndex) { newIndex in
            guard previewStateCoordinator.shouldScrollToIndex else { return }

            if previewStateCoordinator.lastInputWasKeyboard {
                previewStateCoordinator.isKeyboardScrolling = true
            }

            if showAnimations {
                withAnimation(.snappy) {
                    scrollProxy.scrollTo("\(appName)-\(newIndex)", anchor: .center)
                }
            } else {
                scrollProxy.scrollTo("\(appName)-\(newIndex)", anchor: .center)
            }

            if previewStateCoordinator.lastInputWasKeyboard {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    previewStateCoordinator.isKeyboardScrolling = false
                }
            }
        }
    }

    private func loadAppIcon() {
        guard let app = previewStateCoordinator.windows.first?.app, let bundleID = app.bundleIdentifier else { return }
        if let icon = SharedHoverUtils.loadAppIcon(for: bundleID) {
            DispatchQueue.main.async {
                if appIcon != icon { appIcon = icon }
            }
        } else if appIcon != nil {
            DispatchQueue.main.async { appIcon = nil }
        }
    }

    private func closeAllWindows() {
        onWindowTap?()
        let windowsToClose = previewStateCoordinator.windows
        previewStateCoordinator.removeAllWindows()

        DispatchQueue.concurrentPerform(iterations: windowsToClose.count) { index in
            windowsToClose[index].close()
        }
    }

    private func minimizeAllWindows(_ except: WindowInfo? = nil, wasAppActiveBeforeClick: Bool? = nil) {
        onWindowTap?()
        let originalWindows = previewStateCoordinator.windows

        guard !originalWindows.isEmpty else { return }

        if let except {
            var updatedWindows = originalWindows
            guard let exceptIndex = updatedWindows.firstIndex(where: { $0.id == except.id }) else {
                except.bringToFront()
                return
            }

            for idx in updatedWindows.indices where idx != exceptIndex {
                if !updatedWindows[idx].isMinimized {
                    _ = updatedWindows[idx].toggleMinimize()
                }
            }

            let keptWindow = updatedWindows[exceptIndex]
            previewStateCoordinator.setWindows([keptWindow], dockPosition: dockPosition, bestGuessMonitor: bestGuessMonitor, isMockPreviewActive: mockPreviewActive)
            keptWindow.bringToFront()
            return
        }

        if let wasAppActiveBeforeClick {
            if wasAppActiveBeforeClick {
                switch Defaults[.dockClickAction] {
                case .hide:
                    if let app = originalWindows.first?.app {
                        app.hide()
                        previewStateCoordinator.setWindows([], dockPosition: dockPosition, bestGuessMonitor: bestGuessMonitor, isMockPreviewActive: mockPreviewActive)
                    }
                case .minimize:
                    for window in originalWindows where !window.isMinimized {
                        var mutableWindow = window
                        _ = mutableWindow.toggleMinimize()
                    }
                    previewStateCoordinator.setWindows([], dockPosition: dockPosition, bestGuessMonitor: bestGuessMonitor, isMockPreviewActive: mockPreviewActive)
                }
            } else {
                if let app = originalWindows.first?.app {
                    app.activate()
                    app.unhide()

                    var restoredWindows: [WindowInfo] = []
                    for window in originalWindows {
                        if window.isMinimized {
                            var updatedWindow = window
                            if updatedWindow.toggleMinimize() != nil {
                                restoredWindows.append(updatedWindow)
                                continue
                            }
                        }
                        restoredWindows.append(window)
                    }
                    previewStateCoordinator.setWindows(restoredWindows, dockPosition: dockPosition, bestGuessMonitor: bestGuessMonitor, isMockPreviewActive: mockPreviewActive)
                }
            }
        } else {
            for window in originalWindows where !window.isMinimized {
                var mutableWindow = window
                _ = mutableWindow.toggleMinimize()
            }
            previewStateCoordinator.setWindows([], dockPosition: dockPosition, bestGuessMonitor: bestGuessMonitor, isMockPreviewActive: mockPreviewActive)
        }
    }

    private func handleWindowAction(_ action: WindowAction, at index: Int) {
        guard index < previewStateCoordinator.windows.count else { return }
        let window = previewStateCoordinator.windows[index]

        let keepPreviewOnQuit = Defaults[.keepPreviewOnAppTerminate]
        let result = action.perform(on: window, keepPreviewOnQuit: keepPreviewOnQuit)

        switch result {
        case .dismissed:
            onWindowTap?()
        case let .windowUpdated(updatedWindow):
            previewStateCoordinator.updateWindow(at: index, with: updatedWindow)
        case .windowRemoved:
            previewStateCoordinator.removeWindow(at: index)
        case let .appWindowsRemoved(pid):
            for i in stride(from: previewStateCoordinator.windows.count - 1, through: 0, by: -1) {
                if previewStateCoordinator.windows[i].app.processIdentifier == pid {
                    previewStateCoordinator.removeWindow(at: i)
                }
            }
        case .noChange:
            break
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

    private func getDimensions(for index: Int, dimensionsMap: [Int: WindowDimensions]) -> WindowDimensions? {
        dimensionsMap[index]
    }

    private func filteredWindowIndices() -> [Int] {
        previewStateCoordinator.filteredWindowIndices()
    }

    private func createFlowItems() -> [FlowItem] {
        var allItems: [FlowItem] = []

        if embeddedContentType != .none {
            allItems.append(.embedded)
        }

        for index in filteredWindowIndices() {
            allItems.append(.window(index))
        }

        return allItems
    }

    private func createChunkedItems() -> [[FlowItem]] {
        let isHorizontal = dockPosition.isHorizontalFlow || previewStateCoordinator.windowSwitcherActive

        var itemsToProcess: [FlowItem] = []

        if embeddedContentType != .none {
            itemsToProcess.append(.embedded)
        }

        for index in filteredWindowIndices() {
            itemsToProcess.append(.window(index))
        }

        var (maxColumns, maxRows) = WindowPreviewHoverContainer.calculateEffectiveMaxColumnsAndRows(
            bestGuessMonitor: bestGuessMonitor,
            overallMaxDimensions: previewStateCoordinator.overallMaxPreviewDimension,
            dockPosition: dockPosition,
            isWindowSwitcherActive: previewStateCoordinator.windowSwitcherActive,
            previewMaxColumns: previewMaxColumns,
            previewMaxRows: previewMaxRows,
            switcherMaxRows: switcherMaxRows,
            totalItems: itemsToProcess.count
        )

        guard maxColumns > 0, maxRows > 0 else {
            return itemsToProcess.isEmpty ? [[]] : [itemsToProcess]
        }

        if mockPreviewActive {
            maxRows = 1
            maxColumns = 1
        }

        let shouldReverse = (dockPosition == .bottom || dockPosition == .right) && !previewStateCoordinator.windowSwitcherActive

        let chunks = WindowPreviewHoverContainer.chunkArray(
            items: itemsToProcess,
            isHorizontal: isHorizontal,
            maxColumns: maxColumns,
            maxRows: maxRows,
            reverse: shouldReverse
        )

        return chunks.isEmpty ? [[]] : chunks
    }

    @ViewBuilder
    private func buildFlowItem(
        item: FlowItem,
        currentMaxDimensionForPreviews: CGPoint,
        currentDimensionsMapForPreviews: [Int: WindowDimensions]
    ) -> some View {
        switch item {
        case .embedded:
            embeddedContentView()
                .id("\(appName)-embedded")
        case let .window(index):
            let windows = previewStateCoordinator.windows
            if index < windows.count {
                let windowInfo = windows[index]

                let isEligibleForLivePreview: Bool = {
                    guard previewStateCoordinator.windowSwitcherActive else { return true }

                    switch windowSwitcherLivePreviewScope {
                    case .allWindows:
                        return true
                    case .selectedWindowOnly:
                        return index == previewStateCoordinator.currIndex
                    case .selectedAppWindows:
                        let currentIndex = previewStateCoordinator.currIndex
                        guard currentIndex >= 0, currentIndex < windows.count else { return false }
                        let selectedBundleID = windows[currentIndex].app.bundleIdentifier
                        return windowInfo.app.bundleIdentifier == selectedBundleID
                    }
                }()

                if shouldUseCompactMode {
                    WindowPreviewCompact(
                        windowInfo: windowInfo,
                        index: index,
                        dockPosition: dockPosition,
                        uniformCardRadius: uniformCardRadius,
                        handleWindowAction: { action in
                            handleWindowAction(action, at: index)
                        },
                        currIndex: previewStateCoordinator.currIndex,
                        windowSwitcherActive: previewStateCoordinator.windowSwitcherActive,
                        mockPreviewActive: mockPreviewActive,
                        onTap: onWindowTap,
                        onHoverIndexChange: handleHoverIndexChange
                    )
                    .id("\(appName)-\(index)")
                } else {
                    WindowPreview(
                        windowInfo: windowInfo,
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
                        mockPreviewActive: mockPreviewActive,
                        onHoverIndexChange: handleHoverIndexChange,
                        isEligibleForLivePreview: isEligibleForLivePreview
                    )
                    .id("\(appName)-\(index)")
                    .gesture(
                        DragGesture(minimumDistance: 3, coordinateSpace: .global)
                            .onChanged { value in
                                if draggedWindowIndex == nil {
                                    draggedWindowIndex = index
                                    isDragging = true
                                    DragPreviewCoordinator.shared.startDragging(
                                        windowInfo: windowInfo,
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
                                            minimizeAllWindows(windowInfo)
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
            } else {
                EmptyView()
            }
        }
    }

    private func shouldShowNoResultsView() -> Bool {
        let query = previewStateCoordinator.searchQuery
        return previewStateCoordinator.windowSwitcherActive &&
            !query.isEmpty &&
            filteredWindowIndices().isEmpty &&
            embeddedContentType == .none
    }

    @ViewBuilder
    private func noResultsView() -> some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.secondary)

            VStack(spacing: 4) {
                Text("No Results")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("No windows match your search")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(minWidth: 200, minHeight: 120)
        .padding()
    }
}
