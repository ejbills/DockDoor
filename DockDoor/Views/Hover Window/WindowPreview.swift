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
    let mockPreviewActive: Bool
    let disableActions: Bool
    let onHoverIndexChange: ((Int?, CGPoint?) -> Void)?
    var isEligibleForLivePreview: Bool = true

    @Default(.windowSwitcherControlPosition) var windowSwitcherControlPosition
    @Default(.dockPreviewControlPosition) var dockPreviewControlPosition
    @Default(.selectionOpacity) var selectionOpacity
    @Default(.unselectedContentOpacity) var unselectedContentOpacity
    @Default(.hoverHighlightColor) var hoverHighlightColor
    @Default(.allowDynamicImageSizing) var allowDynamicImageSizing
    @Default(.useEmbeddedDockPreviewElements) var useEmbeddedDockPreviewElements
    @Default(.useEmbeddedWindowSwitcherElements) var useEmbeddedWindowSwitcherElements
    @Default(.hidePreviewCardBackground) var hidePreviewCardBackground
    @Default(.showMinimizedHiddenLabels) var showMinimizedHiddenLabels

    // Dock embedded mode settings
    @Default(.showWindowTitle) var dockShowWindowTitle
    @Default(.windowTitleVisibility) var dockWindowTitleVisibility
    @Default(.trafficLightButtonsVisibility) var dockTrafficLightButtonsVisibility
    @Default(.enabledTrafficLightButtons) var dockEnabledTrafficLightButtons
    @Default(.useMonochromeTrafficLights) var dockUseMonochromeTrafficLights
    @Default(.disableDockStyleTrafficLights) var dockDisableDockStyleTrafficLights
    @Default(.disableDockStyleTitles) var dockDisableDockStyleTitles
    @Default(.disableButtonHoverEffects) var dockDisableButtonHoverEffects

    // Window Switcher header settings
    @Default(.switcherShowHeaderAppIcon) var switcherShowHeaderAppIcon
    @Default(.switcherShowHeaderAppName) var switcherShowHeaderAppName
    @Default(.switcherShowHeaderWindowTitle) var switcherShowHeaderWindowTitle
    @Default(.switcherHeaderAppIconVisibility) var switcherHeaderAppIconVisibility
    @Default(.switcherHeaderAppNameVisibility) var switcherHeaderAppNameVisibility
    @Default(.switcherHeaderTitleVisibility) var switcherHeaderTitleVisibility

    // Window Switcher embedded mode settings
    @Default(.switcherShowWindowTitle) var switcherShowWindowTitle
    @Default(.switcherWindowTitleVisibility) var switcherWindowTitleVisibility
    @Default(.switcherTrafficLightButtonsVisibility) var switcherTrafficLightButtonsVisibility
    @Default(.switcherEnabledTrafficLightButtons) var switcherEnabledTrafficLightButtons
    @Default(.switcherUseMonochromeTrafficLights) var switcherUseMonochromeTrafficLights
    @Default(.switcherDisableDockStyleTrafficLights) var switcherDisableDockStyleTrafficLights
    @Default(.switcherDisableDockStyleTitles) var switcherDisableDockStyleTitles
    @Default(.switcherDisableButtonHoverEffects) var switcherDisableButtonHoverEffects

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

    /// Calculates opacity based on visibility setting and hover state
    private func visibilityOpacity(for visibility: WindowTitleVisibility, isHovering: Bool, dimmedOpacity: Double = 0.25) -> Double {
        switch visibility {
        case .whenHoveringPreview, .hiddenUntilHover:
            (isHovering || mockPreviewActive) ? 1.0 : 0.0
        case .never:
            0.0
        case .dimmedUntilHover:
            (isHovering || mockPreviewActive) ? 1.0 : dimmedOpacity
        case .alwaysVisible:
            1.0
        }
    }

    /// Reusable position-based layout for embedded controls (title + traffic lights)
    @ViewBuilder
    private func positionedControlsLayout(
        position: WindowSwitcherControlPosition,
        @ViewBuilder titleContent: () -> some View,
        @ViewBuilder controlsContent: () -> some View
    ) -> some View {
        switch position {
        case .topLeading, .topTrailing:
            VStack {
                HStack(spacing: 4) {
                    if position == .topLeading {
                        titleContent()
                        Spacer()
                        controlsContent()
                    } else {
                        controlsContent()
                        Spacer()
                        titleContent()
                    }
                }
                .padding(8)
                Spacer()
            }
        case .bottomLeading, .bottomTrailing:
            VStack {
                Spacer()
                HStack(spacing: 4) {
                    if position == .bottomLeading {
                        titleContent()
                        Spacer()
                        controlsContent()
                    } else {
                        controlsContent()
                        Spacer()
                        titleContent()
                    }
                }
                .padding(8)
            }
        case .diagonalTopLeftBottomRight:
            VStack {
                HStack { titleContent(); Spacer() }
                    .padding(.leading, 8).padding(.top, 8)
                Spacer()
                HStack { Spacer(); controlsContent() }
                    .padding(.trailing, 8).padding(.bottom, 8)
            }
        case .diagonalTopRightBottomLeft:
            VStack {
                HStack { Spacer(); titleContent() }
                    .padding(.trailing, 8).padding(.top, 8)
                Spacer()
                HStack { controlsContent(); Spacer() }
                    .padding(.leading, 8).padding(.bottom, 8)
            }
        case .diagonalBottomLeftTopRight:
            VStack {
                HStack { Spacer(); controlsContent() }
                    .padding(.trailing, 8).padding(.top, 8)
                Spacer()
                HStack { titleContent(); Spacer() }
                    .padding(.leading, 8).padding(.bottom, 8)
            }
        case .diagonalBottomRightTopLeft:
            VStack {
                HStack { controlsContent(); Spacer() }
                    .padding(.leading, 8).padding(.top, 8)
                Spacer()
                HStack { Spacer(); titleContent() }
                    .padding(.trailing, 8).padding(.bottom, 8)
            }
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
        } else if windowSwitcherActive, useEmbeddedWindowSwitcherElements {
            embeddedWindowSwitcherControls()
        }
    }

    @ViewBuilder
    private func embeddedDockPreviewControls(_ selected: Bool) -> some View {
        let titleToShow: String? = if let windowTitle = windowInfo.windowName, !windowTitle.isEmpty {
            windowTitle
        } else {
            windowInfo.app.localizedName
        }

        let shouldShowTitle = dockShowWindowTitle && titleToShow != nil && dockWindowTitleVisibility != .never
        let titleOpacity = visibilityOpacity(for: dockWindowTitleVisibility, isHovering: isHoveringOverDockPeekPreview)

        let hasTrafficLights = windowInfo.closeButton != nil &&
            dockTrafficLightButtonsVisibility != .never &&
            (showMinimizedHiddenLabels ? (!windowInfo.isMinimized && !windowInfo.isHidden) : true)

        let titleContent = Group {
            if shouldShowTitle, let title = titleToShow {
                MarqueeText(text: title, startDelay: 1)
                    .font(.subheadline)
                    .padding(4)
                    .if(!dockDisableDockStyleTitles) { view in
                        view.materialPill()
                    }
                    .opacity(titleOpacity)
            }
        }

        let effectiveHoverForControls = disableActions ? isHoveringOverDockPeekPreview : (selected || isHoveringOverDockPeekPreview)
        let controlsContent = Group {
            if hasTrafficLights {
                TrafficLightButtons(
                    displayMode: dockTrafficLightButtonsVisibility,
                    hoveringOverParentWindow: effectiveHoverForControls,
                    onWindowAction: handleWindowAction,
                    pillStyling: !dockDisableDockStyleTrafficLights,
                    mockPreviewActive: mockPreviewActive,
                    enabledButtons: dockEnabledTrafficLightButtons,
                    useMonochrome: dockUseMonochromeTrafficLights,
                    disableButtonHoverEffects: dockDisableButtonHoverEffects
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

        if shouldShowTitle || hasTrafficLights {
            positionedControlsLayout(
                position: dockPreviewControlPosition,
                titleContent: { titleContent },
                controlsContent: { controlsContent }
            )
        }
    }

    @ViewBuilder
    private func embeddedWindowSwitcherControls() -> some View {
        let selected = isHoveringOverWindowSwitcherPreview || index == currIndex

        let titleToShow: String? = if let windowTitle = windowInfo.windowName, !windowTitle.isEmpty {
            windowTitle
        } else {
            windowInfo.app.localizedName
        }

        let shouldShowTitle = switcherShowWindowTitle && titleToShow != nil && switcherWindowTitleVisibility != .never
        let titleOpacity = visibilityOpacity(for: switcherWindowTitleVisibility, isHovering: isHoveringOverWindowSwitcherPreview)

        let hasTrafficLights = windowInfo.closeButton != nil &&
            switcherTrafficLightButtonsVisibility != .never &&
            (showMinimizedHiddenLabels ? (!windowInfo.isMinimized && !windowInfo.isHidden) : true)

        let titleContent = Group {
            if shouldShowTitle, let title = titleToShow {
                MarqueeText(text: title, startDelay: 1)
                    .font(.subheadline)
                    .padding(4)
                    .if(!switcherDisableDockStyleTitles) { view in
                        view.materialPill()
                    }
                    .opacity(titleOpacity)
            }
        }

        let effectiveHoverForSwitcherControls = disableActions ? isHoveringOverWindowSwitcherPreview : selected
        let controlsContent = Group {
            if hasTrafficLights {
                TrafficLightButtons(
                    displayMode: switcherTrafficLightButtonsVisibility,
                    hoveringOverParentWindow: effectiveHoverForSwitcherControls,
                    onWindowAction: handleWindowAction,
                    pillStyling: !switcherDisableDockStyleTrafficLights,
                    mockPreviewActive: mockPreviewActive,
                    enabledButtons: switcherEnabledTrafficLightButtons,
                    useMonochrome: switcherUseMonochromeTrafficLights,
                    disableButtonHoverEffects: switcherDisableButtonHoverEffects
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

        if shouldShowTitle || hasTrafficLights {
            positionedControlsLayout(
                position: windowSwitcherControlPosition,
                titleContent: { titleContent },
                controlsContent: { controlsContent }
            )
        }
    }

    @ViewBuilder
    private func embeddedWindowSwitcherHeader() -> some View {
        let windowTitle = windowInfo.windowName ?? ""
        let appName = windowInfo.app.localizedName ?? "Unknown"
        let hasWindowTitleContent = !windowTitle.isEmpty && windowTitle != appName

        let iconOpacity = visibilityOpacity(for: switcherHeaderAppIconVisibility, isHovering: isHoveringOverWindowSwitcherPreview, dimmedOpacity: 0.5)
        let nameOpacity = visibilityOpacity(for: switcherHeaderAppNameVisibility, isHovering: isHoveringOverWindowSwitcherPreview, dimmedOpacity: 0.5)
        let titleOpacity = visibilityOpacity(for: switcherHeaderTitleVisibility, isHovering: isHoveringOverWindowSwitcherPreview, dimmedOpacity: 0.5)

        let showIcon = switcherShowHeaderAppIcon && windowInfo.app.icon != nil && iconOpacity > 0
        let showName = switcherShowHeaderAppName && nameOpacity > 0
        let showTitle = switcherShowHeaderWindowTitle && hasWindowTitleContent && titleOpacity > 0
        let showSeparator = showName && showTitle

        if !(showIcon || showName || showTitle) {
            EmptyView()
        } else {
            HStack(spacing: 6) {
                if showIcon, let appIcon = windowInfo.app.icon {
                    Image(nsImage: appIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .opacity(iconOpacity)
                }

                if switcherShowHeaderAppName {
                    Text(appName)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .opacity(nameOpacity)
                }

                if showSeparator {
                    Text(verbatim: "—")
                        .foregroundStyle(.secondary)
                }

                if switcherShowHeaderWindowTitle, hasWindowTitleContent {
                    MarqueeText(text: windowTitle, startDelay: 1)
                        .foregroundStyle(switcherShowHeaderAppName ? .secondary : .primary)
                        .lineLimit(1)
                        .opacity(titleOpacity)
                }

                Spacer(minLength: 0)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 4)
        }
    }

    private func windowSwitcherContent(_ selected: Bool, showTitleContent: Bool = true, showControlsContent: Bool = true) -> some View {
        let appIconOpacity: Double = switcherHeaderAppIconVisibility == .alwaysVisible || selected ? 1.0 : 0.0
        let appNameOpacity: Double = switcherHeaderAppNameVisibility == .alwaysVisible || selected ? 1.0 : 0.0
        let titleOpacity: Double = switcherHeaderTitleVisibility == .alwaysVisible || selected ? 1.0 : 0.0

        let titleAndSubtitleContent = VStack(alignment: .leading, spacing: 0) {
            if switcherShowHeaderAppName {
                Text(windowInfo.app.localizedName ?? "Unknown")
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .opacity(appNameOpacity)
            }

            if switcherShowHeaderWindowTitle,
               let windowTitle = windowInfo.windowName,
               !windowTitle.isEmpty,
               windowTitle != windowInfo.app.localizedName
            {
                MarqueeText(text: windowTitle, startDelay: 1)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .opacity(titleOpacity)
            }
        }

        let appIconContent = Group {
            if switcherShowHeaderAppIcon, let appIcon = windowInfo.app.icon {
                Image(nsImage: appIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 35, height: 35)
                    .opacity(appIconOpacity)
            }
        }

        let effectiveHoverForNonEmbeddedSwitcher = disableActions ? isHoveringOverWindowSwitcherPreview : (selected || isHoveringOverWindowSwitcherPreview)
        let controlsContent = Group {
            if windowInfo.closeButton != nil && switcherTrafficLightButtonsVisibility != .never && (showMinimizedHiddenLabels ? (!windowInfo.isMinimized && !windowInfo.isHidden) : true) {
                TrafficLightButtons(
                    displayMode: switcherTrafficLightButtonsVisibility,
                    hoveringOverParentWindow: effectiveHoverForNonEmbeddedSwitcher,
                    onWindowAction: handleWindowAction,
                    pillStyling: true,
                    mockPreviewActive: mockPreviewActive,
                    enabledButtons: switcherEnabledTrafficLightButtons,
                    useMonochrome: switcherUseMonochromeTrafficLights,
                    disableButtonHoverEffects: switcherDisableButtonHoverEffects
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
            case .diagonalTopLeftBottomRight, .diagonalBottomLeftTopRight:
                contentRow(isLeadingControls: false)
            case .diagonalTopRightBottomLeft, .diagonalBottomRightTopLeft:
                contentRow(isLeadingControls: true)
            }
        }
    }

    private func dockPreviewContent(_ selected: Bool, showTitleContent: Bool = true, showControlsContent: Bool = true) -> some View {
        let shouldShowTitle = dockShowWindowTitle

        // Determine what title to show: window name first, then app name as fallback
        let titleToShow: String? = if let windowTitle = windowInfo.windowName, !windowTitle.isEmpty {
            windowTitle
        } else {
            windowInfo.app.localizedName
        }

        let showTitleEnabled = shouldShowTitle && titleToShow != nil && dockWindowTitleVisibility != .never
        let titleOpacity = visibilityOpacity(for: dockWindowTitleVisibility, isHovering: isHoveringOverDockPeekPreview)

        let hasTrafficLights = windowInfo.closeButton != nil &&
            dockTrafficLightButtonsVisibility != .never &&
            (showMinimizedHiddenLabels ? (!windowInfo.isMinimized && !windowInfo.isHidden) : true)

        let titleContent = Group {
            if showTitleEnabled, let title = titleToShow {
                MarqueeText(text: title, startDelay: 1)
                    .font(.subheadline)
                    .padding(4)
                    .if(!dockDisableDockStyleTitles) { view in
                        view.materialPill()
                    }
                    .opacity(titleOpacity)
            }
        }

        let effectiveHoverForDockControls = disableActions ? isHoveringOverDockPeekPreview : (selected || isHoveringOverDockPeekPreview)
        let controlsContent = Group {
            if hasTrafficLights {
                TrafficLightButtons(
                    displayMode: dockTrafficLightButtonsVisibility,
                    hoveringOverParentWindow: effectiveHoverForDockControls,
                    onWindowAction: handleWindowAction,
                    pillStyling: !dockDisableDockStyleTrafficLights,
                    mockPreviewActive: mockPreviewActive,
                    enabledButtons: dockEnabledTrafficLightButtons,
                    useMonochrome: dockUseMonochromeTrafficLights,
                    disableButtonHoverEffects: dockDisableButtonHoverEffects
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
        if showTitleEnabled || hasTrafficLights {
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
                    case .diagonalTopLeftBottomRight, .diagonalBottomLeftTopRight:
                        contentRow(isLeadingControls: false)
                    case .diagonalTopRightBottomLeft, .diagonalBottomRightTopLeft:
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

        let showDockHeader = !windowSwitcherActive && !useEmbeddedDockPreviewElements
        let useEmbeddedSwitcherHeader = windowSwitcherActive && useEmbeddedWindowSwitcherElements
        let showNormalSwitcherHeader = windowSwitcherActive && !useEmbeddedWindowSwitcherElements

        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 0) {
                if useEmbeddedSwitcherHeader {
                    embeddedWindowSwitcherHeader()
                }

                if showNormalSwitcherHeader {
                    Group {
                        if windowSwitcherControlPosition == .topLeading ||
                            windowSwitcherControlPosition == .topTrailing
                        {
                            windowSwitcherContent(finalIsSelected)
                        } else if windowSwitcherControlPosition == .diagonalTopLeftBottomRight {
                            windowSwitcherContent(finalIsSelected, showTitleContent: true, showControlsContent: false)
                        } else if windowSwitcherControlPosition == .diagonalTopRightBottomLeft {
                            windowSwitcherContent(finalIsSelected, showTitleContent: true, showControlsContent: false)
                        } else if windowSwitcherControlPosition == .diagonalBottomLeftTopRight {
                            windowSwitcherContent(finalIsSelected, showTitleContent: false, showControlsContent: true)
                        } else if windowSwitcherControlPosition == .diagonalBottomRightTopLeft {
                            windowSwitcherContent(finalIsSelected, showTitleContent: false, showControlsContent: true)
                        }
                    }
                    .padding(.bottom, 4)
                }

                if showDockHeader {
                    Group {
                        if dockPreviewControlPosition == .topLeading ||
                            dockPreviewControlPosition == .topTrailing
                        {
                            dockPreviewContent(finalIsSelected)
                        } else if dockPreviewControlPosition == .diagonalTopLeftBottomRight {
                            dockPreviewContent(finalIsSelected, showTitleContent: true, showControlsContent: false)
                        } else if dockPreviewControlPosition == .diagonalTopRightBottomLeft {
                            dockPreviewContent(finalIsSelected, showTitleContent: true, showControlsContent: false)
                        } else if dockPreviewControlPosition == .diagonalBottomLeftTopRight {
                            dockPreviewContent(finalIsSelected, showTitleContent: false, showControlsContent: true)
                        } else if dockPreviewControlPosition == .diagonalBottomRightTopLeft {
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
                .overlay(alignment: .topLeading) {
                    if useEmbeddedSwitcherHeader {
                        embeddedWindowSwitcherControls()
                            .allowsHitTesting(true)
                    }
                }

                if showNormalSwitcherHeader {
                    Group {
                        if windowSwitcherControlPosition == .bottomLeading ||
                            windowSwitcherControlPosition == .bottomTrailing
                        {
                            windowSwitcherContent(finalIsSelected)
                        } else if windowSwitcherControlPosition == .diagonalTopLeftBottomRight {
                            windowSwitcherContent(finalIsSelected, showTitleContent: false, showControlsContent: true)
                        } else if windowSwitcherControlPosition == .diagonalTopRightBottomLeft {
                            windowSwitcherContent(finalIsSelected, showTitleContent: false, showControlsContent: true)
                        } else if windowSwitcherControlPosition == .diagonalBottomLeftTopRight {
                            windowSwitcherContent(finalIsSelected, showTitleContent: true, showControlsContent: false)
                        } else if windowSwitcherControlPosition == .diagonalBottomRightTopLeft {
                            windowSwitcherContent(finalIsSelected, showTitleContent: true, showControlsContent: false)
                        }
                    }
                    .padding(.top, 4)
                }

                if showDockHeader {
                    Group {
                        if dockPreviewControlPosition == .bottomLeading ||
                            dockPreviewControlPosition == .bottomTrailing
                        {
                            dockPreviewContent(finalIsSelected)
                        } else if dockPreviewControlPosition == .diagonalTopLeftBottomRight {
                            dockPreviewContent(finalIsSelected, showTitleContent: false, showControlsContent: true)
                        } else if dockPreviewControlPosition == .diagonalTopRightBottomLeft {
                            dockPreviewContent(finalIsSelected, showTitleContent: false, showControlsContent: true)
                        } else if dockPreviewControlPosition == .diagonalBottomLeftTopRight {
                            dockPreviewContent(finalIsSelected, showTitleContent: true, showControlsContent: false)
                        } else if dockPreviewControlPosition == .diagonalBottomRightTopLeft {
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
                    if !currentHoverState { setHoverState(true) }
                    onHoverIndexChange?(index, location)
                } else if !currentHoverState {
                    setHoverState(true)
                    handleFullPreviewHover(isHovering: true, action: previewHoverAction)
                }
            case .ended:
                if windowSwitcherActive { onHoverIndexChange?(nil, nil) }
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
        guard !disableActions else { return }
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
