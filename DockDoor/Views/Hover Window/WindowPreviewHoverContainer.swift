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
    let dockItemFrameOverride: CGRect?
    var mockPreviewActive: Bool
    let updateAvailable: Bool
    let embeddedContentType: EmbeddedContentType
    let hasScreenRecordingPermission: Bool

    @ObservedObject var previewStateCoordinator: PreviewStateCoordinator

    @Default(.uniformCardRadius) var uniformCardRadius

    // MARK: - Dock Preview Header Settings

    @Default(.showAppName) var showAppTitleData
    @Default(.showAppIconOnly) var showAppIconOnly
    @Default(.appNameStyle) var appNameStyle

    // MARK: - Cmd+Tab Header Settings

    @Default(.cmdTabShowAppName) var cmdTabShowAppName
    @Default(.cmdTabAppNameStyle) var cmdTabAppNameStyle
    @Default(.cmdTabShowAppIconOnly) var cmdTabShowAppIconOnly

    @Default(.windowTitlePosition) var windowTitlePosition
    @Default(.aeroShakeAction) var aeroShakeAction
    @Default(.previewMaxColumns) var previewMaxColumns
    @Default(.previewMaxRows) var previewMaxRows
    @Default(.switcherMaxRows) var switcherMaxRows
    @Default(.gradientColorPalette) var gradientColorPalette
    @Default(.showAnimations) var showAnimations
    @Default(.enableMouseHoverInSwitcher) var enableMouseHoverInSwitcher
    @Default(.mouseHoverAutoScrollSpeed) var mouseHoverAutoScrollSpeed
    @Default(.windowSwitcherLivePreviewScope) var windowSwitcherLivePreviewScope

    // Live preview settings for compact fallback computation
    @Default(.enableLivePreview) var enableLivePreview
    @Default(.enableLivePreviewForDock) var enableLivePreviewForDock
    @Default(.enableLivePreviewForWindowSwitcher) var enableLivePreviewForWindowSwitcher

    // Compact mode thresholds (0 = disabled, 1+ = enable when window count >= threshold)
    @Default(.windowSwitcherCompactThreshold) var windowSwitcherCompactThreshold
    @Default(.dockPreviewCompactThreshold) var dockPreviewCompactThreshold
    @Default(.cmdTabCompactThreshold) var cmdTabCompactThreshold

    // Force list view settings
    @Default(.disableImagePreview) var disableImagePreview
    @Default(.previewWidth) var previewWidth

    @State private var draggedWindowIndex: Int? = nil
    @State private var isDragging = false

    @State private var hasAppeared: Bool = false
    @State private var appIcon: NSImage? = nil
    @State private var hoveringAppIcon: Bool = false
    @State private var hoveringWindowTitle: Bool = false

    @State private var dragPoints: [CGPoint] = []
    @State private var lastShakeCheck: Date = .init()
    @State private var edgeScrollTimer: Timer?
    @State private var edgeScrollDirection: CGFloat = 0
    @State private var cachedScrollView: NSScrollView?

    init(appName: String,
         onWindowTap: (() -> Void)?,
         dockPosition: DockPosition,
         mouseLocation: CGPoint?,
         bestGuessMonitor: NSScreen,
         dockItemElement: AXUIElement?,
         dockItemFrameOverride: CGRect? = nil,
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
        self.dockItemFrameOverride = dockItemFrameOverride
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

    // MARK: - Context-based header settings

    private var effectiveShowAppName: Bool {
        if dockPosition == .cmdTab {
            cmdTabShowAppName
        } else {
            showAppTitleData
        }
    }

    private var effectiveAppNameStyle: AppNameStyle {
        if dockPosition == .cmdTab {
            cmdTabAppNameStyle
        } else {
            appNameStyle
        }
    }

    private var effectiveShowAppIconOnly: Bool {
        if dockPosition == .cmdTab {
            cmdTabShowAppIconOnly
        } else {
            showAppIconOnly
        }
    }

    private var effectiveShouldShowHeader: Bool {
        // Window switcher doesn't show the container header
        if previewStateCoordinator.windowSwitcherActive {
            return false
        }
        return effectiveShowAppName
    }

    private func handleHoverIndexChange(_ hoveredIndex: Int?, _ location: CGPoint?) {
        guard enableMouseHoverInSwitcher else { return }
        guard let hoveredIndex else { return }
        guard hoveredIndex != previewStateCoordinator.currIndex else { return }

        if !previewStateCoordinator.hasMovedSinceOpen {
            let screenLocation = NSEvent.mouseLocation

            if previewStateCoordinator.initialHoverLocation == nil {
                previewStateCoordinator.initialHoverLocation = screenLocation
                return
            }

            if let initial = previewStateCoordinator.initialHoverLocation {
                let distance = hypot(screenLocation.x - initial.x, screenLocation.y - initial.y)
                if distance > 1 {
                    previewStateCoordinator.hasMovedSinceOpen = true
                } else {
                    return
                }
            }
        }

        previewStateCoordinator.setIndex(to: hoveredIndex, shouldScroll: false)
    }

    var body: some View {
        BaseHoverContainer(bestGuessMonitor: bestGuessMonitor, mockPreviewActive: mockPreviewActive) {
            windowGridContent()
        }
        .padding(.top, (!previewStateCoordinator.windowSwitcherActive && effectiveAppNameStyle == .popover && effectiveShowAppName) ? 30 : 0)
        .onAppear {
            loadAppIcon()
            // Only use LiveCaptureManager when live preview AND keep-alive are both enabled
            if Defaults[.enableLivePreview], Defaults[.livePreviewStreamKeepAlive] != 0 {
                LiveCaptureManager.shared.panelOpened()
            }
        }
        .onDisappear {
            if Defaults[.enableLivePreview], Defaults[.livePreviewStreamKeepAlive] != 0 {
                Task { await LiveCaptureManager.shared.panelClosed() }
            }
        }
        .onChange(of: previewStateCoordinator.windowSwitcherActive) { isActive in
            if !isActive {
                previewStateCoordinator.searchQuery = ""
                stopEdgeScroll()
            }
        }
    }

    @ViewBuilder
    private func windowGridContent() -> some View {
        let calculatedMaxDimension = previewStateCoordinator.overallMaxPreviewDimension
        let calculatedDimensionsMap = previewStateCoordinator.windowDimensionsMap
        let layoutIsHorizontal = previewStateCoordinator.windowSwitcherActive || dockPosition.isHorizontalFlow
        let scrollAxisIsHorizontal: Bool = if previewStateCoordinator.windowSwitcherActive {
            Defaults[.windowSwitcherScrollDirection] == .horizontal
        } else {
            dockPosition.isHorizontalFlow
        }

        ScrollViewReader { scrollProxy in
            buildFlowStack(
                scrollProxy: scrollProxy,
                layoutIsHorizontal: layoutIsHorizontal,
                scrollAxisIsHorizontal: scrollAxisIsHorizontal,
                currentMaxDimensionForPreviews: calculatedMaxDimension,
                currentDimensionsMapForPreviews: calculatedDimensionsMap
            )
            .fadeOnEdges(axis: shouldUseCompactMode ? .vertical : (scrollAxisIsHorizontal ? .horizontal : .vertical), fadeLength: 20)
            .padding(.top, (!previewStateCoordinator.windowSwitcherActive && effectiveAppNameStyle == .default && effectiveShowAppName) ? 25 : 0)
            .overlay(alignment: effectiveAppNameStyle == .popover ? .top : .topLeading) {
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
                                             dockItemFrameOverride: dockItemFrameOverride,
                                             originalMouseLocation: mouseLocation,
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
                        .clipShape(RoundedRectangle(cornerRadius: CardRadius.container, style: .continuous))
                }
            }
            .overlay {
                if enableMouseHoverInSwitcher, previewStateCoordinator.windowSwitcherActive {
                    edgeScrollZones(isHorizontal: scrollAxisIsHorizontal)
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
        let showName = !effectiveShowAppIconOnly

        if !previewStateCoordinator.windowSwitcherActive, effectiveShouldShowHeader {
            Group {
                switch effectiveAppNameStyle {
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
                            if showName {
                                hoverTitleLabelView(labelSize: labelSize)
                            }
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
                    .globalPadding(.top, 12)
                    .globalPadding(.leading, 20)

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
                            if showName {
                                hoverTitleLabelView(labelSize: labelSize)
                            }
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
                            if showName {
                                hoverTitleLabelView(labelSize: labelSize)
                            }
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
                            .opacity(effectiveAppNameStyle == .shadowed ? 1 : 0.25)
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
        let trimmedAppName = appName.trimmingCharacters(in: .whitespaces)
        let baseText = Text(trimmedAppName)

        let rainbowGradientColors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]
        let rainbowGradientHighlights: [Color] = [.white.opacity(0.45), .yellow.opacity(0.35), .pink.opacity(0.4)]
        let rainbowGradientSpeed: CGFloat = 0.65
        let defaultBlur: CGFloat = 0.5

        Group {
            switch effectiveAppNameStyle {
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
        layoutIsHorizontal: Bool,
        scrollAxisIsHorizontal: Bool,
        currentMaxDimensionForPreviews: CGPoint,
        currentDimensionsMapForPreviews: [Int: WindowDimensions]
    ) -> some View {
        ScrollView(shouldUseCompactMode ? .vertical : (scrollAxisIsHorizontal ? .horizontal : .vertical), showsIndicators: false) {
            Group {
                // Show no results view when search is active and no results found
                if shouldShowNoResultsView() {
                    noResultsView()
                } else if shouldUseCompactMode {
                    // Compact mode: simple vertical list
                    LazyVStack(spacing: 4) {
                        ForEach(createFlowItems(), id: \.id) { item in
                            buildFlowItem(
                                item: item,
                                isHorizontal: layoutIsHorizontal,
                                currentMaxDimensionForPreviews: currentMaxDimensionForPreviews,
                                currentDimensionsMapForPreviews: currentDimensionsMapForPreviews
                            )
                        }
                    }
                } else if layoutIsHorizontal {
                    let chunkedItems = createChunkedItems()
                    LazyVStack(alignment: .leading, spacing: 24) {
                        ForEach(Array(chunkedItems.enumerated()), id: \.offset) { index, rowItems in
                            LazyHStack(spacing: 24) {
                                ForEach(rowItems, id: \.id) { item in
                                    buildFlowItem(
                                        item: item,
                                        isHorizontal: layoutIsHorizontal,
                                        currentMaxDimensionForPreviews: currentMaxDimensionForPreviews,
                                        currentDimensionsMapForPreviews: currentDimensionsMapForPreviews
                                    )
                                }
                            }
                        }
                    }
                } else {
                    let chunkedItems = createChunkedItems()
                    LazyHStack(alignment: .top, spacing: 24) {
                        ForEach(Array(chunkedItems.enumerated()), id: \.offset) { index, colItems in
                            LazyVStack(spacing: 24) {
                                ForEach(colItems, id: \.id) { item in
                                    buildFlowItem(
                                        item: item,
                                        isHorizontal: layoutIsHorizontal,
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
        .animation(showAnimations ? .smooth(duration: 0.1) : nil, value: previewStateCoordinator.windows)
        .onChange(of: previewStateCoordinator.currIndex) { newIndex in
            guard previewStateCoordinator.shouldScrollToIndex else { return }

            scrollProxy.scrollTo("\(appName)-\(newIndex)", anchor: .center)
        }
    }

    private func startEdgeScroll(direction: CGFloat, isHorizontal: Bool) {
        edgeScrollDirection = direction
        guard edgeScrollTimer == nil else { return }

        if cachedScrollView == nil || cachedScrollView?.window == nil {
            if let window = NSApp.windows.first(where: { $0.isVisible && $0.title.isEmpty }) {
                cachedScrollView = findScrollView(in: window.contentView)
            }
        }

        edgeScrollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            smoothScrollBy(direction: edgeScrollDirection, isHorizontal: isHorizontal)
        }
    }

    private func stopEdgeScroll() {
        edgeScrollTimer?.invalidate()
        edgeScrollTimer = nil
        edgeScrollDirection = 0
        cachedScrollView = nil
    }

    private func smoothScrollBy(direction: CGFloat, isHorizontal: Bool) {
        guard let scrollView = cachedScrollView,
              let documentView = scrollView.documentView
        else { return }

        let scrollAmount: CGFloat = mouseHoverAutoScrollSpeed * direction
        let clipView = scrollView.contentView
        var newOrigin = clipView.bounds.origin

        if isHorizontal {
            newOrigin.x += scrollAmount
            newOrigin.x = max(0, min(newOrigin.x, documentView.frame.width - clipView.bounds.width))
        } else {
            newOrigin.y += scrollAmount
            newOrigin.y = max(0, min(newOrigin.y, documentView.frame.height - clipView.bounds.height))
        }

        clipView.setBoundsOrigin(newOrigin)
    }

    private func findScrollView(in view: NSView?) -> NSScrollView? {
        guard let view else { return nil }
        if let scrollView = view as? NSScrollView {
            return scrollView
        }
        for subview in view.subviews {
            if let found = findScrollView(in: subview) {
                return found
            }
        }
        return nil
    }

    @ViewBuilder
    private func edgeScrollZones(isHorizontal: Bool) -> some View {
        let edgeSize: CGFloat = 50

        if isHorizontal {
            HStack {
                // Leading edge
                Color.clear
                    .frame(width: edgeSize)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        if hovering { startEdgeScroll(direction: -1, isHorizontal: true) }
                        else { stopEdgeScroll() }
                    }
                Spacer()
                // Trailing edge
                Color.clear
                    .frame(width: edgeSize)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        if hovering { startEdgeScroll(direction: 1, isHorizontal: true) }
                        else { stopEdgeScroll() }
                    }
            }
        } else {
            VStack {
                // Top edge
                Color.clear
                    .frame(height: edgeSize)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        if hovering { startEdgeScroll(direction: -1, isHorizontal: false) }
                        else { stopEdgeScroll() }
                    }
                Spacer()
                // Bottom edge
                Color.clear
                    .frame(height: edgeSize)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        if hovering { startEdgeScroll(direction: 1, isHorizontal: false) }
                        else { stopEdgeScroll() }
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
            guard let keptWindow = originalWindows.first(where: { $0.id == except.id }) else {
                except.bringToFront()
                return
            }

            let windowsToMinimize = originalWindows.filter { $0.id != except.id }
            WindowUtil.minimizeWindowsAsync(windowsToMinimize)

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
                    WindowUtil.minimizeWindowsAsync(originalWindows)
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
            WindowUtil.minimizeWindowsAsync(originalWindows)
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
        let isHorizontal = previewStateCoordinator.windowSwitcherActive || dockPosition.isHorizontalFlow

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
        isHorizontal: Bool,
        currentMaxDimensionForPreviews: CGPoint,
        currentDimensionsMapForPreviews: [Int: WindowDimensions]
    ) -> some View {
        switch item {
        case .embedded:
            let firstWindowIndex = filteredWindowIndices().first ?? 0
            let firstWindow = previewStateCoordinator.windows.first
            let firstWindowDimensions = currentDimensionsMapForPreviews[firstWindowIndex]

            if isHorizontal, let window = firstWindow, let dimensions = firstWindowDimensions {
                WindowPreview(
                    windowInfo: window,
                    onTap: nil,
                    index: firstWindowIndex,
                    dockPosition: dockPosition,
                    bestGuessMonitor: bestGuessMonitor,
                    uniformCardRadius: uniformCardRadius,
                    handleWindowAction: { _ in },
                    currIndex: -1,
                    windowSwitcherActive: previewStateCoordinator.windowSwitcherActive,
                    dimensions: dimensions,
                    showAppIconOnly: false,
                    mockPreviewActive: mockPreviewActive,
                    onHoverIndexChange: nil,
                    useLivePreview: false,
                    skeletonMode: true
                )
                .overlay { embeddedContentView() }
                .id("\(appName)-embedded")
            } else {
                embeddedContentView()
                    .id("\(appName)-embedded")
            }
        case let .window(index):
            let windows = previewStateCoordinator.windows
            if index < windows.count {
                let windowInfo = windows[index]

                // Compute live preview eligibility once
                let useLivePreview: Bool = {
                    // Check global and context-specific settings
                    let windowSwitcherActive = previewStateCoordinator.windowSwitcherActive
                    let livePreviewEnabledForContext = windowSwitcherActive ? enableLivePreviewForWindowSwitcher : enableLivePreviewForDock
                    guard enableLivePreview, livePreviewEnabledForContext else { return false }

                    // Can't use live preview for minimized/hidden windows
                    guard !windowInfo.isMinimized, !windowInfo.isHidden else { return false }

                    // Check scope-based eligibility for window switcher
                    if windowSwitcherActive {
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
                    }

                    return true
                }()

                // Use compact mode if: container threshold triggered OR per-window fallback (no image and no live preview)
                let useCompactForThisWindow = shouldUseCompactMode || (windowInfo.image == nil && !useLivePreview)

                if useCompactForThisWindow {
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
                        bestGuessMonitor: bestGuessMonitor,
                        uniformCardRadius: uniformCardRadius,
                        handleWindowAction: { action in
                            handleWindowAction(action, at: index)
                        },
                        currIndex: previewStateCoordinator.currIndex,
                        windowSwitcherActive: previewStateCoordinator.windowSwitcherActive,
                        dimensions: getDimensions(for: index, dimensionsMap: currentDimensionsMapForPreviews),
                        showAppIconOnly: effectiveShowAppIconOnly,
                        mockPreviewActive: mockPreviewActive,
                        onHoverIndexChange: handleHoverIndexChange,
                        useLivePreview: useLivePreview
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
        .frame(minWidth: previewWidth, maxWidth: previewWidth, minHeight: 120)
    }
}
