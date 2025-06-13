import AVKit
import Defaults
import SwiftUI

struct MediaControlsView: View {
    @StateObject private var mediaInfo = MediaInfo()
    let appName: String
    let bundleIdentifier: String
    let dockPosition: DockPosition
    let bestGuessMonitor: NSScreen
    let isEmbeddedMode: Bool

    @Default(.uniformCardRadius) var uniformCardRadius
    @Default(.showAppName) var showAppTitleData
    @Default(.showAppIconOnly) var showAppIconOnly
    @Default(.appNameStyle) var appNameStyle
    @Default(.showAnimations) var showAnimations
    @Default(.gradientColorPalette) private var defaultGradientColorPalette
    @Default(.hasShownEmbeddedControlsToast) var hasShownEmbeddedControlsToast

    @State private var appIcon: NSImage? = nil
    @State private var hoveringAppIcon: Bool = false
    @State private var hoveringWindowTitle: Bool = false
    @State private var isLoadingMediaInfo: Bool = true
    @State private var dominantArtworkColor: Color? = nil
    @State private var showToast: Bool = false

    private enum Layout {
        static let containerSpacing: CGFloat = 8
        static let artworkSize: CGFloat = 55
        static let artworkCornerRadius: CGFloat = 6
        static let artworkTextSpacing: CGFloat = 12
        static let mediaButtonsSpacing: CGFloat = 20
        static let progressBarHeight: CGFloat = 20
        static let skeletonOpacity: Double = 0.25
        static let embeddedArtworkSize: CGFloat = 40
        static let embeddedMediaButtonsSpacing: CGFloat = 15
        static let embeddedProgressBarHeight: CGFloat = 16
    }

    init(appName: String,
         bundleIdentifier: String,
         dockPosition: DockPosition,
         bestGuessMonitor: NSScreen,
         isEmbeddedMode: Bool = false)
    {
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.dockPosition = dockPosition
        self.bestGuessMonitor = bestGuessMonitor
        self.isEmbeddedMode = isEmbeddedMode
    }

    var body: some View {
        Group {
            if isEmbeddedMode {
                embeddedContent()
                    .overlay(alignment: .top) {
                        if showToast, !hasShownEmbeddedControlsToast {
                            EmbeddedControlsToast(
                                appType: "media controls",
                                onDismiss: {
                                    showToast = false
                                    hasShownEmbeddedControlsToast = true
                                }
                            )
                            .padding(.top, 8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
            } else {
                fullContent()
            }
        }
        .onAppear {
            isLoadingMediaInfo = true
            loadAppIcon()
            Task {
                await mediaInfo.fetchMediaInfo(for: bundleIdentifier)
                withAnimation(.smooth(duration: 0.125)) {
                    isLoadingMediaInfo = false
                }
            }
            if let artwork = mediaInfo.artwork {
                dominantArtworkColor = artwork.averageColor()
            }
            if isEmbeddedMode {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        showToast = true
                    }
                }
            }
        }
        .onChange(of: mediaInfo.artwork) { newArtwork in
            if let artwork = newArtwork {
                dominantArtworkColor = artwork.averageColor()
            } else {
                dominantArtworkColor = nil
            }
        }
        .onDisappear {
            mediaInfo.updateTimer?.invalidate()
        }
    }

    @ViewBuilder
    private func embeddedContent() -> some View {
        Group {
            if isLoadingMediaInfo || mediaInfo.title.isEmpty {
                embeddedMediaControlsSkeleton()
            } else {
                VStack(alignment: .center, spacing: 6) {
                    HStack(alignment: .center, spacing: Layout.artworkTextSpacing) {
                        artworkView()
                            .frame(width: Layout.embeddedArtworkSize, height: Layout.embeddedArtworkSize)
                            .clipShape(RoundedRectangle(cornerRadius: Layout.artworkCornerRadius, style: .continuous))

                        VStack(alignment: .leading, spacing: 1) {
                            Text(mediaInfo.title)
                                .font(.callout)
                                .fontWeight(.medium)
                                .lineLimit(1)

                            if !mediaInfo.artist.isEmpty {
                                Text(mediaInfo.artist)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer(minLength: 0)
                    }

                    HStack(spacing: Layout.embeddedMediaButtonsSpacing) {
                        MediaControlButton(systemName: "backward.fill", isTitle: false, action: { mediaInfo.previousTrack() }, buttonDimension: 24)

                        MediaControlButton(systemName: mediaInfo.isPlaying ? "pause.fill" : "play.fill", isTitle: true,
                                           action: {
                                               withAnimation(.easeInOut(duration: 0.2)) {
                                                   mediaInfo.isPlaying.toggle()
                                               }
                                               mediaInfo.playPause()
                                           }, buttonDimension: 28)
                            .animation(.easeInOut(duration: 0.15), value: mediaInfo.isPlaying)

                        MediaControlButton(systemName: "forward.fill", isTitle: false, action: { mediaInfo.nextTrack() }, buttonDimension: 24)
                    }
                }
                .padding(12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: uniformCardRadius ? 12 : 0, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: uniformCardRadius ? 12 : 0, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func embeddedMediaControlsSkeleton() -> some View {
        VStack(spacing: 6) {
            HStack(alignment: .center, spacing: Layout.artworkTextSpacing) {
                RoundedRectangle(cornerRadius: Layout.artworkCornerRadius, style: .continuous)
                    .fill(Color.primary.opacity(Layout.skeletonOpacity))
                    .frame(width: Layout.embeddedArtworkSize, height: Layout.embeddedArtworkSize)

                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(Layout.skeletonOpacity))
                        .frame(width: 100, height: 13)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(Layout.skeletonOpacity))
                        .frame(width: 70, height: 11)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: Layout.embeddedMediaButtonsSpacing) {
                ForEach(0 ..< 3, id: \.self) { index in
                    Circle()
                        .fill(Color.primary.opacity(Layout.skeletonOpacity))
                        .frame(width: index == 1 ? 28 : 24, height: index == 1 ? 28 : 24)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: uniformCardRadius ? 12 : 0, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: uniformCardRadius ? 12 : 0, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .glintPlaceholder()
    }

    @ViewBuilder
    private func fullContent() -> some View {
        BaseHoverContainer(
            bestGuessMonitor: bestGuessMonitor,
            mockPreviewActive: false,
            content: {
                VStack(spacing: 0) {
                    mediaControlsContent()
                        .padding(20)
                }
                .padding(.top, (appNameStyle == .default && showAppTitleData) ? 25 : 0)
                .overlay(alignment: .topLeading) {
                    hoverTitleBaseView(labelSize: measureString(appName, fontSize: 14))
                        .onHover { isHovered in
                            withAnimation(.snappy) { hoveringWindowTitle = isHovered }
                        }
                }
                .padding(.top, (appNameStyle == .popover && showAppTitleData) ? 30 : 0)
                .overlay {
                    WindowDismissalContainer(appName: appName,
                                             bestGuessMonitor: bestGuessMonitor,
                                             dockPosition: dockPosition,
                                             minimizeAllWindowsCallback: {})
                        .allowsHitTesting(false)
                }
            },
            highlightColor: dominantArtworkColor
        )
    }

    @ViewBuilder
    private func mediaControlsContent() -> some View {
        Group {
            if isLoadingMediaInfo || mediaInfo.title.isEmpty {
                mediaControlsSkeleton()
            } else {
                VStack(alignment: .center, spacing: Layout.containerSpacing) {
                    HStack(alignment: .center, spacing: Layout.artworkTextSpacing) {
                        artworkView()
                            .frame(width: Layout.artworkSize, height: Layout.artworkSize)
                            .clipShape(RoundedRectangle(cornerRadius: Layout.artworkCornerRadius, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(mediaInfo.title)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                                .animation(.easeInOut(duration: 0.2), value: mediaInfo.title)

                            if !mediaInfo.artist.isEmpty {
                                Text(mediaInfo.artist)
                                    .lineLimit(1)
                                    .animation(.easeInOut(duration: 0.2), value: mediaInfo.artist)
                            }
                        }
                        Spacer(minLength: 0)
                    }

                    HStack(alignment: .center, spacing: 8) {
                        Text(formatTime(mediaInfo.currentTime))

                        SimpleProgressBar(
                            value: Binding(
                                get: { mediaInfo.currentTime },
                                set: { newValue in
                                    mediaInfo.seek(to: newValue)
                                }
                            ),
                            range: 0 ... max(mediaInfo.duration, 1),
                            barColor: .primary.opacity(0.8),
                            backgroundColor: .secondary.opacity(0.8)
                        )
                        .frame(height: Layout.progressBarHeight)

                        Text("-\(formatTime(max(0, mediaInfo.duration - mediaInfo.currentTime)))")
                    }
                    .font(.caption)
                    .monospacedDigit()

                    HStack(spacing: Layout.mediaButtonsSpacing) {
                        MediaControlButton(systemName: "backward.fill", isTitle: false, action: { mediaInfo.previousTrack() })
                        MediaControlButton(systemName: "gobackward.15", isTitle: true, action: {
                            let newTime = max(0, mediaInfo.currentTime - 15)
                            mediaInfo.seek(to: newTime)
                        })

                        MediaControlButton(systemName: mediaInfo.isPlaying ? "pause.fill" : "play.fill", isTitle: true,
                                           action: {
                                               withAnimation(.easeInOut(duration: 0.2)) {
                                                   mediaInfo.isPlaying.toggle()
                                               }
                                               mediaInfo.playPause()
                                           })
                                           .animation(.easeInOut(duration: 0.15), value: mediaInfo.isPlaying)

                        MediaControlButton(systemName: "goforward.15", isTitle: true, action: {
                            let newTime = min(mediaInfo.duration, mediaInfo.currentTime + 15)
                            mediaInfo.seek(to: newTime)
                        })
                        MediaControlButton(systemName: "forward.fill", isTitle: false, action: { mediaInfo.nextTrack() })
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func mediaControlsSkeleton() -> some View {
        VStack(spacing: Layout.containerSpacing) {
            HStack(alignment: .center, spacing: Layout.artworkTextSpacing) {
                RoundedRectangle(cornerRadius: Layout.artworkCornerRadius, style: .continuous)
                    .fill(Color.primary.opacity(Layout.skeletonOpacity))
                    .frame(width: Layout.artworkSize, height: Layout.artworkSize)

                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(Layout.skeletonOpacity))
                        .frame(width: 120, height: 16)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(Layout.skeletonOpacity))
                        .frame(width: 80, height: 14)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.primary.opacity(Layout.skeletonOpacity))
                    .frame(width: 35, height: 12)

                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.primary.opacity(Layout.skeletonOpacity))
                    .frame(height: Layout.progressBarHeight)
                    .frame(maxWidth: .infinity)

                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.primary.opacity(Layout.skeletonOpacity))
                    .frame(width: 35, height: 12)
            }
            .font(.caption)

            HStack(spacing: Layout.mediaButtonsSpacing) {
                Spacer()
                ForEach(0 ..< 5, id: \.self) { _ in
                    Circle()
                        .fill(Color.primary.opacity(Layout.skeletonOpacity))
                        .frame(width: 28, height: 28)
                }
                Spacer()
            }
        }
        .glintPlaceholder()
    }

    @ViewBuilder
    private func artworkView() -> some View {
        ZStack {
            if let artwork = mediaInfo.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: Layout.artworkCornerRadius)
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.title2)
                    )
            }
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let seconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, abs(seconds))
    }

    @ViewBuilder
    private func hoverTitleBaseView(labelSize: CGSize) -> some View {
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
                        hoverTitleLabelView(labelSize: labelSize)
                            .animation(nil, value: hoveringAppIcon)
                    }
                    .padding(.top, 10)
                    .padding(.horizontal)
                    .animation(.smooth(duration: 0.15), value: hoveringAppIcon)

                case .shadowed:
                    HStack(spacing: 2) {
                        if let appIcon {
                            Image(nsImage: appIcon)
                                .resizable()
                                .scaledToFit()
                                .zIndex(1)
                                .frame(width: 24, height: 24)
                        } else { ProgressView().frame(width: 24, height: 24) }
                        hoverTitleLabelView(labelSize: labelSize)
                            .animation(nil, value: hoveringAppIcon)
                    }
                    .padding(EdgeInsets(top: -11.5, leading: 15, bottom: -1.5, trailing: 1.5))
                    .animation(.smooth(duration: 0.15), value: hoveringAppIcon)

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
                            hoverTitleLabelView(labelSize: labelSize)
                                .animation(nil, value: hoveringAppIcon)
                        }
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .dockStyle(cornerRadius: 10)
                        Spacer()
                    }
                    .offset(y: -30)
                    .animation(.smooth(duration: 0.15), value: hoveringAppIcon)
                }
            }
            .onHover { hover in
                hoveringAppIcon = hover
            }
        }
    }

    @ViewBuilder
    private func hoverTitleLabelView(labelSize: CGSize) -> some View {
        if !showAppIconOnly {
            let trimmedAppName = appName.trimmingCharacters(in: .whitespaces)
            let baseText = Text(trimmedAppName).font(.subheadline).fontWeight(.medium)
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
                            .animation(.easeInOut(duration: 0.2), value: trimmedAppName)
                    } else {
                        baseText.foregroundStyle(Color.primary).shadow(stacked: 2, radius: 6)
                            .background(
                                ZStack {
                                    MaterialBlurView(material: .hudWindow).mask(Ellipse().fill(LinearGradient(gradient: Gradient(colors: [Color.white.opacity(1.0), Color.white.opacity(0.35)]), startPoint: .top, endPoint: .bottom))).blur(radius: 5)
                                }.frame(width: labelSize.width + 30)
                            )
                            .animation(.easeInOut(duration: 0.2), value: trimmedAppName)
                    }
                case .default, .popover:
                    if trimmedAppName == "DockDoor" {
                        FluidGradient(blobs: rainbowGradientColors, highlights: rainbowGradientHighlights, speed: 0.65, blur: 0.5)
                            .frame(width: labelSize.width, height: labelSize.height)
                            .mask(baseText)
                            .animation(.easeInOut(duration: 0.2), value: trimmedAppName)
                    } else {
                        baseText.foregroundStyle(Color.primary)
                            .animation(.easeInOut(duration: 0.2), value: trimmedAppName)
                    }
                }
            }
        }
    }

    private func loadAppIcon() {
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first, let icon = app.icon {
            DispatchQueue.main.async {
                if appIcon != icon { appIcon = icon }
            }
        } else if appIcon != nil {
            DispatchQueue.main.async { appIcon = nil }
        }
    }

    private func measureString(_ string: String, fontSize: CGFloat) -> CGSize {
        let font = NSFont.systemFont(ofSize: fontSize)
        let attributes = [NSAttributedString.Key.font: font]
        let size = (string as NSString).size(withAttributes: attributes)
        return size
    }
}

struct MediaControlButton: View {
    let systemName: String
    let isTitle: Bool
    let action: () -> Void
    var buttonDimension: CGFloat = 28

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .symbolRenderingMode(.hierarchical)
                .font(isTitle ? .body : .caption)
                .fontWeight(.semibold)
                .frame(width: buttonDimension, height: buttonDimension)
                .contentShape(Circle())
                .symbolReplaceTransition()
        }
        .buttonStyle(.plain)
        .background(
            Circle()
                .fill(Color.primary.opacity(isHovering ? 0.12 : 0))
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.10)) { isHovering = hovering }
        }
    }
}

private extension View {
    @ViewBuilder
    func symbolReplaceTransition() -> some View {
        if #available(macOS 14.0, *) {
            self.contentTransition(.symbolEffect(.replace))
        } else {
            self
        }
    }
}
