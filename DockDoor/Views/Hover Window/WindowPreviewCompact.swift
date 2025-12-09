import Defaults
import SwiftUI

struct WindowPreviewCompact: View {
    let windowInfo: WindowInfo
    let index: Int
    let uniformCardRadius: Bool
    let handleWindowAction: (WindowAction) -> Void
    let currIndex: Int
    let windowSwitcherActive: Bool
    let mockPreviewActive: Bool
    let onTap: (() -> Void)?
    let onHoverIndexChange: ((Int?) -> Void)?

    @Default(.previewWidth) private var previewWidth
    @Default(.compactModeTitleFormat) private var titleFormat
    @Default(.trafficLightButtonsVisibility) private var trafficLightButtonsVisibility
    @Default(.selectionOpacity) private var selectionOpacity
    @Default(.unselectedContentOpacity) private var unselectedContentOpacity
    @Default(.hoverHighlightColor) private var hoverHighlightColor
    @Default(.showMinimizedHiddenLabels) private var showMinimizedHiddenLabels
    @Default(.hidePreviewCardBackground) private var hidePreviewCardBackground
    @Default(.enableTitleMarquee) private var enableTitleMarquee

    @State private var isHovering = false

    private var isSelected: Bool {
        isHovering || index == currIndex
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
                    .frame(width: 32, height: 32)
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .foregroundStyle(.secondary)
            }

            // Title content based on format
            VStack(alignment: .leading, spacing: 2) {
                switch titleFormat {
                case .appNameAndTitle:
                    titleText(appName, isPrimary: true)
                    if let title = windowTitle {
                        titleText(title, isPrimary: false)
                    } else if showMinimizedHiddenLabels, let state = stateIndicator {
                        stateText(state)
                    }

                case .titleOnly:
                    titleText(windowTitle ?? appName, isPrimary: true)
                    if showMinimizedHiddenLabels, let state = stateIndicator {
                        stateText(state)
                    }

                case .appNameOnly:
                    titleText(appName, isPrimary: true)
                    if showMinimizedHiddenLabels, let state = stateIndicator {
                        stateText(state)
                    }
                }
            }

            Spacer(minLength: 0)

            // Traffic light buttons
            if windowInfo.closeButton != nil,
               trafficLightButtonsVisibility != .never,
               !showMinimizedHiddenLabels || (!windowInfo.isMinimized && !windowInfo.isHidden)
            {
                TrafficLightButtons(
                    displayMode: trafficLightButtonsVisibility,
                    hoveringOverParentWindow: isSelected,
                    onWindowAction: handleWindowAction,
                    pillStyling: true,
                    mockPreviewActive: mockPreviewActive
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(width: previewWidth, height: 48, alignment: .leading)
        .clipped()
        .background {
            let cornerRadius = uniformCardRadius ? 12.0 : 4.0

            if !hidePreviewCardBackground {
                BlurView(variant: 18)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .overlay {
                        if isSelected {
                            let highlightColor = hoverHighlightColor ?? Color(nsColor: .controlAccentColor)
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(highlightColor.opacity(selectionOpacity))
                        }
                    }
            }
        }
        .opacity(isSelected ? 1.0 : unselectedContentOpacity)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.snappy(duration: 0.175)) {
                isHovering = hovering
                if windowSwitcherActive {
                    onHoverIndexChange?(hovering ? index : nil)
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
                        Label("Force Quit", systemImage: "power")
                    } else {
                        Label("Quit", systemImage: "minus.square.fill")
                    }
                }
            }
        }
        .onMiddleClick {
            if windowInfo.closeButton != nil {
                handleWindowAction(.close)
            }
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

    @ViewBuilder
    private func titleText(_ text: String, isPrimary: Bool) -> some View {
        if enableTitleMarquee {
            MarqueeText(text: text, startDelay: 1)
                .font(.system(size: isPrimary ? 13 : 11, weight: isPrimary ? .medium : .regular))
                .foregroundStyle(isPrimary ? .primary : .secondary)
        } else {
            Text(text)
                .font(.system(size: isPrimary ? 13 : 11, weight: isPrimary ? .medium : .regular))
                .foregroundStyle(isPrimary ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    @ViewBuilder
    private func stateText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .italic()
    }
}
