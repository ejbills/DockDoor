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
    @Default(.selectionOpacity) var selectionOpacity
    @Default(.selectionColor) var selectionColor
    @Default(.useAccentColorForSelection) var useAccentColorForSelection
    @Default(.dimInSwitcherUntilSelected) var dimInSwitcherUntilSelected

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
                    .aspectRatio(contentMode: .fit)
                    .markHidden(isHidden: inactive || (windowSwitcherActive && !isSelected && dimInSwitcherUntilSelected))
                    .overlay(isSelected && !inactive ? CustomizableFluidGradientView().opacity(0.125) : nil)
                    .clipShape(uniformCardRadius ? AnyShape(RoundedRectangle(cornerRadius: 12, style: .continuous)) : AnyShape(Rectangle()))
            }
        }
        .frame(width: max(dimensions.size.width, 50), height: dimensions.size.height, alignment: .center)
        .frame(maxWidth: dimensions.maxDimensions.width, maxHeight: dimensions.maxDimensions.height)
        .shadow(radius: isSelected ? 0 : 3)
        .overlay(alignment: {
            switch windowTitlePosition {
            case .bottomLeft: .bottomLeading
            case .bottomRight: .bottomTrailing
            case .topRight: .topTrailing
            case .topLeft: .topLeading
            }
        }()) {
            if !windowSwitcherActive {
                windowTitleOverlay(selected: isSelected)
            }
        }
        .overlay(alignment: {
            switch trafficLightButtonsPosition {
            case .bottomLeft: .bottomLeading
            case .bottomRight: .bottomTrailing
            case .topRight: .topTrailing
            case .topLeft: .topLeading
            }
        }()) {
            if !windowSwitcherActive, !isMinimized, !isHidden, let _ = windowInfo.closeButton {
                TrafficLightButtons(
                    displayMode: trafficLightButtonsVisibility,
                    hoveringOverParentWindow: isSelected || isHoveringOverWindowSwitcherPreview,
                    onWindowAction: handleWindowAction,
                    pillStyling: false,
                    mockPreviewActive: mockPreviewActive
                )
                .padding(4)
            }
        }
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
                HStack(spacing: 0) {
                    Text(windowTitle)

                    if windowInfo.isMinimized || windowInfo.isHidden {
                        Text(" - Inactive").italic()
                    }
                }
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
        .frame(
            maxWidth: max(dimensions.size.width * 0.6, 70),
        ).fixedSize(horizontal: true, vertical: false)

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
            }
            .background {
                if finalIsSelected {
                    let highlightColor: Color = if useAccentColorForSelection {
                        Color(nsColor: .controlAccentColor)
                    } else {
                        selectionColor ?? .secondary
                    }
                    RoundedRectangle(cornerRadius: uniformCardRadius ? 14 : 0)
                        .fill(highlightColor.opacity(selectionOpacity))
                        .padding(-6)
                }
            }
        }
        .overlay {
            if isDraggingOver {
                RoundedRectangle(cornerRadius: uniformCardRadius ? 14 : 0)
                    .strokeBorder(Color(nsColor: .controlAccentColor), lineWidth: 2)
                    .padding(-2)
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
