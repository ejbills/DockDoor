import AppKit
import Defaults
import ScreenCaptureKit
import SwiftUI

enum FlowItem: Hashable, Identifiable {
    case widget(Int)
    case window(Int)

    var id: String {
        switch self {
        case let .widget(index):
            "widget-\(index)"
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
    var mockPreviewActive: Bool
    let updateAvailable: Bool
    // Optional declarative/native widgets to render in embedded mode
    let embeddedWidgets: [WidgetManifest]?

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
         embeddedWidgets: [WidgetManifest]? = nil)
    {
        self.appName = appName
        self.onWindowTap = onWindowTap
        self.dockPosition = dockPosition
        self.mouseLocation = mouseLocation
        self.bestGuessMonitor = bestGuessMonitor
        previewStateCoordinator = windowSwitcherCoordinator
        self.mockPreviewActive = mockPreviewActive
        self.updateAvailable = updateAvailable
        self.embeddedWidgets = embeddedWidgets
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
                .fadeOnEdges(axis: orientationIsHorizontal ? .horizontal : .vertical, fadeLength: 20)
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

    // Removed embeddedContentView; widgets are rendered as individual flow items.

    @ViewBuilder
    private func buildFlowStack(
        scrollProxy: ScrollViewProxy,
        _ isHorizontal: Bool,
        currentMaxDimensionForPreviews: CGPoint,
        currentDimensionsMapForPreviews: [Int: WindowDimensions]
    ) -> some View {
        ScrollView(isHorizontal ? .horizontal : .vertical, showsIndicators: false) {
            Group {
                // Show no results view when search is active and no results found
                if shouldShowNoResultsView() {
                    noResultsView()
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
            let window = windowsToClose[index]
            WindowUtil.closeWindow(windowInfo: window)
        }
    }

    private func minimizeAllWindows(_ except: WindowInfo? = nil, wasAppActiveBeforeClick: Bool? = nil) {
        onWindowTap?()
        let originalWindows = previewStateCoordinator.windows

        guard !originalWindows.isEmpty else { return }

        if let except {
            WindowUtil.bringWindowToFront(windowInfo: except)
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
                    for window in originalWindows {
                        if !window.isMinimized {
                            _ = WindowUtil.toggleMinimize(windowInfo: window)
                        }
                    }
                    previewStateCoordinator.setWindows([], dockPosition: dockPosition, bestGuessMonitor: bestGuessMonitor, isMockPreviewActive: mockPreviewActive)
                }
            } else {
                if let app = originalWindows.first?.app {
                    app.activate()
                    app.unhide()

                    var restoredWindows: [WindowInfo] = []
                    for var window in originalWindows {
                        if window.isMinimized {
                            if let newMinimizedState = WindowUtil.toggleMinimize(windowInfo: window) {
                                window.isMinimized = newMinimizedState
                            }
                        }
                        restoredWindows.append(window)
                    }
                    previewStateCoordinator.setWindows(restoredWindows, dockPosition: dockPosition, bestGuessMonitor: bestGuessMonitor, isMockPreviewActive: mockPreviewActive)
                }
            }
        } else {
            for window in originalWindows {
                if !window.isMinimized {
                    _ = WindowUtil.toggleMinimize(windowInfo: window)
                }
            }
            previewStateCoordinator.setWindows([], dockPosition: dockPosition, bestGuessMonitor: bestGuessMonitor, isMockPreviewActive: mockPreviewActive)
        }
    }

    private func handleWindowAction(_ action: WindowAction, at index: Int) {
        guard index < previewStateCoordinator.windows.count else { return }
        var window = previewStateCoordinator.windows[index]

        switch action {
        case .quit:
            WindowUtil.quitApp(windowInfo: window, force: NSEvent.modifierFlags.contains(.option))

            if Defaults[.keepPreviewOnAppTerminate] {
                let appPID = window.app.processIdentifier
                for i in stride(from: previewStateCoordinator.windows.count - 1, through: 0, by: -1) {
                    if previewStateCoordinator.windows[i].app.processIdentifier == appPID {
                        previewStateCoordinator.removeWindow(at: i)
                    }
                }
            } else {
                onWindowTap?()
            }

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

    private func getDimensions(for index: Int, dimensionsMap: [Int: WindowDimensions]) -> WindowDimensions? {
        dimensionsMap[index]
    }

    private func filteredWindowIndices() -> [Int] {
        // Only filter when switcher is active; view-only filtering
        let query = previewStateCoordinator.searchQuery.lowercased()
        guard previewStateCoordinator.windowSwitcherActive, !query.isEmpty else {
            return Array(previewStateCoordinator.windows.indices)
        }

        return previewStateCoordinator.windows.enumerated().compactMap { idx, win in
            let appName = win.app.localizedName?.lowercased() ?? ""
            let windowTitle = (win.windowName ?? "").lowercased()
            return (appName.contains(query) || windowTitle.contains(query)) ? idx : nil
        }
    }

    private func createFlowItems() -> [FlowItem] {
        var allItems: [FlowItem] = []

        // Add each embedded widget as its own flow item
        if let widgets = embeddedWidgets, !widgets.isEmpty {
            for i in widgets.indices {
                allItems.append(.widget(i))
            }
        }

        // Add windows from filtered indices (dimensions stay mapped by original indices)
        for index in filteredWindowIndices() {
            allItems.append(.window(index))
        }

        return allItems
    }

    private func createChunkedItems() -> [[FlowItem]] {
        let isHorizontal = dockPosition.isHorizontalFlow || previewStateCoordinator.windowSwitcherActive

        var (maxColumns, maxRows): (Int, Int)
        if previewStateCoordinator.windowSwitcherActive {
            maxColumns = 999
            maxRows = switcherMaxRows
        } else {
            if dockPosition == .bottom || dockPosition == .cmdTab {
                maxColumns = 999
                // Force a single row while Cmd+Tab is active to avoid multi-row flow
                maxRows = (dockPosition == .cmdTab) ? 1 : previewMaxRows
            } else {
                maxColumns = previewMaxColumns
                maxRows = 999
            }
        }

        guard maxColumns > 0, maxRows > 0 else {
            let allItems = createFlowItems()
            return allItems.isEmpty ? [[]] : [allItems]
        }

        if mockPreviewActive {
            maxRows = 1
            maxColumns = 1
        }

        var itemsToProcess: [FlowItem] = []

        if let widgets = embeddedWidgets, !widgets.isEmpty {
            for i in widgets.indices {
                itemsToProcess.append(.widget(i))
            }
        }

        for index in filteredWindowIndices() {
            itemsToProcess.append(.window(index))
        }

        let totalItems = itemsToProcess.count

        if isHorizontal {
            if maxRows == 1 {
                return itemsToProcess.isEmpty ? [[]] : [itemsToProcess]
            }

            let itemsPerRow = Int(ceil(Double(totalItems) / Double(maxRows)))
            var chunks: [[FlowItem]] = []
            var startIndex = 0

            for _ in 0 ..< maxRows {
                let endIndex = min(startIndex + itemsPerRow, totalItems)

                if startIndex < totalItems {
                    let rowItems = Array(itemsToProcess[startIndex ..< endIndex])
                    if !rowItems.isEmpty {
                        chunks.append(rowItems)
                    }
                    startIndex = endIndex
                }

                if startIndex >= totalItems {
                    break
                }
            }

            return chunks.isEmpty ? [[]] : chunks

        } else {
            if maxColumns == 1 {
                return itemsToProcess.isEmpty ? [itemsToProcess] : [itemsToProcess]
            }

            let itemsPerColumn = Int(ceil(Double(totalItems) / Double(maxColumns)))
            var chunks: [[FlowItem]] = []
            var startIndex = 0

            for _ in 0 ..< maxColumns {
                let endIndex = min(startIndex + itemsPerColumn, totalItems)

                if startIndex < totalItems {
                    let columnItems = Array(itemsToProcess[startIndex ..< endIndex])
                    if !columnItems.isEmpty {
                        chunks.append(columnItems)
                    }
                    startIndex = endIndex
                }

                if startIndex >= totalItems {
                    break
                }
            }

            return chunks.isEmpty ? [[]] : chunks
        }
    }

    @ViewBuilder
    private func buildFlowItem(
        item: FlowItem,
        currentMaxDimensionForPreviews: CGPoint,
        currentDimensionsMapForPreviews: [Int: WindowDimensions]
    ) -> some View {
        switch item {
        case let .widget(index):
            if let widgets = embeddedWidgets, index < widgets.count {
                let manifest = widgets[index]
                let ctx: [String: String] = [
                    "appName": appName,
                    "bundleIdentifier": previewStateCoordinator.windows.first?.app.bundleIdentifier ?? "",
                    "windows.count": String(previewStateCoordinator.windows.count),
                    "dockPosition": dockPosition.rawValue,
                ]

                if manifest.isNative() {
                    WidgetHostView(manifest: manifest, mode: .embedded, context: ctx, screen: bestGuessMonitor)
                        .id("\(appName)-widget-native-\(index)")
                        .frame(minWidth: minimumEmbeddedWidth, alignment: .center)
                } else {
                    WidgetHostView(manifest: manifest, mode: .embedded, context: ctx, screen: bestGuessMonitor)
                        .padding(12)
                        .simpleBlurBackground(strokeWidth: 1.75)
                        .id("\(appName)-widget-decl-\(index)")
                        .frame(minWidth: minimumEmbeddedWidth, alignment: .center)
                }
            } else {
                EmptyView()
            }
        case let .window(index):
            if index < previewStateCoordinator.windows.count {
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
            } else {
                // Index is out of bounds - don't render anything
                EmptyView()
            }
        }
    }

    private func shouldShowNoResultsView() -> Bool {
        let query = previewStateCoordinator.searchQuery
        return previewStateCoordinator.windowSwitcherActive &&
            !query.isEmpty &&
            filteredWindowIndices().isEmpty &&
            (embeddedWidgets?.isEmpty ?? true)
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
