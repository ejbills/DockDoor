import Defaults
import SwiftUI

struct SharedHoverAppTitle<Trailing: View>: View {
    let appName: String
    let appIcon: NSImage?
    let hoveringAppIcon: Bool
    let backgroundAppearance: BackgroundAppearance
    private let showTitleOverride: Bool?
    private let styleOverride: AppNameStyle?
    private let showIconOnlyOverride: Bool?
    private let onIconHover: ((Bool) -> Void)?
    private let trailing: Trailing

    @Default(.showAppName) private var showAppTitleDefault
    @Default(.showAppIconOnly) private var showAppIconOnlyDefault
    @Default(.appNameStyle) private var appNameStyleDefault
    @Default(.showAnimations) private var showAnimations

    init(
        appName: String,
        appIcon: NSImage?,
        hoveringAppIcon: Bool,
        backgroundAppearance: BackgroundAppearance,
        showTitle: Bool? = nil,
        styleOverride: AppNameStyle? = nil,
        showIconOnly: Bool? = nil,
        onIconHover: ((Bool) -> Void)? = nil
    ) where Trailing == EmptyView {
        self.init(
            appName: appName,
            appIcon: appIcon,
            hoveringAppIcon: hoveringAppIcon,
            backgroundAppearance: backgroundAppearance,
            showTitle: showTitle,
            styleOverride: styleOverride,
            showIconOnly: showIconOnly,
            onIconHover: onIconHover,
            trailing: { EmptyView() }
        )
    }

    init(
        appName: String,
        appIcon: NSImage?,
        hoveringAppIcon: Bool,
        backgroundAppearance: BackgroundAppearance,
        showTitle: Bool? = nil,
        styleOverride: AppNameStyle? = nil,
        showIconOnly: Bool? = nil,
        onIconHover: ((Bool) -> Void)? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.appName = appName
        self.appIcon = appIcon
        self.hoveringAppIcon = hoveringAppIcon
        self.backgroundAppearance = backgroundAppearance
        showTitleOverride = showTitle
        self.styleOverride = styleOverride
        showIconOnlyOverride = showIconOnly
        self.onIconHover = onIconHover
        self.trailing = trailing()
    }

    var body: some View {
        if effectiveShowTitle {
            Group {
                switch effectiveStyle {
                case .default:
                    defaultHeader
                case .shadowed:
                    shadowedHeader
                case .popover:
                    popoverHeader
                }
            }
            .contentShape(Rectangle())
        }
    }

    private var effectiveShowTitle: Bool { showTitleOverride ?? showAppTitleDefault }
    private var effectiveStyle: AppNameStyle { styleOverride ?? appNameStyleDefault }
    private var effectiveShowIconOnly: Bool { showIconOnlyOverride ?? showAppIconOnlyDefault }

    private var trimmedAppName: String {
        appName.trimmingCharacters(in: .whitespaces)
    }

    private var labelSize: CGSize {
        measureString(
            trimmedAppName,
            fontSize: PreviewTypography.appTitleSize,
            fontWeight: PreviewTypography.appTitleMeasureWeight
        )
    }

    private var labelText: Text {
        Text(trimmedAppName).font(PreviewTypography.appTitle)
    }

    @ViewBuilder
    private var plainLabel: some View {
        Group {
            if trimmedAppName == "DockDoor" {
                FluidGradient(
                    blobs: RainbowPalette.colors,
                    highlights: RainbowPalette.highlights,
                    speed: 0.65,
                    blur: 0.5
                )
                .frame(width: labelSize.width, height: labelSize.height)
                .mask(labelText)
            } else {
                labelText.foregroundStyle(Color.primary)
            }
        }
        .animation(PreviewMotion.content(enabled: showAnimations), value: trimmedAppName)
    }

    @ViewBuilder
    private var shadowedLabel: some View {
        Group {
            if trimmedAppName == "DockDoor" {
                FluidGradient(
                    blobs: RainbowPalette.colors,
                    highlights: RainbowPalette.highlights,
                    speed: 0.65,
                    blur: 0.5
                )
                .frame(width: labelSize.width, height: labelSize.height)
                .mask(labelText)
                .padding(.leading, 4)
            } else {
                labelText.foregroundStyle(Color.primary)
            }
        }
        .shadow(stacked: 2, radius: 6)
        .background(
            ZStack {
                MaterialBlurView(material: .hudWindow)
                    .mask(
                        Ellipse()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.white.opacity(1.0), Color.white.opacity(0.35)]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                    .blur(radius: 5)
            }
            .frame(width: labelSize.width + 30)
        )
        .animation(PreviewMotion.content(enabled: showAnimations), value: trimmedAppName)
    }

    @ViewBuilder
    private var label: some View {
        Group {
            switch effectiveStyle {
            case .shadowed:
                shadowedLabel
            default:
                plainLabel
            }
        }
        .animation(nil, value: hoveringAppIcon)
    }

    private var iconView: some View {
        Group {
            if let appIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .scaledToFit()
                    .zIndex(1)
                    .frame(width: 24, height: 24)
            } else {
                ProgressView()
                    .frame(width: 24, height: 24)
            }
        }
        .animation(PreviewMotion.hover(enabled: showAnimations), value: hoveringAppIcon)
    }

    private var titleAndIcon: some View {
        HStack(spacing: 6) {
            iconView
            if !effectiveShowIconOnly {
                label
            }
        }
        .contentShape(Rectangle())
    }

    private var defaultHeader: some View {
        HStack(alignment: .center) {
            titleAndIcon
            trailing
                .padding(.leading, 4)
        }
        .contentShape(Rectangle())
        .onHover { hover in onIconHover?(hover) }
        .shadow(radius: 2)
        .globalPadding(.top, 12)
        .globalPadding(.leading, 20)
        .animation(PreviewMotion.hover(enabled: showAnimations), value: hoveringAppIcon)
    }

    private var shadowedHeader: some View {
        HStack(spacing: 2) {
            titleAndIcon
            trailing
                .padding(.leading, 4)
        }
        .contentShape(Rectangle())
        .onHover { hover in onIconHover?(hover) }
        .padding(EdgeInsets(top: -11.5, leading: 15, bottom: -1.5, trailing: 1.5))
        .animation(PreviewMotion.hover(enabled: showAnimations), value: hoveringAppIcon)
    }

    private var popoverHeader: some View {
        HStack {
            Spacer()
            HStack(alignment: .center, spacing: 2) {
                HStack(spacing: 6) {
                    iconView
                    if !effectiveShowIconOnly {
                        plainLabel.animation(nil, value: hoveringAppIcon)
                    }
                }
                trailing
                    .padding(.leading, 4)
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .dockStyle(backgroundAppearance: backgroundAppearance, cornerRadius: 10)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .onHover { hover in onIconHover?(hover) }
            Spacer()
        }
        .offset(y: -30)
        .animation(PreviewMotion.hover(enabled: showAnimations), value: hoveringAppIcon)
    }
}

private enum RainbowPalette {
    static let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]
    static let highlights: [Color] = [.white.opacity(0.45), .yellow.opacity(0.35), .pink.opacity(0.4)]
}
