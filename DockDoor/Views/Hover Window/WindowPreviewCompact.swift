import Defaults
import SwiftUI

struct WindowPreviewCompact: View, Equatable {
    let windowInfo: WindowInfo
    let index: Int
    let dockPosition: DockPosition
    let uniformCardRadius: Bool
    let handleWindowAction: (WindowAction) -> Void
    let isSelected: Bool
    let windowSwitcherActive: Bool
    let mockPreviewActive: Bool
    let onTap: (() -> Void)?
    let onHoverIndexChange: ((Int?, CGPoint?) -> Void)?
    var appearance: PreviewAppearanceSettings
    let backgroundAppearance: BackgroundAppearance

    @State private var isHovering = false

    static func == (l: Self, r: Self) -> Bool {
        l.index == r.index && l.isSelected == r.isSelected
            && l.uniformCardRadius == r.uniformCardRadius
            && l.windowSwitcherActive == r.windowSwitcherActive
            && l.appearance == r.appearance
            && l.windowInfo.viewSnapshot == r.windowInfo.viewSnapshot
            && l.backgroundAppearance == r.backgroundAppearance
    }

    /// Checks if this window is the currently active (focused) window on the system and adds a border if so.
    private var isActiveWindow: Bool {
        guard appearance.showActiveWindowBorder else { return false }
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
        if windowInfo.isWindowlessApp {
            return String(localized: "No Open Windows", comment: "Label for running apps without any open windows in the window switcher")
        }
        guard appearance.showMinimizedHiddenLabels,
              appearance.trafficLightVisibility != .never
        else { return nil }
        if windowInfo.isMinimized {
            return "Minimized"
        } else if windowInfo.isHidden {
            return "Hidden"
        }
        return nil
    }

    var body: some View {
        HStack(spacing: 10) {
            // App icon
            if let appIcon = windowInfo.app.icon {
                Image(nsImage: appIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: appearance.compactModeItemSize.iconSize, height: appearance.compactModeItemSize.iconSize)
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: appearance.compactModeItemSize.iconSize, height: appearance.compactModeItemSize.iconSize)
                    .foregroundStyle(.secondary)
            }

            // Title content based on format
            VStack(alignment: .leading, spacing: 2) {
                switch appearance.compactModeTitleFormat {
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
            if !appearance.compactModeHideTrafficLights,
               windowInfo.closeButton != nil,
               appearance.trafficLightVisibility != .never,
               !appearance.showMinimizedHiddenLabels || (!windowInfo.isMinimized && !windowInfo.isHidden)
            {
                TrafficLightButtons(
                    displayMode: appearance.trafficLightVisibility,
                    hoveringOverParentWindow: isSelected || isHovering,
                    onWindowAction: handleWindowAction,
                    pillStyling: true,
                    mockPreviewActive: mockPreviewActive,
                    enabledButtons: appearance.enabledTrafficLightButtons,
                    useMonochrome: appearance.useMonochromeTrafficLights,
                    buttonScale: appearance.trafficLightButtonScale,
                    backgroundAppearance: backgroundAppearance
                )
            }
        }
        .padding(.vertical, 8)
        .frame(width: appearance.previewWidth, height: appearance.compactModeItemSize.rowHeight, alignment: .leading)
        .clipped()
        .background {
            let cornerRadius = uniformCardRadius ? CardRadius.base + (CardRadius.innerPadding * appearance.globalPaddingMultiplier) : CardRadius.fallback

            if !appearance.hidePreviewCardBackground {
                BlurView(cornerRadius: cornerRadius, appearance: backgroundAppearance)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .borderedBackground(.primary.opacity(0.1), lineWidth: 1.75, cornerRadius: cornerRadius)
                    .padding(.horizontal, -CardRadius.innerPadding)
                    .overlay {
                        if isSelected || isHovering {
                            let highlightColor = appearance.hoverHighlightColor ?? Color(nsColor: .controlAccentColor)
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(highlightColor.opacity(appearance.selectionOpacity))
                                .padding(.horizontal, -CardRadius.innerPadding)
                        }
                    }
                    .overlay {
                        if isActiveWindow {
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .strokeBorder(appearance.activeAppIndicatorColor, lineWidth: 2.5)
                                .padding(.horizontal, -CardRadius.innerPadding)
                        }
                    }
            }
        }
        .opacity((isSelected || isHovering) ? 1.0 : appearance.unselectedContentOpacity)
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            let setHoverState: (Bool) -> Void = { newState in
                if appearance.showAnimations {
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
        let font = isPrimary ? appearance.compactModeItemSize.primaryFont : appearance.compactModeItemSize.secondaryFont
        if appearance.enableTitleMarquee {
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
            .font(appearance.compactModeItemSize.secondaryFont)
            .foregroundStyle(.secondary)
            .italic()
    }
}
