import Defaults
import SwiftUI
import UniformTypeIdentifiers

struct PreviewAppearanceSettings {
    let trafficLightVisibility: TrafficLightButtonsVisibility
    let enabledTrafficLightButtons: Set<WindowAction>
    let useMonochromeTrafficLights: Bool
    let showWindowTitle: Bool
    let windowTitleVisibility: WindowTitleVisibility
    let controlPosition: WindowSwitcherControlPosition
    let useEmbeddedElements: Bool
    let disableDockStyleTrafficLights: Bool
    let disableDockStyleTitles: Bool
    let showMinimizedHiddenLabels: Bool
    let selectionOpacity: Double
    let unselectedContentOpacity: Double
    let hoverHighlightColor: Color?
    let allowDynamicImageSizing: Bool
    let hidePreviewCardBackground: Bool
    let tapEquivalentInterval: Double
    let previewHoverAction: PreviewHoverAction
    let showActiveWindowBorder: Bool
    let activeAppIndicatorColor: Color
    let showAnimations: Bool
    let globalPaddingMultiplier: CGFloat
    let windowTitleFontSize: WindowTitleFontSize
    let livePreviewQuality: LivePreviewQuality
    let livePreviewFrameRate: LivePreviewFrameRate

    var isDiagonalPosition: Bool {
        switch controlPosition {
        case .diagonalTopLeftBottomRight, .diagonalTopRightBottomLeft,
             .diagonalBottomLeftTopRight, .diagonalBottomRightTopLeft:
            true
        default:
            false
        }
    }

    static func resolve(windowSwitcherActive: Bool, dockPosition: DockPosition) -> PreviewAppearanceSettings {
        let isCmdTab = dockPosition == .cmdTab

        let trafficLightVisibility: TrafficLightButtonsVisibility = if windowSwitcherActive {
            Defaults[.switcherTrafficLightButtonsVisibility]
        } else if isCmdTab {
            Defaults[.cmdTabTrafficLightButtonsVisibility]
        } else {
            Defaults[.trafficLightButtonsVisibility]
        }

        let enabledButtons: Set<WindowAction> = if windowSwitcherActive {
            Defaults[.switcherEnabledTrafficLightButtons]
        } else if isCmdTab {
            Defaults[.cmdTabEnabledTrafficLightButtons]
        } else {
            Defaults[.enabledTrafficLightButtons]
        }

        let monochrome: Bool = if windowSwitcherActive {
            Defaults[.switcherUseMonochromeTrafficLights]
        } else if isCmdTab {
            Defaults[.cmdTabUseMonochromeTrafficLights]
        } else {
            Defaults[.useMonochromeTrafficLights]
        }

        let showTitle: Bool = if windowSwitcherActive {
            Defaults[.switcherShowWindowTitle]
        } else if isCmdTab {
            Defaults[.cmdTabShowWindowTitle]
        } else {
            Defaults[.showWindowTitle]
        }

        let titleVisibility: WindowTitleVisibility = if windowSwitcherActive {
            Defaults[.switcherWindowTitleVisibility]
        } else if isCmdTab {
            Defaults[.cmdTabWindowTitleVisibility]
        } else {
            Defaults[.windowTitleVisibility]
        }

        let controlPos: WindowSwitcherControlPosition = if windowSwitcherActive {
            Defaults[.windowSwitcherControlPosition]
        } else if isCmdTab {
            Defaults[.cmdTabControlPosition]
        } else {
            Defaults[.dockPreviewControlPosition]
        }

        let disableStyleTrafficLights: Bool = if windowSwitcherActive {
            Defaults[.switcherDisableDockStyleTrafficLights]
        } else if isCmdTab {
            Defaults[.cmdTabDisableDockStyleTrafficLights]
        } else {
            Defaults[.disableDockStyleTrafficLights]
        }

        let disableStyleTitles: Bool = if isCmdTab {
            Defaults[.cmdTabDisableDockStyleTitles]
        } else {
            Defaults[.disableDockStyleTitles]
        }

        let useEmbedded: Bool = if isCmdTab {
            Defaults[.cmdTabUseEmbeddedDockPreviewElements]
        } else {
            Defaults[.useEmbeddedDockPreviewElements]
        }

        let quality = windowSwitcherActive ? Defaults[.windowSwitcherLivePreviewQuality] : Defaults[.dockLivePreviewQuality]
        let frameRate = windowSwitcherActive ? Defaults[.windowSwitcherLivePreviewFrameRate] : Defaults[.dockLivePreviewFrameRate]

        return PreviewAppearanceSettings(
            trafficLightVisibility: trafficLightVisibility,
            enabledTrafficLightButtons: enabledButtons,
            useMonochromeTrafficLights: monochrome,
            showWindowTitle: showTitle,
            windowTitleVisibility: titleVisibility,
            controlPosition: controlPos,
            useEmbeddedElements: useEmbedded,
            disableDockStyleTrafficLights: disableStyleTrafficLights,
            disableDockStyleTitles: disableStyleTitles,
            showMinimizedHiddenLabels: Defaults[.showMinimizedHiddenLabels],
            selectionOpacity: Defaults[.selectionOpacity],
            unselectedContentOpacity: Defaults[.unselectedContentOpacity],
            hoverHighlightColor: Defaults[.hoverHighlightColor],
            allowDynamicImageSizing: Defaults[.allowDynamicImageSizing],
            hidePreviewCardBackground: Defaults[.hidePreviewCardBackground],
            tapEquivalentInterval: Defaults[.tapEquivalentInterval],
            previewHoverAction: Defaults[.previewHoverAction],
            showActiveWindowBorder: Defaults[.showActiveWindowBorder],
            activeAppIndicatorColor: Defaults[.activeAppIndicatorColor],
            showAnimations: Defaults[.showAnimations],
            globalPaddingMultiplier: Defaults[.globalPaddingMultiplier],
            windowTitleFontSize: Defaults[.windowTitleFontSize],
            livePreviewQuality: quality,
            livePreviewFrameRate: frameRate
        )
    }
}

struct WindowPreview: View {
    let windowInfo: WindowInfo
    let onTap: (() -> Void)?
    let index: Int
    let dockPosition: DockPosition
    let bestGuessMonitor: NSScreen
    let uniformCardRadius: Bool
    let handleWindowAction: (WindowAction) -> Void
    var currIndex: Int
    var windowSwitcherActive: Bool
    let dimensions: WindowPreviewHoverContainer.WindowDimensions
    let showAppIconOnly: Bool
    let mockPreviewActive: Bool
    let onHoverIndexChange: ((Int?, CGPoint?) -> Void)?
    let useLivePreview: Bool
    var skeletonMode: Bool = false
    var appearance: PreviewAppearanceSettings

    @State private var isHoveringOverDockPeekPreview = false
    @State private var isHoveringOverWindowSwitcherPreview = false
    @State private var fullPreviewTimer: Timer?
    @State private var fullPreviewHoverID: UUID?
    @State private var isDraggingOver = false
    @State private var dragTimer: Timer?
    @State private var highlightOpacity = 0.0

    private var isActiveWindow: Bool {
        guard appearance.showActiveWindowBorder else { return false }
        guard windowInfo.app.isActive else { return false }
        guard let focusedWindow = try? windowInfo.appAxElement.focusedWindow(),
              let focusedWindowID = try? focusedWindow.cgWindowId()
        else { return false }
        return windowInfo.id == focusedWindowID
    }

    @ViewBuilder
    private func windowContent(isMinimized: Bool, isHidden: Bool, isSelected: Bool) -> some View {
        let inactive = (isMinimized || isHidden) && appearance.showMinimizedHiddenLabels
        let quality = appearance.livePreviewQuality
        let frameRate = appearance.livePreviewFrameRate

        Group {
            if skeletonMode {
                Color.clear
            } else if useLivePreview {
                LivePreviewImage(windowID: windowInfo.id, fallbackImage: windowInfo.image, quality: quality, frameRate: frameRate)
            } else if let cgImage = windowInfo.image {
                Image(decorative: cgImage, scale: 1.0)
                    .resizable()
                    .scaledToFit()
            }
        }
        .markHidden(isHidden: inactive || (windowSwitcherActive && !isSelected))
        .overlay {
            if inactive, appearance.showMinimizedHiddenLabels {
                Image(systemName: "eye.slash")
                    .font(.largeTitle)
                    .foregroundColor(.primary)
                    .shadow(radius: 2)
                    .transition(.opacity)
            }
        }
        .animation(appearance.showAnimations ? .easeInOut(duration: 0.15) : nil, value: inactive)
        .clipShape(RoundedRectangle(cornerRadius: CardRadius.image, style: .continuous))
        .dynamicWindowFrame(
            allowDynamicSizing: appearance.allowDynamicImageSizing && !windowSwitcherActive,
            dimensions: dimensions,
            dockPosition: dockPosition,
            windowSwitcherActive: windowSwitcherActive
        )
        .opacity(isSelected ? 1.0 : appearance.unselectedContentOpacity)
    }

    @ViewBuilder
    private func embeddedControlsOverlay(_ selected: Bool) -> some View {
        if !windowSwitcherActive {
            embeddedDockPreviewControls(selected)
        }
    }

    @ViewBuilder
    private func embeddedDockPreviewControls(_ selected: Bool) -> some View {
        let titleToShow: String? = if let windowTitle = windowInfo.windowName, !windowTitle.isEmpty {
            windowTitle
        } else {
            windowInfo.app.localizedName
        }

        let hasTitle = appearance.showWindowTitle &&
            titleToShow != nil &&
            (appearance.windowTitleVisibility == .alwaysVisible || selected)

        let hasTrafficLights = windowInfo.closeButton != nil &&
            appearance.trafficLightVisibility != .never &&
            (appearance.showMinimizedHiddenLabels ? (!windowInfo.isMinimized && !windowInfo.isHidden) : true)

        let titleContent = Group {
            if hasTitle, let title = titleToShow {
                MarqueeText(text: title, startDelay: 1)
                    .font(appearance.windowTitleFontSize.font)
                    .padding(4)
                    .if(!appearance.disableDockStyleTitles) { view in
                        view.materialPill()
                    }
            }
        }

        let controlsContent = Group {
            if hasTrafficLights {
                TrafficLightButtons(
                    displayMode: appearance.trafficLightVisibility,
                    hoveringOverParentWindow: selected || isHoveringOverDockPeekPreview,
                    onWindowAction: handleWindowAction,
                    pillStyling: !appearance.disableDockStyleTrafficLights,
                    mockPreviewActive: mockPreviewActive,
                    enabledButtons: appearance.enabledTrafficLightButtons,
                    useMonochrome: appearance.useMonochromeTrafficLights
                )
            } else if windowInfo.isMinimized || windowInfo.isHidden,
                      appearance.showMinimizedHiddenLabels,
                      appearance.trafficLightVisibility != .never
            {
                Text(windowInfo.isMinimized ? "Minimized" : "Hidden")
                    .font(appearance.windowTitleFontSize.font)
                    .italic()
                    .foregroundStyle(.secondary)
                    .padding(4)
                    .materialPill()
                    .frame(height: 34)
            }
        }

        if hasTitle || hasTrafficLights {
            switch appearance.controlPosition {
            case .topLeading, .topTrailing:
                VStack {
                    HStack(spacing: 4) {
                        if appearance.controlPosition == .topLeading {
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
                        if appearance.controlPosition == .bottomLeading {
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
            case .parallelTopLeftBottomLeft:
                VStack {
                    HStack {
                        titleContent
                        Spacer()
                    }
                    .padding(.leading, 8)
                    .padding(.top, 8)
                    Spacer()
                    HStack {
                        controlsContent
                        Spacer()
                    }
                    .padding(.leading, 8)
                    .padding(.bottom, 8)
                }
            case .parallelTopRightBottomRight:
                VStack {
                    HStack {
                        Spacer()
                        titleContent
                    }
                    .padding(.trailing, 8)
                    .padding(.top, 8)
                    Spacer()
                    HStack {
                        Spacer()
                        controlsContent
                    }
                    .padding(.trailing, 8)
                    .padding(.bottom, 8)
                }
            case .parallelBottomLeftTopLeft:
                VStack {
                    HStack {
                        controlsContent
                        Spacer()
                    }
                    .padding(.leading, 8)
                    .padding(.top, 8)
                    Spacer()
                    HStack {
                        titleContent
                        Spacer()
                    }
                    .padding(.leading, 8)
                    .padding(.bottom, 8)
                }
            case .parallelBottomRightTopRight:
                VStack {
                    HStack {
                        Spacer()
                        controlsContent
                    }
                    .padding(.trailing, 8)
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

    private func windowSwitcherContent(_ selected: Bool, isLeadingControls: Bool, showTitleContent: Bool = true, showControlsContent: Bool = true) -> some View {
        let shouldShowWindowTitle = appearance.showWindowTitle &&
            (appearance.windowTitleVisibility == .alwaysVisible || selected || isHoveringOverWindowSwitcherPreview)

        let titleAndSubtitleContent = VStack(alignment: .leading, spacing: 0) {
            if !showAppIconOnly {
                Text(windowInfo.app.localizedName ?? "Unknown")
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }

            if let windowTitle = windowInfo.windowName,
               !windowTitle.isEmpty,
               windowTitle != windowInfo.app.localizedName,
               shouldShowWindowTitle
            {
                MarqueeText(text: windowTitle, startDelay: 1)
                    .font(appearance.windowTitleFontSize.font)
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
            if windowInfo.closeButton != nil && (appearance.showMinimizedHiddenLabels ? (!windowInfo.isMinimized && !windowInfo.isHidden) : true) {
                TrafficLightButtons(
                    displayMode: appearance.trafficLightVisibility,
                    hoveringOverParentWindow: selected || isHoveringOverWindowSwitcherPreview,
                    onWindowAction: handleWindowAction,
                    pillStyling: !appearance.disableDockStyleTrafficLights,
                    mockPreviewActive: mockPreviewActive,
                    enabledButtons: appearance.enabledTrafficLightButtons,
                    useMonochrome: appearance.useMonochromeTrafficLights
                )
            } else if windowInfo.isMinimized || windowInfo.isHidden,
                      appearance.showMinimizedHiddenLabels,
                      appearance.trafficLightVisibility != .never
            {
                Text(windowInfo.isMinimized ? "Minimized" : "Hidden")
                    .font(appearance.windowTitleFontSize.font)
                    .italic()
                    .foregroundStyle(.secondary)
                    .padding(4)
                    .materialPill()
                    .frame(height: 34)
            }
        }

        return HStack(spacing: 4) {
            if isLeadingControls {
                if showControlsContent { controlsContent }
                Spacer(minLength: 8)
                if showTitleContent {
                    appIconContent
                    titleAndSubtitleContent
                }
            } else {
                if showTitleContent {
                    appIconContent
                    titleAndSubtitleContent
                }
                Spacer(minLength: 8)
                if showControlsContent { controlsContent }
            }
        }
    }

    private func dockPreviewContent(_ selected: Bool, isLeadingControls: Bool, showTitleContent: Bool = true, showControlsContent: Bool = true) -> some View {
        // Determine what title to show: window name first, then app name as fallback
        let titleToShow: String? = if let windowTitle = windowInfo.windowName, !windowTitle.isEmpty {
            windowTitle
        } else {
            windowInfo.app.localizedName
        }

        let hasTitle = appearance.showWindowTitle &&
            titleToShow != nil &&
            (appearance.windowTitleVisibility == .alwaysVisible || selected)

        let hasTrafficLights = windowInfo.closeButton != nil &&
            appearance.trafficLightVisibility != .never &&
            (appearance.showMinimizedHiddenLabels ? (!windowInfo.isMinimized && !windowInfo.isHidden) : true)

        let titleContent = Group {
            if hasTitle, let title = titleToShow {
                MarqueeText(text: title, startDelay: 1)
                    .font(appearance.windowTitleFontSize.font)
                    .padding(4)
                    .if(!appearance.disableDockStyleTitles) { view in
                        view.materialPill()
                    }
            }
        }

        let controlsContent = Group {
            if hasTrafficLights {
                TrafficLightButtons(
                    displayMode: appearance.trafficLightVisibility,
                    hoveringOverParentWindow: selected || isHoveringOverDockPeekPreview,
                    onWindowAction: handleWindowAction,
                    pillStyling: !appearance.disableDockStyleTrafficLights,
                    mockPreviewActive: mockPreviewActive,
                    enabledButtons: appearance.enabledTrafficLightButtons,
                    useMonochrome: appearance.useMonochromeTrafficLights
                )
            } else if windowInfo.isMinimized || windowInfo.isHidden,
                      appearance.showMinimizedHiddenLabels,
                      appearance.trafficLightVisibility != .never
            {
                Text(windowInfo.isMinimized ? "Minimized" : "Hidden")
                    .font(appearance.windowTitleFontSize.font)
                    .italic()
                    .foregroundStyle(.secondary)
                    .padding(4)
                    .materialPill()
                    .frame(height: 34)
            }
        }

        if hasTitle || hasTrafficLights {
            return AnyView(
                HStack(spacing: 4) {
                    if isLeadingControls {
                        if showControlsContent { controlsContent }
                        Spacer(minLength: 8)
                        if showTitleContent { titleContent }
                    } else {
                        if showTitleContent { titleContent }
                        Spacer(minLength: 8)
                        if showControlsContent { controlsContent }
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
                if !appearance.useEmbeddedElements || windowSwitcherActive,
                   appearance.controlPosition.showsOnTop
                {
                    let config = appearance.controlPosition.topConfiguration
                    Group {
                        if windowSwitcherActive {
                            windowSwitcherContent(finalIsSelected, isLeadingControls: config.isLeadingControls, showTitleContent: config.showTitle, showControlsContent: config.showControls)
                        } else {
                            dockPreviewContent(finalIsSelected, isLeadingControls: config.isLeadingControls, showTitleContent: config.showTitle, showControlsContent: config.showControls)
                        }
                    }
                    .padding(.bottom, 4)
                }

                windowContent(
                    isMinimized: windowInfo.isMinimized,
                    isHidden: windowInfo.isHidden,
                    isSelected: finalIsSelected
                )

                if !appearance.useEmbeddedElements || windowSwitcherActive,
                   appearance.controlPosition.showsOnBottom
                {
                    let config = appearance.controlPosition.bottomConfiguration
                    Group {
                        if windowSwitcherActive {
                            windowSwitcherContent(finalIsSelected, isLeadingControls: config.isLeadingControls, showTitleContent: config.showTitle, showControlsContent: config.showControls)
                        } else {
                            dockPreviewContent(finalIsSelected, isLeadingControls: config.isLeadingControls, showTitleContent: config.showTitle, showControlsContent: config.showControls)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: dimensions.maxDimensions.width > 0 ? dimensions.maxDimensions.width : nil)
            .background {
                let cornerRadius = uniformCardRadius ? CardRadius.base + (CardRadius.innerPadding * appearance.globalPaddingMultiplier) : 8.0

                if !appearance.hidePreviewCardBackground {
                    BlurView(variant: 18)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                        .borderedBackground(.primary.opacity(0.1), lineWidth: 1.75, cornerRadius: cornerRadius)
                        .padding(-CardRadius.innerPadding)
                        .overlay {
                            if finalIsSelected {
                                let highlightColor = appearance.hoverHighlightColor ?? Color(nsColor: .controlAccentColor)
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .fill(highlightColor.opacity(appearance.selectionOpacity))
                                    .padding(-CardRadius.innerPadding)
                            }
                        }
                        .overlay {
                            if isActiveWindow {
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .strokeBorder(appearance.activeAppIndicatorColor, lineWidth: 2.5)
                                    .padding(-CardRadius.innerPadding)
                            }
                        }
                }
            }
        }
        .overlay {
            if isDraggingOver {
                let dragRadius = uniformCardRadius ? CardRadius.base + (CardRadius.innerPadding * appearance.globalPaddingMultiplier) : CardRadius.fallback
                RoundedRectangle(cornerRadius: dragRadius)
                    .fill(Color(nsColor: .controlAccentColor).opacity(0.3))
                    .padding(-CardRadius.innerPadding)
                    .opacity(highlightOpacity)
            }

            if !windowSwitcherActive, appearance.useEmbeddedElements {
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
                if appearance.showAnimations {
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
                    if !currentHoverState { setHoverState(true) }
                    onHoverIndexChange?(index, location)
                } else if !currentHoverState {
                    setHoverState(true)
                    handleFullPreviewHover(isHovering: true, action: appearance.previewHoverAction)
                }
            case .ended:
                if windowSwitcherActive { onHoverIndexChange?(nil, nil) }
                if currentHoverState {
                    setHoverState(false)
                    if !windowSwitcherActive { handleFullPreviewHover(isHovering: false, action: appearance.previewHoverAction) }
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
                handleWindowAction: { action in
                    cancelFullPreviewHover()
                    handleWindowAction(action)
                },
                onTap: {
                    cancelFullPreviewHover()
                    onTap?()
                }
            )
            .fixedSize()
            .opacity(skeletonMode ? 0 : 1)
            .allowsHitTesting(!skeletonMode)
    }

    private func cancelFullPreviewHover() {
        fullPreviewTimer?.invalidate()
        fullPreviewTimer = nil
        fullPreviewHoverID = nil
        SharedPreviewWindowCoordinator.activeInstance?.hideFullPreviewWindow()
    }

    private func handleFullPreviewHover(isHovering: Bool, action: PreviewHoverAction) {
        if isHovering, !windowSwitcherActive {
            switch action {
            case .none: break

            case .tap:
                if appearance.tapEquivalentInterval == 0 { handleWindowTap() } else {
                    fullPreviewTimer = Timer.scheduledTimer(withTimeInterval: appearance.tapEquivalentInterval, repeats: false) { _ in
                        DispatchQueue.main.async { handleWindowTap() }
                    }
                }

            case .previewFullSize:
                let hoverID = UUID()
                fullPreviewHoverID = hoverID
                let showFullPreview = {
                    guard fullPreviewHoverID == hoverID else { return }
                    SharedPreviewWindowCoordinator.activeInstance?.showWindow(
                        appName: windowInfo.app.localizedName ?? "Unknown",
                        windows: [windowInfo],
                        mouseScreen: bestGuessMonitor,
                        dockItemElement: nil, overrideDelay: true,
                        centeredHoverWindowState: .fullWindowPreview
                    )
                }
                if appearance.tapEquivalentInterval == 0 {
                    showFullPreview()
                } else {
                    fullPreviewTimer = Timer.scheduledTimer(withTimeInterval: appearance.tapEquivalentInterval, repeats: false) { _ in
                        showFullPreview()
                    }
                }
            }
        } else {
            cancelFullPreviewHover()
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
