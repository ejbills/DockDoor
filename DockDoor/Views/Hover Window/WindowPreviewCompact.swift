import Defaults
import SwiftUI

struct WindowPreviewCompact: View {
    let windowInfo: WindowInfo
    let index: Int
    let dockPosition: DockPosition
    let uniformCardRadius: Bool
    let handleWindowAction: (WindowAction) -> Void
    let currIndex: Int
    let windowSwitcherActive: Bool
    let mockPreviewActive: Bool
    let onTap: (() -> Void)?
    let onHoverIndexChange: ((Int?, CGPoint?) -> Void)?

    @Default(.previewWidth) private var previewWidth
    @Default(.compactModeTitleFormat) private var titleFormat
    @Default(.compactModeItemSize) private var itemSize

    // MARK: - Dock Preview Appearance Settings

    @Default(.trafficLightButtonsVisibility) private var trafficLightButtonsVisibility
    @Default(.enabledTrafficLightButtons) private var enabledTrafficLightButtons
    @Default(.useMonochromeTrafficLights) private var useMonochromeTrafficLights

    // MARK: - Window Switcher Appearance Settings

    @Default(.switcherTrafficLightButtonsVisibility) private var switcherTrafficLightButtonsVisibility
    @Default(.switcherEnabledTrafficLightButtons) private var switcherEnabledTrafficLightButtons
    @Default(.switcherUseMonochromeTrafficLights) private var switcherUseMonochromeTrafficLights

    // MARK: - Cmd+Tab Appearance Settings

    @Default(.cmdTabTrafficLightButtonsVisibility) private var cmdTabTrafficLightButtonsVisibility
    @Default(.cmdTabEnabledTrafficLightButtons) private var cmdTabEnabledTrafficLightButtons
    @Default(.cmdTabUseMonochromeTrafficLights) private var cmdTabUseMonochromeTrafficLights

    @Default(.selectionOpacity) private var selectionOpacity
    @Default(.unselectedContentOpacity) private var unselectedContentOpacity
    @Default(.hoverHighlightColor) private var hoverHighlightColor
    @Default(.showMinimizedHiddenLabels) private var showMinimizedHiddenLabels
    @Default(.hidePreviewCardBackground) private var hidePreviewCardBackground
    @Default(.enableTitleMarquee) private var enableTitleMarquee
    @Default(.showAnimations) private var showAnimations
    @Default(.showActiveWindowBorder) private var showActiveWindowBorder
    @Default(.activeAppIndicatorColor) private var activeAppIndicatorColor
    @Default(.globalPaddingMultiplier) private var globalPaddingMultiplier

    @State private var isHovering = false

    private var isSelected: Bool {
        index == currIndex
    }

    /// Checks if this window is the currently active (focused) window on the system and adds a border if so.
    private var isActiveWindow: Bool {
        guard showActiveWindowBorder else { return false }
        guard windowInfo.app.isActive else { return false }
        guard let focusedWindow = try? windowInfo.appAxElement.focusedWindow(),
              let focusedWindowID = try? focusedWindow.cgWindowId()
        else { return false }
        return windowInfo.id == focusedWindowID
    }

    private var appName: String {
        windowInfo.app.localizedName ?? "Unknown"
    }

    private var windowTitle: String? {
        let title = windowInfo.windowName ?? ""
        if title.isEmpty || title == appName {
            return nil
        }
        return title
    }

    private var stateIndicator: String? {
        guard showMinimizedHiddenLabels else { return nil }
        if windowInfo.isMinimized {
            return "Minimized"
        } else if windowInfo.isHidden {
            return "Hidden"
        }
        return nil
    }

    // MARK: - Context-based appearance settings

    private var effectiveTrafficLightVisibility: TrafficLightButtonsVisibility {
        if windowSwitcherActive {
            switcherTrafficLightButtonsVisibility
        } else if dockPosition == .cmdTab {
            cmdTabTrafficLightButtonsVisibility
        } else {
            trafficLightButtonsVisibility
        }
    }

    private var effectiveEnabledTrafficLightButtons: Set<WindowAction> {
        if windowSwitcherActive {
            switcherEnabledTrafficLightButtons
        } else if dockPosition == .cmdTab {
            cmdTabEnabledTrafficLightButtons
        } else {
            enabledTrafficLightButtons
        }
    }

    private var effectiveUseMonochromeTrafficLights: Bool {
        if windowSwitcherActive {
            switcherUseMonochromeTrafficLights
        } else if dockPosition == .cmdTab {
            cmdTabUseMonochromeTrafficLights
        } else {
            useMonochromeTrafficLights
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            // App icon
            if let appIcon = windowInfo.app.icon {
                Image(nsImage: appIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: itemSize.iconSize, height: itemSize.iconSize)
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: itemSize.iconSize, height: itemSize.iconSize)
                    .foregroundStyle(.secondary)
            }

            // Title content based on format
            VStack(alignment: .leading, spacing: 2) {
                switch titleFormat {
                case .appNameAndTitle:
                    titleText(appName, isPrimary: true)
                    // Show state instead of window title when minimized/hidden
                    if let state = stateIndicator {
                        stateText(state)
                    } else if let title = windowTitle {
                        titleText(title, isPrimary: false)
                    }

                case .titleOnly:
                    titleText(windowTitle ?? appName, isPrimary: true)
                    // Show state below the title
                    if let state = stateIndicator {
                        stateText(state)
                    }

                case .appNameOnly:
                    titleText(appName, isPrimary: true)
                    // Show state below app name
                    if let state = stateIndicator {
                        stateText(state)
                    }
                }
            }

            Spacer(minLength: 0)

            // Traffic light buttons
            if windowInfo.closeButton != nil,
               effectiveTrafficLightVisibility != .never,
               !showMinimizedHiddenLabels || (!windowInfo.isMinimized && !windowInfo.isHidden)
            {
                TrafficLightButtons(
                    displayMode: effectiveTrafficLightVisibility,
                    hoveringOverParentWindow: isSelected || isHovering,
                    onWindowAction: handleWindowAction,
                    pillStyling: true,
                    mockPreviewActive: mockPreviewActive,
                    enabledButtons: effectiveEnabledTrafficLightButtons,
                    useMonochrome: effectiveUseMonochromeTrafficLights
                )
            }
        }
        .padding(.vertical, 8)
        .frame(width: previewWidth, height: itemSize.rowHeight, alignment: .leading)
        .clipped()
        .background {
            let cornerRadius = uniformCardRadius ? CardRadius.base + (CardRadius.innerPadding * globalPaddingMultiplier) : CardRadius.fallback

            if !hidePreviewCardBackground {
                BlurView(variant: 18)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .borderedBackground(.primary.opacity(0.1), lineWidth: 1.75, cornerRadius: cornerRadius)
                    .padding(.horizontal, -CardRadius.innerPadding)
                    .overlay {
                        if isSelected || isHovering {
                            let highlightColor = hoverHighlightColor ?? Color(nsColor: .controlAccentColor)
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(highlightColor.opacity(selectionOpacity))
                                .padding(.horizontal, -CardRadius.innerPadding)
                        }
                    }
                    .overlay {
                        if isActiveWindow {
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .strokeBorder(activeAppIndicatorColor, lineWidth: 2.5)
                                .padding(.horizontal, -CardRadius.innerPadding)
                        }
                    }
            }
        }
        .opacity((isSelected || isHovering) ? 1.0 : unselectedContentOpacity)
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            let setHoverState: (Bool) -> Void = { newState in
                if showAnimations {
                    withAnimation(.snappy(duration: 0.175)) { isHovering = newState }
                } else {
                    isHovering = newState
                }
            }

            switch phase {
            case let .active(location):
                if !isHovering { setHoverState(true) }
                if windowSwitcherActive { onHoverIndexChange?(index, location) }
            case .ended:
                if windowSwitcherActive { onHoverIndexChange?(nil, nil) }
                if isHovering { setHoverState(false) }
            }
        }
        .windowPreviewInteractions(
            windowInfo: windowInfo,
            windowSwitcherActive: windowSwitcherActive,
            dockPosition: dockPosition,
            useCompactMode: true,
            handleWindowAction: handleWindowAction,
            onTap: onTap
        )
    }

    @ViewBuilder
    private func titleText(_ text: String, isPrimary: Bool) -> some View {
        let font = isPrimary ? itemSize.primaryFont : itemSize.secondaryFont
        if enableTitleMarquee {
            MarqueeText(text: text, startDelay: 1)
                .font(font)
                .foregroundStyle(isPrimary ? .primary : .secondary)
        } else {
            Text(text)
                .font(font)
                .foregroundStyle(isPrimary ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    @ViewBuilder
    private func stateText(_ text: String) -> some View {
        Text(text)
            .font(itemSize.secondaryFont)
            .foregroundStyle(.secondary)
            .italic()
    }
}
