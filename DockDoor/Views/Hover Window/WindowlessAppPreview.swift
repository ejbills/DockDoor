import Defaults
import SwiftUI

struct WindowlessAppPreview: View, Equatable {
    let windowInfo: WindowInfo
    let index: Int
    let dockPosition: DockPosition
    let uniformCardRadius: Bool
    let isSelected: Bool
    let windowSwitcherActive: Bool
    let dimensions: WindowPreviewHoverContainer.WindowDimensions?
    let onTap: (() -> Void)?
    let onHoverIndexChange: ((Int?, CGPoint?) -> Void)?
    var appearance: PreviewAppearanceSettings
    let backgroundAppearance: BackgroundAppearance

    @State private var isHovering = false

    static func == (l: Self, r: Self) -> Bool {
        l.index == r.index && l.isSelected == r.isSelected
            && l.uniformCardRadius == r.uniformCardRadius
            && l.dimensions == r.dimensions
            && l.appearance == r.appearance
            && l.windowInfo.viewSnapshot == r.windowInfo.viewSnapshot
            && l.backgroundAppearance == r.backgroundAppearance
    }

    private var appName: String {
        windowInfo.app.localizedName ?? "Unknown"
    }

    private func titleBar(isLeadingControls: Bool) -> some View {
        let shouldShowSubtitle = appearance.showWindowTitle &&
            (appearance.windowTitleVisibility == .alwaysVisible || isSelected || isHovering)

        return HStack(spacing: 4) {
            if appearance.controlPosition.isCentered {
                Spacer(minLength: 0)
                appIcon
                titleContent(showSubtitle: shouldShowSubtitle)
                Spacer(minLength: 0)
            } else if isLeadingControls {
                Spacer(minLength: 8)
                appIcon
                titleContent(showSubtitle: shouldShowSubtitle)
            } else {
                appIcon
                titleContent(showSubtitle: shouldShowSubtitle)
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private var appIcon: some View {
        if let appIcon = windowInfo.app.icon {
            Image(nsImage: appIcon)
                .resizable()
                .scaledToFit()
                .frame(width: 35, height: 35)
        }
    }

    private func titleContent(showSubtitle: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(appName)
                .foregroundStyle(.primary)
                .lineLimit(1)

            if showSubtitle {
                Text(String(localized: "No Open Windows", comment: "Label for running apps without any open windows in the window switcher"))
                    .font(appearance.windowTitleFontSize.font)
                    .foregroundStyle(.secondary)
                    .italic()
                    .lineLimit(1)
            }
        }
        .padding(.trailing, 8)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if appearance.controlPosition.showsOnTop {
                let config = appearance.controlPosition.topConfiguration
                if config.showTitle {
                    titleBar(isLeadingControls: config.isLeadingControls)
                        .padding(.bottom, 4)
                }
            }

            iconContent
                .clipShape(RoundedRectangle(cornerRadius: CardRadius.image, style: .continuous))
                .dynamicWindowFrame(
                    allowDynamicSizing: false,
                    dimensions: dimensions ?? WindowPreviewHoverContainer.WindowDimensions(size: .zero, maxDimensions: .zero),
                    dockPosition: dockPosition,
                    windowSwitcherActive: windowSwitcherActive
                )
                .opacity(isSelected ? 1.0 : appearance.unselectedContentOpacity)

            if appearance.controlPosition.showsOnBottom {
                let config = appearance.controlPosition.bottomConfiguration
                if config.showTitle {
                    titleBar(isLeadingControls: config.isLeadingControls)
                        .padding(.top, 4)
                }
            }
        }
        .frame(maxWidth: (dimensions?.maxDimensions.width ?? 0) > 0 ? dimensions!.maxDimensions.width : nil)
        .background {
            let cornerRadius = uniformCardRadius ? CardRadius.base + (CardRadius.innerPadding * appearance.globalPaddingMultiplier) : 8.0

            if !appearance.hidePreviewCardBackground {
                BlurView(cornerRadius: cornerRadius, appearance: backgroundAppearance)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .borderedBackground(.primary.opacity(0.1), lineWidth: 1.75, cornerRadius: cornerRadius)
                    .padding(-CardRadius.innerPadding)
                    .overlay {
                        if isSelected || isHovering {
                            let highlightColor = appearance.hoverHighlightColor ?? Color(nsColor: .controlAccentColor)
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(highlightColor.opacity(appearance.selectionOpacity))
                                .padding(-CardRadius.innerPadding)
                        }
                    }
            }
        }
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
        .onTapGesture {
            windowInfo.app.activate(options: [.activateIgnoringOtherApps])
            onTap?()
        }
        .contextMenu {
            Button(role: .destructive, action: {
                if NSEvent.modifierFlags.contains(.option) {
                    windowInfo.app.forceTerminate()
                } else {
                    windowInfo.app.terminate()
                }
            }) {
                if NSEvent.modifierFlags.contains(.option) {
                    Label("Force Quit", systemImage: "power")
                } else {
                    Label("Quit", systemImage: "minus.square.fill")
                }
            }
        }
        .fixedSize()
    }

    @ViewBuilder
    private var iconContent: some View {
        if let appIcon = windowInfo.app.icon {
            Image(nsImage: appIcon)
                .resizable()
                .scaledToFit()
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Color.clear
        }
    }
}
