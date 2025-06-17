
import Defaults
import SwiftUI

struct SharedHoverAppTitle: View {
    let appName: String
    let appIcon: NSImage?
    let hoveringAppIcon: Bool

    @Default(.showAppName) var showAppTitleData
    @Default(.showAppIconOnly) var showAppIconOnly
    @Default(.appNameStyle) var appNameStyle
    @Default(.showAnimations) var showAnimations
    @Default(.gradientColorPalette) private var defaultGradientColorPalette

    var body: some View {
        if showAppTitleData {
            Group {
                switch appNameStyle {
                case .default:
                    HStack(alignment: .center) {
                        if let appIcon {
                            Image(nsImage: appIcon)
                                .resizable()
                                .scaledToFit()
                                .zIndex(1)
                                .frame(width: 24, height: 24)
                        } else { ProgressView().frame(width: 24, height: 24) }
                        hoverTitleLabelView()
                            .animation(nil, value: hoveringAppIcon)
                    }
                    .padding(.top, 10)
                    .padding(.horizontal)
                    .animation(showAnimations ? .smooth(duration: 0.15) : nil, value: hoveringAppIcon)

                case .shadowed:
                    HStack(spacing: 2) {
                        if let appIcon {
                            Image(nsImage: appIcon)
                                .resizable()
                                .scaledToFit()
                                .zIndex(1)
                                .frame(width: 24, height: 24)
                        } else { ProgressView().frame(width: 24, height: 24) }
                        hoverTitleLabelView()
                            .animation(nil, value: hoveringAppIcon)
                    }
                    .padding(EdgeInsets(top: -11.5, leading: 15, bottom: -1.5, trailing: 1.5))
                    .animation(showAnimations ? .smooth(duration: 0.15) : nil, value: hoveringAppIcon)

                case .popover:
                    HStack {
                        Spacer()
                        HStack(alignment: .center, spacing: 2) {
                            if let appIcon {
                                Image(nsImage: appIcon)
                                    .resizable()
                                    .scaledToFit()
                                    .zIndex(1)
                                    .frame(width: 24, height: 24)
                            } else { ProgressView().frame(width: 24, height: 24) }
                            hoverTitleLabelView()
                                .animation(nil, value: hoveringAppIcon)
                        }
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .dockStyle(cornerRadius: 10)
                        Spacer()
                    }
                    .offset(y: -30)
                    .animation(showAnimations ? .smooth(duration: 0.15) : nil, value: hoveringAppIcon)
                }
            }
        }
    }

    @ViewBuilder
    private func hoverTitleLabelView() -> some View {
        if !showAppIconOnly {
            let trimmedAppName = appName.trimmingCharacters(in: .whitespaces)
            let baseText = Text(trimmedAppName).font(.subheadline).fontWeight(.medium)
            let labelSize = measureString(trimmedAppName, fontSize: 14)
            let rainbowGradientColors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]
            let rainbowGradientHighlights: [Color] = [.white.opacity(0.45), .yellow.opacity(0.35), .pink.opacity(0.4)]

            Group {
                switch appNameStyle {
                case .shadowed:
                    if trimmedAppName == "DockDoor" {
                        FluidGradient(blobs: rainbowGradientColors, highlights: rainbowGradientHighlights, speed: 0.65, blur: 0.5)
                            .frame(width: labelSize.width, height: labelSize.height)
                            .mask(baseText)
                            .fontWeight(.medium)
                            .padding(.leading, 4)
                            .shadow(stacked: 2, radius: 6)
                            .background(
                                ZStack {
                                    MaterialBlurView(material: .hudWindow).mask(Ellipse().fill(LinearGradient(gradient: Gradient(colors: [Color.white.opacity(1.0), Color.white.opacity(0.35)]), startPoint: .top, endPoint: .bottom))).blur(radius: 5)
                                }.frame(width: labelSize.width + 30)
                            )
                            .animation(showAnimations ? .easeInOut(duration: 0.2) : nil, value: trimmedAppName)
                    } else {
                        baseText.foregroundStyle(Color.primary).shadow(stacked: 2, radius: 6)
                            .background(
                                ZStack {
                                    MaterialBlurView(material: .hudWindow).mask(Ellipse().fill(LinearGradient(gradient: Gradient(colors: [Color.white.opacity(1.0), Color.white.opacity(0.35)]), startPoint: .top, endPoint: .bottom))).blur(radius: 5)
                                }.frame(width: labelSize.width + 30)
                            )
                            .animation(showAnimations ? .easeInOut(duration: 0.2) : nil, value: trimmedAppName)
                    }
                case .default, .popover:
                    if trimmedAppName == "DockDoor" {
                        FluidGradient(blobs: rainbowGradientColors, highlights: rainbowGradientHighlights, speed: 0.65, blur: 0.5)
                            .frame(width: labelSize.width, height: labelSize.height)
                            .mask(baseText)
                            .animation(showAnimations ? .easeInOut(duration: 0.2) : nil, value: trimmedAppName)
                    } else {
                        baseText.foregroundStyle(Color.primary)
                            .animation(showAnimations ? .easeInOut(duration: 0.2) : nil, value: trimmedAppName)
                    }
                }
            }
        }
    }
}
