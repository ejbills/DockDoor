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
    var currIndex: Int
    var windowSwitcherActive: Bool

    @Default(.windowTitlePosition) var windowTitlePosition
    @Default(.showWindowTitle) var showWindowTitle
    @Default(.windowTitleDisplayCondition) var windowTitleDisplayCondition
    @Default(.windowTitleVisibility) var windowTitleVisibility
    @Default(.trafficLightButtonsVisibility) var trafficLightButtonsVisibility
    @Default(.trafficLightButtonsPosition) var trafficLightButtonsPosition

    // preview popup action handlers
    @Default(.tapEquivalentInterval) var tapEquivalentInterval
    @Default(.previewHoverAction) var previewHoverAction

    @State private var isHoveringOverDockPeekPreview = false
    @State private var isHoveringOverWindowSwitcherPreview = false
    @State private var fullPreviewTimer: Timer?

    private var calculatedMaxDimensions: CGSize {
        CGSize(width: bestGuessMonitor.frame.width * 0.75, height: bestGuessMonitor.frame.height * 0.75)
    }

    var calculatedSize: CGSize {
        guard let cgImage = windowInfo.image else { return .zero }

        let cgSize = CGSize(width: cgImage.width, height: cgImage.height)
        let aspectRatio = cgSize.width / cgSize.height
        let maxAllowedWidth = maxWindowDimension.x
        let maxAllowedHeight = maxWindowDimension.y

        var targetWidth = maxAllowedWidth
        var targetHeight = targetWidth / aspectRatio

        if targetHeight > maxAllowedHeight {
            targetHeight = maxAllowedHeight
            targetWidth = aspectRatio * targetHeight
        }

        return CGSize(width: targetWidth, height: targetHeight)
    }

    private func windowContent(isMinimized: Bool, isHidden: Bool, isSelected: Bool) -> some View {
        Group {
            if let cgImage = windowInfo.image {
                Image(decorative: cgImage, scale: 1.0)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .markHidden(isHidden: isMinimized || isHidden)
                    .overlay(isSelected ? CustomizableFluidGradientView().opacity(0.125) : nil)
            }
        }
        .frame(width: calculatedSize.width, height: calculatedSize.height, alignment: .center)
        .frame(maxWidth: calculatedMaxDimensions.width, maxHeight: calculatedMaxDimensions.height)
    }

    var body: some View {
        let isHighlightedInWindowSwitcher = (index == currIndex && windowSwitcherActive)
        let selected = isHoveringOverDockPeekPreview || isHighlightedInWindowSwitcher

        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                windowContent(isMinimized: windowInfo.isMinimized, isHidden: windowInfo.isHidden, isSelected: selected)
                    .overlay { Color.white.opacity(isHoveringOverWindowSwitcherPreview ? 0.1 : 0) }
                    .shadow(radius: selected || isHoveringOverWindowSwitcherPreview ? 0 : 3)
                    .background {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.clear.shadow(.drop(color: .black.opacity(selected ? 0.35 : 0.25), radius: selected ? 12 : 8, y: selected ? 6 : 4)))
                    }
                    .clipShape(uniformCardRadius ? AnyShape(RoundedRectangle(cornerRadius: 6, style: .continuous)) : AnyShape(Rectangle()))
            }
            .overlay(alignment: {
                switch windowTitlePosition {
                case .bottomLeft:
                    .bottomLeading
                case .bottomRight:
                    .bottomTrailing
                case .topRight:
                    .topTrailing
                case .topLeft:
                    .topLeading
                }
            }()) {
                if showWindowTitle, windowTitleDisplayCondition == .all || (windowTitleDisplayCondition == .windowSwitcherOnly && windowSwitcherActive) || (windowTitleDisplayCondition == .dockPreviewsOnly && !windowSwitcherActive) {
                    windowTitleOverlay(selected: selected)
                }
            }
            .overlay(alignment: {
                switch trafficLightButtonsPosition {
                case .bottomLeft:
                    .bottomLeading
                case .bottomRight:
                    .bottomTrailing
                case .topRight:
                    .topTrailing
                case .topLeft:
                    .topLeading
                }
            }()) {
                if !windowInfo.isMinimized, !windowInfo.isHidden, let _ = windowInfo.closeButton {
                    TrafficLightButtons(windowInfo: windowInfo,
                                        displayMode: trafficLightButtonsVisibility,
                                        hoveringOverParentWindow: selected || isHoveringOverWindowSwitcherPreview,
                                        onAction: { onTap?() })
                }
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .scaleEffect(selected ? 1.015 : 1)
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
            WindowUtil.toggleMinimize(windowInfo: windowInfo)
        } else if windowInfo.isHidden {
            WindowUtil.toggleHidden(windowInfo: windowInfo)
        } else {
            WindowUtil.bringWindowToFront(windowInfo: windowInfo)
        }
        onTap?()
    }

    @ViewBuilder
    private func windowTitleOverlay(selected: Bool) -> some View {
        if windowTitleVisibility == .alwaysVisible || selected, let windowTitle = windowInfo.window.title, !windowTitle.isEmpty, windowTitle != windowInfo.app.localizedName || windowSwitcherActive {
            let maxLabelWidth = calculatedSize.width - 50
            let stringMeasurementWidth = measureString(windowTitle, fontSize: 12).width + 5
            let width = maxLabelWidth > stringMeasurementWidth ? stringMeasurementWidth : maxLabelWidth

            TheMarquee(width: width, secsBeforeLooping: 1, speedPtsPerSec: 20, nonMovingAlignment: .leading) {
                Text(windowInfo.windowName ?? "Hidden window")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .padding(4)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(.ultraThinMaterial))
            .padding(4)
        }
    }
}
