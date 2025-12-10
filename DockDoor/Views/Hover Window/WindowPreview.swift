import Defaults
import SwiftUI
import UniformTypeIdentifiers

struct WindowPreview: View {
    let windowInfo: WindowInfo
    let onTap: (() -> Void)?
    let index: Int
    let dockPosition: DockPosition
    let maxWindowDimension: CGPoint
    let bestGuessMonitor: NSScreen
    let uniformCardRadius: Bool
    let handleWindowAction: (WindowAction) -> Void
    var currIndex: Int
    var windowSwitcherActive: Bool
    let dimensions: WindowPreviewHoverContainer.WindowDimensions
    let showAppIconOnly: Bool
    let mockPreviewActive: Bool
    let onHoverIndexChange: ((Int?, CGPoint?) -> Bool)?
    var isEligibleForLivePreview: Bool = true

    @Default(.windowTitlePosition) var windowTitlePosition
    @Default(.showWindowTitle) var showWindowTitle
    @Default(.windowTitleDisplayCondition) var windowTitleDisplayCondition
    @Default(.windowTitleVisibility) var windowTitleVisibility
    @Default(.trafficLightButtonsVisibility) var trafficLightButtonsVisibility
    @Default(.trafficLightButtonsPosition) var trafficLightButtonsPosition
    @Default(.windowSwitcherControlPosition) var windowSwitcherControlPosition
    @Default(.dockPreviewControlPosition) var dockPreviewControlPosition
    @Default(.selectionOpacity) var selectionOpacity
    @Default(.unselectedContentOpacity) var unselectedContentOpacity
    @Default(.hoverHighlightColor) var hoverHighlightColor
    @Default(.allowDynamicImageSizing) var allowDynamicImageSizing
    @Default(.useEmbeddedDockPreviewElements) var useEmbeddedDockPreviewElements
    @Default(.disableDockStyleTrafficLights) var disableDockStyleTrafficLights
    @Default(.disableDockStyleTitles) var disableDockStyleTitles
    @Default(.hidePreviewCardBackground) var hidePreviewCardBackground
    @Default(.showMinimizedHiddenLabels) var showMinimizedHiddenLabels

    @Default(.tapEquivalentInterval) var tapEquivalentInterval
    @Default(.previewHoverAction) var previewHoverAction
    @Default(.showActiveWindowBorder) var showActiveWindowBorder
    @Default(.activeAppIndicatorColor) var activeAppIndicatorColor
    @Default(.enableLivePreview) var enableLivePreview
    @Default(.enableLivePreviewForDock) var enableLivePreviewForDock
    @Default(.enableLivePreviewForWindowSwitcher) var enableLivePreviewForWindowSwitcher
    @Default(.dockLivePreviewQuality) var dockLivePreviewQuality
    @Default(.dockLivePreviewFrameRate) var dockLivePreviewFrameRate
    @Default(.windowSwitcherLivePreviewQuality) var windowSwitcherLivePreviewQuality
    @Default(.windowSwitcherLivePreviewFrameRate) var windowSwitcherLivePreviewFrameRate
    @Default(.showAnimations) var showAnimations

    @State private var isHoveringOverDockPeekPreview = false
    @State private var isHoveringOverWindowSwitcherPreview = false
    @State private var fullPreviewTimer: Timer?
    @State private var isDraggingOver = false
    @State private var dragTimer: Timer?
    @State private var highlightOpacity = 0.0

    private var isDiagonalPosition: Bool {
        switch dockPreviewControlPosition {
        case .diagonalTopLeftBottomRight, .diagonalTopRightBottomLeft,
             .diagonalBottomLeftTopRight, .diagonalBottomRightTopLeft:
            true
        default:
            false
        }
    }

    /// Checks if this window is the currently active (focused) window on the system
    private var isActiveWindow: Bool {
        guard showActiveWindowBorder else { return false }
        guard windowInfo.app.isActive else { return false }
        guard let focusedWindow = try? windowInfo.appAxElement.focusedWindow(),
              let focusedWindowID = try? focusedWindow.cgWindowId()
        else { return false }
        return windowInfo.id == focusedWindowID
    }

    private var isWindowSwitcherDiagonalPosition: Bool {
        switch windowSwitcherControlPosition {
        case .diagonalTopLeftBottomRight, .diagonalTopRightBottomLeft,
             .diagonalBottomLeftTopRight, .diagonalBottomRightTopLeft:
            true
        default:
            false
        }
    }

    @ViewBuilder
    private func windowContent(isMinimized: Bool, isHidden: Bool, isSelected: Bool) -> some View {
        let inactive = (isMinimized || isHidden) && showMinimizedHiddenLabels
        let livePreviewEnabledForContext = windowSwitcherActive ? enableLivePreviewForWindowSwitcher : enableLivePreviewForDock
        let useLivePreview = enableLivePreview && livePreviewEnabledForContext && isEligibleForLivePreview && !isMinimized && !isHidden
        let quality = windowSwitcherActive ? windowSwitcherLivePreviewQuality : dockLivePreviewQuality
        let frameRate = windowSwitcherActive ? windowSwitcherLivePreviewFrameRate : dockLivePreviewFrameRate

        Group {
            if useLivePreview {
                LivePreviewImage(windowID: windowInfo.id, fallbackImage: windowInfo.image, quality: quality, frameRate: frameRate)
                    .scaledToFit()
            } else if let cgImage = windowInfo.image {
                Image(decorative: cgImage, scale: 1.0)
                    .resizable()
                    .scaledToFit()
            }
        }
        .markHidden(isHidden: inactive || (windowSwitcherActive && !isSelected))
        .overlay {
            if inactive, showMinimizedHiddenLabels {
                Image(systemName: "eye.slash")
                    .font(.largeTitle)
                    .foregroundColor(.primary)
                    .shadow(radius: 2)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: inactive)
        .clipShape(uniformCardRadius ? AnyShape(RoundedRectangle(cornerRadius: 12, style: .continuous)) : AnyShape(Rectangle()))
        .dynamicWindowFrame(
            allowDynamicSizing: allowDynamicImageSizing,
            dimensions: dimensions,
            dockPosition: dockPosition,
            windowSwitcherActive: windowSwitcherActive
        )
        .opacity(isSelected ? 1.0 : unselectedContentOpacity)
    }

    @ViewBuilder
    private func embeddedControlsOverlay(_ selected: Bool) -> some View {
        if !windowSwitcherActive {
            embeddedDockPreviewControls(selected)
        }
    }

    @ViewBuilder
    private func embeddedDockPreviewControls(_ selected: Bool) -> some View {
        let shouldShowTitle = showWindowTitle && (
            windowTitleDisplayCondition == .all ||
                windowTitleDisplayCondition == .dockPreviewsOnly
        )

        let titleToShow: String? = if let windowTitle = windowInfo.windowName, !windowTitle.isEmpty {
            windowTitle
        } else {
            windowInfo.app.localizedName
        }

        let hasTitle = shouldShowTitle &&
            titleToShow != nil &&
            (windowTitleVisibility == .alwaysVisible || selected)

        let hasTrafficLights = windowInfo.closeButton != nil &&
            trafficLightButtonsVisibility != .never &&
            (showMinimizedHiddenLabels ? (!windowInfo.isMinimized && !windowInfo.isHidden) : true)

        let titleContent = Group {
            if hasTitle, let title = titleToShow {
                MarqueeText(text: title, startDelay: 1)
                    .font(.subheadline)
                    .padding(4)
                    .if(!disableDockStyleTitles) { view in
                        view.materialPill()
                    }
            }
        }

        let controlsContent = Group {
            if hasTrafficLights {
                TrafficLightButtons(
                    displayMode: trafficLightButtonsVisibility,
                    hoveringOverParentWindow: selected || isHoveringOverDockPeekPreview,
                    onWindowAction: handleWindowAction,
                    pillStyling: !disableDockStyleTrafficLights,
                    mockPreviewActive: mockPreviewActive
                )
            } else if windowInfo.isMinimized || windowInfo.isHidden, showMinimizedHiddenLabels {
                Text(windowInfo.isMinimized ? "Minimized" : "Hidden")
                    .font(.subheadline)
                    .italic()
                    .foregroundStyle(.secondary)
                    .padding(4)
                    .materialPill()
                    .frame(height: 34)
            }
        }

        if hasTitle || hasTrafficLights {
            switch dockPreviewControlPosition {
            case .topLeading, .topTrailing:
                VStack {
                    HStack(spacing: 4) {
                        if dockPreviewControlPosition == .topLeading {
                            titleContent
                            Spacer()
                            controlsContent
                        } else {
                            controlsContent
                            Spacer()
                            titleContent
                        }
                    }
                    .padding(8)
                    Spacer()
                }
            case .bottomLeading, .bottomTrailing:
                VStack {
                    Spacer()
                    HStack(spacing: 4) {
                        if dockPreviewControlPosition == .bottomLeading {
                            titleContent
                            Spacer()
                            controlsContent
                        } else {
                            controlsContent
                            Spacer()
                            titleContent
                        }
                    }
                    .padding(8)
                }
            case .diagonalTopLeftBottomRight:
                VStack {
                    HStack {
                        titleContent
                        Spacer()
                    }
                    .padding(.leading, 8)
                    .padding(.top, 8)
                    Spacer()
                    HStack {
                        Spacer()
                        controlsContent
                    }
                    .padding(.trailing, 8)
                    .padding(.bottom, 8)
                }
            case .diagonalTopRightBottomLeft:
                VStack {
                    HStack {
                        Spacer()
                        titleContent
                    }
                    .padding(.trailing, 8)
                    .padding(.top, 8)
                    Spacer()
                    HStack {
                        controlsContent
                        Spacer()
                    }
                    .padding(.leading, 8)
                    .padding(.bottom, 8)
                }
            case .diagonalBottomLeftTopRight:
                VStack {
                    HStack {
                        Spacer()
                        controlsContent
                    }
                    .padding(.trailing, 8)
                    .padding(.top, 8)
                    Spacer()
                    HStack {
                        titleContent
                        Spacer()
                    }
                    .padding(.leading, 8)
                    .padding(.bottom, 8)
                }
            case .diagonalBottomRightTopLeft:
                VStack {
                    HStack {
                        controlsContent
                        Spacer()
                    }
                    .padding(.leading, 8)
                    .padding(.top, 8)
                    Spacer()
                    HStack {
                        Spacer()
                        titleContent
                    }
                    .padding(.trailing, 8)
                    .padding(.bottom, 8)
                }
            }
        }
    }

    private func windowSwitcherContent(_ selected: Bool, showTitleContent: Bool = true, showControlsContent: Bool = true) -> some View {
        let shouldShowTitle = showWindowTitle && (
            windowTitleDisplayCondition == .all ||
                windowTitleDisplayCondition == .windowSwitcherOnly
        )

        let titleAndSubtitleContent = VStack(alignment: .leading, spacing: 0) {
            if !showAppIconOnly {
                Text(windowInfo.app.localizedName ?? "Unknown")
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }

            if let windowTitle = windowInfo.windowName,
               !windowTitle.isEmpty,
               windowTitle != windowInfo.app.localizedName,
               shouldShowTitle
            {
                MarqueeText(text: windowTitle, startDelay: 1)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }

        let appIconContent = Group {
            if let appIcon = windowInfo.app.icon {
                Image(nsImage: appIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 35, height: 35)
            }
        }

        let controlsContent = Group {
            if windowInfo.closeButton != nil && (showMinimizedHiddenLabels ? (!windowInfo.isMinimized && !windowInfo.isHidden) : true) {
                TrafficLightButtons(
                    displayMode: trafficLightButtonsVisibility,
                    hoveringOverParentWindow: selected || isHoveringOverWindowSwitcherPreview,
                    onWindowAction: handleWindowAction,
                    pillStyling: true, mockPreviewActive: mockPreviewActive
                )
            } else if windowInfo.isMinimized || windowInfo.isHidden, showMinimizedHiddenLabels {
                Text(windowInfo.isMinimized ? "Minimized" : "Hidden")
                    .font(.subheadline)
                    .italic()
                    .foregroundStyle(.secondary)
                    .padding(4)
                    .materialPill()
                    .frame(height: 34)
            }
        }

        @ViewBuilder
        func contentRow(isLeadingControls: Bool) -> some View {
            HStack(spacing: 4) {
                if isLeadingControls {
                    if showControlsContent {
                        controlsContent
                    }
                    Spacer()
                    if showTitleContent {
                        appIconContent
                        titleAndSubtitleContent
                    }
                } else {
                    if showTitleContent {
                        appIconContent
                        titleAndSubtitleContent
                    }
                    Spacer()
                    if showControlsContent {
                        controlsContent
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }

        return VStack(spacing: 0) {
            switch windowSwitcherControlPosition {
            case .topLeading:
                contentRow(isLeadingControls: false)
            case .topTrailing:
                contentRow(isLeadingControls: true)
            case .bottomLeading:
                contentRow(isLeadingControls: false)
            case .bottomTrailing:
                contentRow(isLeadingControls: true)
            case .diagonalTopLeftBottomRight, .diagonalBottomRightTopLeft:
                contentRow(isLeadingControls: false)
            case .diagonalTopRightBottomLeft, .diagonalBottomLeftTopRight:
                contentRow(isLeadingControls: true)
            }
        }
    }

    private func dockPreviewContent(_ selected: Bool, showTitleContent: Bool = true, showControlsContent: Bool = true) -> some View {
        let shouldShowTitle = showWindowTitle && (
            windowTitleDisplayCondition == .all ||
                windowTitleDisplayCondition == .dockPreviewsOnly
        )

        // Determine what title to show: window name first, then app name as fallback
        let titleToShow: String? = if let windowTitle = windowInfo.windowName, !windowTitle.isEmpty {
            windowTitle
        } else {
            windowInfo.app.localizedName
        }

        let hasTitle = shouldShowTitle &&
            titleToShow != nil &&
            (windowTitleVisibility == .alwaysVisible || selected)

        let hasTrafficLights = windowInfo.closeButton != nil &&
            trafficLightButtonsVisibility != .never &&
            (showMinimizedHiddenLabels ? (!windowInfo.isMinimized && !windowInfo.isHidden) : true)

        let titleContent = Group {
            if hasTitle, let title = titleToShow {
                MarqueeText(text: title, startDelay: 1)
                    .font(.subheadline)
                    .padding(4)
                    .if(!disableDockStyleTitles) { view in
                        view.materialPill()
                    }
            }
        }

        let controlsContent = Group {
            if hasTrafficLights {
                TrafficLightButtons(
                    displayMode: trafficLightButtonsVisibility,
                    hoveringOverParentWindow: selected || isHoveringOverDockPeekPreview,
                    onWindowAction: handleWindowAction,
                    pillStyling: !disableDockStyleTrafficLights,
                    mockPreviewActive: mockPreviewActive
                )
            } else if windowInfo.isMinimized || windowInfo.isHidden, showMinimizedHiddenLabels {
                Text(windowInfo.isMinimized ? "Minimized" : "Hidden")
                    .font(.subheadline)
                    .italic()
                    .foregroundStyle(.secondary)
                    .padding(4)
                    .materialPill()
                    .frame(height: 34)
            }
        }

        @ViewBuilder
        func contentRow(isLeadingControls: Bool) -> some View {
            HStack(spacing: 4) {
                if isLeadingControls {
                    if showControlsContent {
                        controlsContent
                    }
                    Spacer()
                    if showTitleContent {
                        titleContent
                    }
                } else {
                    if showTitleContent {
                        titleContent
                    }
                    Spacer()
                    if showControlsContent {
                        controlsContent
                    }
                }
            }
        }

        // Only show the toolbar if there's either a title or traffic lights to display
        if hasTitle || hasTrafficLights {
            return AnyView(
                VStack(spacing: 0) {
                    switch dockPreviewControlPosition {
                    case .topLeading:
                        contentRow(isLeadingControls: false)
                    case .topTrailing:
                        contentRow(isLeadingControls: true)
                    case .bottomLeading:
                        contentRow(isLeadingControls: false)
                    case .bottomTrailing:
                        contentRow(isLeadingControls: true)
                    case .diagonalTopLeftBottomRight, .diagonalBottomRightTopLeft:
                        contentRow(isLeadingControls: false)
                    case .diagonalTopRightBottomLeft, .diagonalBottomLeftTopRight:
                        contentRow(isLeadingControls: true)
                    }
                }
            )
        } else {
            return AnyView(EmptyView())
        }
    }

    @ViewBuilder
    private var previewCoreContent: some View {
        let isSelectedByKeyboardInDock = !windowSwitcherActive && (index == currIndex)
        let isSelectedByKeyboardInSwitcher = windowSwitcherActive && (index == currIndex)

        let finalIsSelected = isSelectedByKeyboardInSwitcher ||
            isSelectedByKeyboardInDock ||
            isHoveringOverDockPeekPreview

        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 0) {
                if !useEmbeddedDockPreviewElements ||
                    windowSwitcherActive
                {
                    Group {
                        if windowSwitcherActive, windowSwitcherControlPosition == .topLeading ||
                            windowSwitcherControlPosition == .topTrailing
                        {
                            windowSwitcherContent(finalIsSelected)
                        } else if windowSwitcherActive, windowSwitcherControlPosition == .diagonalTopLeftBottomRight {
                            windowSwitcherContent(finalIsSelected, showTitleContent: true, showControlsContent: false)
                        } else if windowSwitcherActive, windowSwitcherControlPosition == .diagonalTopRightBottomLeft {
                            windowSwitcherContent(finalIsSelected, showTitleContent: true, showControlsContent: false)
                        } else if windowSwitcherActive, windowSwitcherControlPosition == .diagonalBottomLeftTopRight {
                            windowSwitcherContent(finalIsSelected, showTitleContent: false, showControlsContent: true)
                        } else if windowSwitcherActive, windowSwitcherControlPosition == .diagonalBottomRightTopLeft {
                            windowSwitcherContent(finalIsSelected, showTitleContent: false, showControlsContent: true)
                        }

                        if !windowSwitcherActive, dockPreviewControlPosition == .topLeading ||
                            dockPreviewControlPosition == .topTrailing
                        {
                            dockPreviewContent(finalIsSelected)
                        } else if !windowSwitcherActive, dockPreviewControlPosition == .diagonalTopLeftBottomRight {
                            dockPreviewContent(finalIsSelected, showTitleContent: true, showControlsContent: false)
                        } else if !windowSwitcherActive, dockPreviewControlPosition == .diagonalTopRightBottomLeft {
                            dockPreviewContent(finalIsSelected, showTitleContent: true, showControlsContent: false)
                        } else if !windowSwitcherActive, dockPreviewControlPosition == .diagonalBottomLeftTopRight {
                            dockPreviewContent(finalIsSelected, showTitleContent: false, showControlsContent: true)
                        } else if !windowSwitcherActive, dockPreviewControlPosition == .diagonalBottomRightTopLeft {
                            dockPreviewContent(finalIsSelected, showTitleContent: false, showControlsContent: true)
                        }
                    }
                    .padding(.bottom, 4)
                }

                windowContent(
                    isMinimized: windowInfo.isMinimized,
                    isHidden: windowInfo.isHidden,
                    isSelected: finalIsSelected
                )

                if !useEmbeddedDockPreviewElements ||
                    windowSwitcherActive
                {
                    Group {
                        if windowSwitcherActive, windowSwitcherControlPosition == .bottomLeading ||
                            windowSwitcherControlPosition == .bottomTrailing
                        {
                            windowSwitcherContent(finalIsSelected)
                        } else if windowSwitcherActive, windowSwitcherControlPosition == .diagonalTopLeftBottomRight {
                            windowSwitcherContent(finalIsSelected, showTitleContent: false, showControlsContent: true)
                        } else if windowSwitcherActive, windowSwitcherControlPosition == .diagonalTopRightBottomLeft {
                            windowSwitcherContent(finalIsSelected, showTitleContent: false, showControlsContent: true)
                        } else if windowSwitcherActive, windowSwitcherControlPosition == .diagonalBottomLeftTopRight {
                            windowSwitcherContent(finalIsSelected, showTitleContent: true, showControlsContent: false)
                        } else if windowSwitcherActive, windowSwitcherControlPosition == .diagonalBottomRightTopLeft {
                            windowSwitcherContent(finalIsSelected, showTitleContent: true, showControlsContent: false)
                        }

                        if !windowSwitcherActive, dockPreviewControlPosition == .bottomLeading ||
                            dockPreviewControlPosition == .bottomTrailing
                        {
                            dockPreviewContent(finalIsSelected)
                        } else if !windowSwitcherActive, dockPreviewControlPosition == .diagonalTopLeftBottomRight {
                            dockPreviewContent(finalIsSelected, showTitleContent: false, showControlsContent: true)
                        } else if !windowSwitcherActive, dockPreviewControlPosition == .diagonalTopRightBottomLeft {
                            dockPreviewContent(finalIsSelected, showTitleContent: false, showControlsContent: true)
                        } else if !windowSwitcherActive, dockPreviewControlPosition == .diagonalBottomLeftTopRight {
                            dockPreviewContent(finalIsSelected, showTitleContent: true, showControlsContent: false)
                        } else if !windowSwitcherActive, dockPreviewControlPosition == .diagonalBottomRightTopLeft {
                            dockPreviewContent(finalIsSelected, showTitleContent: true, showControlsContent: false)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .background {
                let cornerRadius = uniformCardRadius ? 20.0 : 0.0

                if !hidePreviewCardBackground {
                    BlurView(variant: 18)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                        .borderedBackground(.primary.opacity(0.1), lineWidth: 1.75, shape: RoundedRectangle(cornerRadius: cornerRadius))
                        .padding(-6)
                        .overlay {
                            if finalIsSelected {
                                let highlightColor = hoverHighlightColor ?? Color(nsColor: .controlAccentColor)
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .fill(highlightColor.opacity(selectionOpacity))
                                    .padding(-6)
                            }
                        }
                        .overlay {
                            if isActiveWindow {
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .strokeBorder(activeAppIndicatorColor, lineWidth: 2.5)
                                    .padding(-6)
                            }
                        }
                }
            }
        }
        .overlay {
            if isDraggingOver {
                RoundedRectangle(cornerRadius: uniformCardRadius ? 20 : 0)
                    .fill(Color(nsColor: .controlAccentColor).opacity(0.3))
                    .padding(-6)
                    .opacity(highlightOpacity)
            }

            if !windowSwitcherActive, useEmbeddedDockPreviewElements {
                embeddedControlsOverlay(finalIsSelected)
            }
        }
        .onDrop(of: [UTType.item], isTargeted: $isDraggingOver) { providers in
            if !isDraggingOver { return false }
            handleWindowTap()
            return true
        }
        .onChange(of: isDraggingOver) { isOver in
            if isOver {
                startDragTimer()
            } else {
                cancelDragTimer()
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            if isDraggingOver { return }

            let setHoverState: (Bool) -> Void = { newState in
                if showAnimations {
                    withAnimation(.snappy(duration: 0.175)) {
                        if windowSwitcherActive { isHoveringOverWindowSwitcherPreview = newState }
                        else { isHoveringOverDockPeekPreview = newState }
                    }
                } else {
                    if windowSwitcherActive { isHoveringOverWindowSwitcherPreview = newState }
                    else { isHoveringOverDockPeekPreview = newState }
                }
            }

            let currentHoverState = windowSwitcherActive ? isHoveringOverWindowSwitcherPreview : isHoveringOverDockPeekPreview

            switch phase {
            case let .active(location):
                if windowSwitcherActive {
                    let shouldApply = onHoverIndexChange?(index, location) ?? true
                    if shouldApply, !currentHoverState { setHoverState(true) }
                } else if !currentHoverState {
                    setHoverState(true)
                    handleFullPreviewHover(isHovering: true, action: previewHoverAction)
                }
            case .ended:
                if windowSwitcherActive { _ = onHoverIndexChange?(nil, nil) }
                if currentHoverState {
                    setHoverState(false)
                    if !windowSwitcherActive { handleFullPreviewHover(isHovering: false, action: previewHoverAction) }
                }
            }
        }
    }

    var body: some View {
        previewCoreContent
            .windowPreviewInteractions(
                windowInfo: windowInfo,
                windowSwitcherActive: windowSwitcherActive,
                dockPosition: dockPosition,
                handleWindowAction: handleWindowAction,
                onTap: onTap
            )
            .fixedSize()
    }

    private func handleFullPreviewHover(isHovering: Bool, action: PreviewHoverAction) {
        if isHovering, !windowSwitcherActive {
            switch action {
            case .none: break

            case .tap:
                if tapEquivalentInterval == 0 { handleWindowTap() } else {
                    fullPreviewTimer = Timer.scheduledTimer(withTimeInterval: tapEquivalentInterval, repeats: false) { _ in
                        DispatchQueue.main.async { handleWindowTap() }
                    }
                }

            case .previewFullSize:
                let showFullPreview = {
                    DispatchQueue.main.async {
                        SharedPreviewWindowCoordinator.activeInstance?.showWindow(
                            appName: windowInfo.app.localizedName ?? "Unknown",
                            windows: [windowInfo],
                            mouseScreen: bestGuessMonitor,
                            dockItemElement: nil, overrideDelay: true,
                            centeredHoverWindowState: .fullWindowPreview
                        )
                    }
                }
                if tapEquivalentInterval == 0 { showFullPreview() } else {
                    fullPreviewTimer = Timer.scheduledTimer(withTimeInterval: tapEquivalentInterval, repeats: false) { _ in showFullPreview() }
                }
            }
        } else {
            fullPreviewTimer?.invalidate()
            fullPreviewTimer = nil
            SharedPreviewWindowCoordinator.activeInstance?.hideFullPreviewWindow()
        }
    }

    private func handleWindowTap() {
        if windowInfo.isMinimized {
            handleWindowAction(.minimize)
        } else if windowInfo.isHidden {
            handleWindowAction(.hide)
        } else {
            windowInfo.bringToFront()
            onTap?()
        }
    }

    private func startDragTimer() {
        dragTimer?.invalidate()
        highlightOpacity = 1.0
        dragTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.08)) { highlightOpacity = 0.0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.easeInOut(duration: 0.08)) { highlightOpacity = 1.0 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    withAnimation(.easeInOut(duration: 0.08)) { highlightOpacity = 0.0 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        withAnimation(.easeInOut(duration: 0.08)) { highlightOpacity = 1.0 }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                            cancelDragTimer()
                            handleWindowTap()
                        }
                    }
                }
            }
        }
    }

    private func cancelDragTimer() {
        dragTimer?.invalidate()
        dragTimer = nil
        isDraggingOver = false
        highlightOpacity = 0.0
    }
}
