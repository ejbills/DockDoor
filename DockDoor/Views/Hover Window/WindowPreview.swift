import Defaults
import SwiftUI

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

    @Default(.windowTitlePosition) var windowTitlePosition
    @Default(.showWindowTitle) var showWindowTitle
    @Default(.windowTitleDisplayCondition) var windowTitleDisplayCondition
    @Default(.windowTitleVisibility) var windowTitleVisibility
    @Default(.trafficLightButtonsVisibility) var trafficLightButtonsVisibility
    @Default(.trafficLightButtonsPosition) var trafficLightButtonsPosition
    @Default(.windowSwitcherControlPosition) var windowSwitcherControlPosition
    @Default(.selectionOpacity) var selectionOpacity
    @Default(.selectionColor) var selectionColor
    @Default(.dimInSwitcherUntilSelected) var dimInSwitcherUntilSelected

    // preview popup action handlers
    @Default(.tapEquivalentInterval) var tapEquivalentInterval
    @Default(.previewHoverAction) var previewHoverAction

    @State private var isHoveringOverDockPeekPreview = false
    @State private var isHoveringOverWindowSwitcherPreview = false
    @State private var fullPreviewTimer: Timer?

    private func windowContent(isMinimized: Bool, isHidden: Bool, isSelected: Bool) -> some View {
        Group {
            if let cgImage = windowInfo.image {
                let inactive = isMinimized || isHidden
                Image(decorative: cgImage, scale: 1.0)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .markHidden(isHidden: inactive || windowSwitcherActive && !isSelected && dimInSwitcherUntilSelected)
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
                    windowInfo: windowInfo,
                    displayMode: trafficLightButtonsVisibility,
                    hoveringOverParentWindow: isSelected || isHoveringOverWindowSwitcherPreview,
                    onWindowAction: handleWindowAction,
                    pillStyling: false
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
            Text(windowInfo.app.localizedName ?? "Unknown")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            if let windowTitle = windowInfo.window.title,
               !windowTitle.isEmpty,
               windowTitle != windowInfo.app.localizedName,
               shouldShowTitle
            {
                Text(windowInfo.windowName ?? "Hidden window")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(
            minWidth: 50,
            idealWidth: nil,
            maxWidth: max(dimensions.size.width * 0.6, 70),
            alignment: .leading
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
                    windowInfo: windowInfo,
                    displayMode: trafficLightButtonsVisibility,
                    hoveringOverParentWindow: selected || isHoveringOverWindowSwitcherPreview,
                    onWindowAction: handleWindowAction,
                    pillStyling: true
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

    var body: some View {
        let isHighlightedInWindowSwitcher = (index == currIndex && windowSwitcherActive)
        let selected = isHoveringOverDockPeekPreview || isHighlightedInWindowSwitcher || isHoveringOverWindowSwitcherPreview

        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 0) {
                // Title and traffic lights for window switcher mode in top mode
                if windowSwitcherActive, windowSwitcherControlPosition == .topLeading ||
                    windowSwitcherControlPosition == .topTrailing
                {
                    windowSwitcherContent(selected)
                }

                // Window content
                windowContent(
                    isMinimized: windowInfo.isMinimized,
                    isHidden: windowInfo.isHidden,
                    isSelected: selected
                )

                // Title and traffic lights for window switcher mode in bottom mode
                if windowSwitcherActive, windowSwitcherControlPosition == .bottomLeading ||
                    windowSwitcherControlPosition == .bottomTrailing
                {
                    windowSwitcherContent(selected)
                }
            }
            .background {
                if selected || isHoveringOverWindowSwitcherPreview {
                    RoundedRectangle(cornerRadius: uniformCardRadius ? 14 : 0)
                        .fill(selectionColor?.opacity(selectionOpacity) ?? Color.secondary.opacity(selectionOpacity))
                        .padding(-6)
                }
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .contentShape(Rectangle())
        .onHover { isHovering in
            withAnimation(.snappy(duration: 0.175)) {
                if !windowSwitcherActive {
                    isHoveringOverDockPeekPreview = isHovering
                    handleFullPreviewHover(isHovering: isHovering, action: previewHoverAction)
                } else {
                    isHoveringOverWindowSwitcherPreview = isHovering
                }
            }
        }
        .onTapGesture {
            handleWindowTap()
        }
        .contextMenu(menuItems: {
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

                Button(role: .destructive, action: {
                    handleWindowAction(.quit)
                }) {
                    if NSEvent.modifierFlags.contains(.option) {
                        Label("Force Quit", systemImage: "power.square.fill")
                    } else {
                        Label("Quit", systemImage: "power.square")
                    }
                }
            }
        })
        .fixedSize()
    }

    private func handleFullPreviewHover(isHovering: Bool, action: PreviewHoverAction) {
        if isHovering, !windowSwitcherActive {
            switch action {
            case .none:
                // Do nothing for .none
                break

            case .tap:
                // If the interval is 0, immediately trigger the tap action
                if tapEquivalentInterval == 0 {
                    handleWindowTap()
                } else {
                    // Set a timer to trigger the tap action after the specified interval
                    fullPreviewTimer = Timer.scheduledTimer(withTimeInterval: tapEquivalentInterval, repeats: false) { [self] _ in
                        DispatchQueue.main.async {
                            handleWindowTap()
                        }
                    }
                }

            case .previewFullSize:
                // If the interval is 0, show the full window preview immediately
                if tapEquivalentInterval == 0 {
                    DispatchQueue.main.async {
                        SharedPreviewWindowCoordinator.shared.showWindow(
                            appName: windowInfo.app.localizedName ?? "Unknown",
                            windows: [windowInfo],
                            mouseScreen: bestGuessMonitor,
                            iconRect: nil,
                            overrideDelay: true,
                            centeredHoverWindowState: .fullWindowPreview
                        )
                    }
                } else {
                    // If the interval is greater than 0, set a timer to show the full window preview after the specified interval
                    fullPreviewTimer = Timer.scheduledTimer(withTimeInterval: tapEquivalentInterval, repeats: false) { [self] _ in
                        DispatchQueue.main.async {
                            SharedPreviewWindowCoordinator.shared.showWindow(
                                appName: windowInfo.app.localizedName ?? "Unknown",
                                windows: [windowInfo],
                                mouseScreen: bestGuessMonitor,
                                iconRect: nil,
                                overrideDelay: true,
                                centeredHoverWindowState: .fullWindowPreview
                            )
                        }
                    }
                }
            }
        } else {
            // If the hover state is not active or the window switcher is active, invalidate the timer
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

    @ViewBuilder
    private func windowTitleOverlay(selected: Bool) -> some View {
        let shouldShowTitle = showWindowTitle && (
            windowTitleDisplayCondition == .all ||
                (windowTitleDisplayCondition == .dockPreviewsOnly && !windowSwitcherActive) ||
                (windowTitleDisplayCondition == .windowSwitcherOnly && windowSwitcherActive)
        )

        if shouldShowTitle, windowTitleVisibility == .alwaysVisible || selected {
            if let windowTitle = windowInfo.window.title,
               !windowTitle.isEmpty,
               windowTitle != windowInfo.app.localizedName
            {
                let stringMeasurementWidth = measureString(windowTitle, fontSize: 12).width + 5
                let maxLabelWidth = max(dimensions.size.width - 50, 50)
                let width = min(stringMeasurementWidth, maxLabelWidth)
                TheMarquee(width: width, secsBeforeLooping: 1, speedPtsPerSec: 20, nonMovingAlignment: .leading) {
                    Text(windowInfo.windowName ?? "Hidden window")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                .materialPill()
                .padding(4)
            }
        }
    }
}
