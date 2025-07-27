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

    @Default(.tapEquivalentInterval) var tapEquivalentInterval
    @Default(.previewHoverAction) var previewHoverAction

    @State private var isHoveringOverDockPeekPreview = false
    @State private var isHoveringOverWindowSwitcherPreview = false
    @State private var fullPreviewTimer: Timer?
    @State private var isDraggingOver = false
    @State private var dragTimer: Timer?
    @State private var highlightOpacity = 0.0

    private func windowContent(isMinimized: Bool, isHidden: Bool, isSelected: Bool) -> some View {
        Group {
            if let cgImage = windowInfo.image {
                let inactive = isMinimized || isHidden
                Image(decorative: cgImage, scale: 1.0)
                    .resizable()
                    .scaledToFit()
                    .markHidden(isHidden: inactive || (windowSwitcherActive && !isSelected))
                    .overlay {
                        if inactive {
                            Image(systemName: "eye.slash")
                                .font(.largeTitle)
                                .foregroundColor(.primary)
                                .shadow(radius: 2)
                        }
                    }
                    .clipShape(uniformCardRadius ? AnyShape(RoundedRectangle(cornerRadius: 12, style: .continuous)) : AnyShape(Rectangle()))
            }
        }
        .frame(width: max(dimensions.size.width, 50), height: dimensions.size.height, alignment: .center)
        .frame(maxWidth: dimensions.maxDimensions.width, maxHeight: dimensions.maxDimensions.height)
        .opacity(isSelected ? 1.0 : unselectedContentOpacity)
    }

    private func windowSwitcherContent(_ selected: Bool) -> some View {
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
            if !windowInfo.isMinimized, !windowInfo.isHidden, windowInfo.closeButton != nil {
                TrafficLightButtons(
                    displayMode: trafficLightButtonsVisibility,
                    hoveringOverParentWindow: selected || isHoveringOverWindowSwitcherPreview,
                    onWindowAction: handleWindowAction,
                    pillStyling: true, mockPreviewActive: mockPreviewActive
                )
            } else if windowInfo.isMinimized || windowInfo.isHidden {
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
                    controlsContent
                    Spacer()
                    appIconContent
                    titleAndSubtitleContent
                } else {
                    appIconContent
                    titleAndSubtitleContent
                    Spacer()
                    controlsContent
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
            }
        }
        .padding(windowSwitcherControlPosition == .topLeading ||
            windowSwitcherControlPosition == .topTrailing ?
            .bottom : .top, 4)
    }

    private func dockPreviewContent(_ selected: Bool) -> some View {
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

        let hasTrafficLights = !windowInfo.isMinimized &&
            !windowInfo.isHidden &&
            windowInfo.closeButton != nil &&
            trafficLightButtonsVisibility != .never

        let titleContent = Group {
            if hasTitle, let title = titleToShow {
                MarqueeText(text: title, startDelay: 1)
                    .font(.subheadline)
                    .padding(4)
                    .materialPill()
            }
        }

        let controlsContent = Group {
            if hasTrafficLights {
                TrafficLightButtons(
                    displayMode: trafficLightButtonsVisibility,
                    hoveringOverParentWindow: selected || isHoveringOverDockPeekPreview,
                    onWindowAction: handleWindowAction,
                    pillStyling: true,
                    mockPreviewActive: mockPreviewActive
                )
            } else if windowInfo.isMinimized || windowInfo.isHidden {
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
                    controlsContent
                    Spacer()
                    titleContent
                } else {
                    titleContent
                    Spacer()
                    controlsContent
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
                    }
                }
                .padding(dockPreviewControlPosition == .topLeading ||
                    dockPreviewControlPosition == .topTrailing ?
                    .bottom : .top, 4)
            )
        } else {
            return AnyView(EmptyView())
        }
    }

    @ViewBuilder
    private var previewCoreContent: some View {
        let isSelectedByKeyboardInDock = !windowSwitcherActive && (index == currIndex)
        let isSelectedByKeyboardInSwitcher = windowSwitcherActive && (index == currIndex)

        let finalIsSelected = isHoveringOverDockPeekPreview ||
            isSelectedByKeyboardInSwitcher ||
            isSelectedByKeyboardInDock ||
            isHoveringOverWindowSwitcherPreview

        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 0) {
                if windowSwitcherActive, windowSwitcherControlPosition == .topLeading ||
                    windowSwitcherControlPosition == .topTrailing
                {
                    windowSwitcherContent(finalIsSelected)
                }

                if !windowSwitcherActive, dockPreviewControlPosition == .topLeading ||
                    dockPreviewControlPosition == .topTrailing
                {
                    dockPreviewContent(finalIsSelected)
                }

                windowContent(
                    isMinimized: windowInfo.isMinimized,
                    isHidden: windowInfo.isHidden,
                    isSelected: finalIsSelected
                )

                if windowSwitcherActive, windowSwitcherControlPosition == .bottomLeading ||
                    windowSwitcherControlPosition == .bottomTrailing
                {
                    windowSwitcherContent(finalIsSelected)
                }

                if !windowSwitcherActive, dockPreviewControlPosition == .bottomLeading ||
                    dockPreviewControlPosition == .bottomTrailing
                {
                    dockPreviewContent(finalIsSelected)
                }
            }
            .background {
                // Always show background - gray by default, accent color (or custom) on hover
                let (backgroundColor, opacity): (Color, CGFloat) = if finalIsSelected {
                    (hoverHighlightColor ?? Color(nsColor: .controlAccentColor), selectionOpacity)
                } else {
                    (Color.secondary, selectionOpacity * 0.3)
                }
                RoundedRectangle(cornerRadius: uniformCardRadius ? 20 : 0)
                    .fill(backgroundColor.opacity(opacity))
                    .padding(-6)
            }
        }
        .overlay {
            if isDraggingOver {
                RoundedRectangle(cornerRadius: uniformCardRadius ? 20 : 0)
                    .fill(Color(nsColor: .controlAccentColor).opacity(0.3))
                    .padding(-6)
                    .opacity(highlightOpacity)
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
        .onHover { isHovering in
            if !isDraggingOver {
                withAnimation(.snappy(duration: 0.175)) {
                    if !windowSwitcherActive {
                        isHoveringOverDockPeekPreview = isHovering
                        handleFullPreviewHover(isHovering: isHovering, action: previewHoverAction)
                    } else {
                        isHoveringOverWindowSwitcherPreview = isHovering
                    }
                }
            }
        }
        .onTapGesture {
            handleWindowTap()
        }
        .contextMenu {
            if windowInfo.closeButton != nil {
                Button(action: { handleWindowAction(.minimize) }) {
                    if windowInfo.isMinimized {
                        Label("Un-minimize", systemImage: "arrow.up.left.and.arrow.down.right.square")
                    } else {
                        Label("Minimize", systemImage: "minus.square")
                    }
                }

                Button(action: { handleWindowAction(.toggleFullScreen) }) {
                    Label("Toggle Full Screen", systemImage: "arrow.up.left.and.arrow.down.right.square")
                }

                Divider()

                Button(action: { handleWindowAction(.close) }) {
                    Label("Close", systemImage: "xmark.square")
                }

                Button(role: .destructive, action: { handleWindowAction(.quit) }) {
                    if NSEvent.modifierFlags.contains(.option) {
                        Label("Force Quit", systemImage: "power.square.fill")
                    } else {
                        Label("Quit", systemImage: "minus.square.fill")
                    }
                }
            }
        }
    }

    var body: some View {
        previewCoreContent
            .onMiddleClick(perform: {
                if windowInfo.closeButton != nil {
                    handleWindowAction(.close)
                }
            })
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
        }
    }

    private func handleWindowTap() {
        if windowInfo.isMinimized {
            handleWindowAction(.minimize)
        } else if windowInfo.isHidden {
            handleWindowAction(.hide)
        } else {
            WindowUtil.bringWindowToFront(windowInfo: windowInfo)
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

    @ViewBuilder
    private func windowTitleOverlay(selected: Bool) -> some View {
        let shouldShowTitle = showWindowTitle && (
            windowTitleDisplayCondition == .all ||
                (windowTitleDisplayCondition == .dockPreviewsOnly && !windowSwitcherActive) ||
                (windowTitleDisplayCondition == .windowSwitcherOnly && windowSwitcherActive)
        )
        if shouldShowTitle, windowTitleVisibility == .alwaysVisible || selected {
            if let windowTitle = windowInfo.windowName,
               !windowTitle.isEmpty,
               windowTitle != windowInfo.app.localizedName
            {
                MarqueeText(text: windowTitle, startDelay: 1)
                    .font(.caption)
                    .lineLimit(1)
                    .materialPill()
                    .padding(4)
            }
        }
    }
}
