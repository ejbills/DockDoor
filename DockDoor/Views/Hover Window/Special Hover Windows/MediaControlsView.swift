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
    let isPinnedMode: Bool

    @Default(.uniformCardRadius) var uniformCardRadius
    @Default(.showAppName) var showAppTitleData
    @Default(.showAppIconOnly) var showAppIconOnly
    @Default(.appNameStyle) var appNameStyle
    @Default(.showAnimations) var showAnimations
    @Default(.gradientColorPalette) private var defaultGradientColorPalette

    @State private var appIcon: NSImage? = nil
    @State private var hoveringAppIcon: Bool = false
    @State private var hoveringWindowTitle: Bool = false
    @State private var isLoadingMediaInfo: Bool = true
    @State private var dominantArtworkColor: Color? = nil
    @State private var capturedEmbeddedWidth: CGFloat? = nil

    @State private var isArtworkExpanded: Bool = false
    @Namespace private var artworkExpansionNamespace

    @State private var isArtworkExpandedFull: Bool = false
    @Namespace private var artworkExpansionFullNamespace

    @State private var artworkRotation: Double = 0.0

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

        static let expandedArtworkSize: CGFloat = 200
        static let expandedArtworkCornerRadius: CGFloat = 8
        static let expandedMediaButtonsSpacing: CGFloat = 25
        static let expandedPlayButtonDimension: CGFloat = 36
        static let expandedOtherButtonDimension: CGFloat = 28

        static let fullExpandedArtworkSize: CGFloat = 150
        static let fullExpandedArtworkCornerRadius: CGFloat = 12
        static let fullExpandedTitleFontSize: CGFloat = 18
        static let fullExpandedArtistFontSize: CGFloat = 15
        static let fullExpandedContainerSpacing: CGFloat = 12
        static let fullExpandedMediaButtonsSpacing: CGFloat = 22
        static let fullExpandedPlayButtonDimension: CGFloat = 34
        static let fullExpandedOtherButtonDimension: CGFloat = 26
    }

    init(appName: String,
         bundleIdentifier: String,
         dockPosition: DockPosition,
         bestGuessMonitor: NSScreen,
         isEmbeddedMode: Bool = false,
         isPinnedMode: Bool = false)
    {
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.dockPosition = dockPosition
        self.bestGuessMonitor = bestGuessMonitor
        self.isEmbeddedMode = isEmbeddedMode
        self.isPinnedMode = isPinnedMode
    }

    var body: some View {
        Group {
            if isEmbeddedMode {
                embeddedContent()
            } else {
                fullContent()
            }
        }
        .onAppear {
            isLoadingMediaInfo = true
            loadAppIcon()
            Task {
                await mediaInfo.fetchMediaInfo(for: bundleIdentifier)
                withAnimation(showAnimations ? .smooth(duration: 0.225) : nil) {
                    isLoadingMediaInfo = false
                }
            }
            if let artwork = mediaInfo.artwork {
                dominantArtworkColor = artwork.averageColor()
            }
        }
        .onChange(of: mediaInfo.artwork) { newArtwork in
            if let artwork = newArtwork {
                dominantArtworkColor = artwork.averageColor()
            } else {
                dominantArtworkColor = nil
            }
        }
        .onChange(of: mediaInfo.title) { _ in
            if !mediaInfo.title.isEmpty {
                withAnimation(showAnimations ? .smooth(duration: 0.3) : nil) {
                    artworkRotation += 360
                }
            }
        }
        .onDisappear {
            mediaInfo.updateTimer?.invalidate()
        }
    }

    @ViewBuilder
    private func embeddedContent() -> some View {
        Group {
            if isArtworkExpanded {
                expandedEmbeddedDisplayCore()
                    .globalPadding(20)
            } else {
                compactEmbeddedDisplayCore()
            }
        }
        .frame(width: isArtworkExpanded ? 280 : 250)
        .frame(height: isArtworkExpanded ? 380 : nil)
        .dockStyle()
        .animation(showAnimations ? .spring(response: 0.45, dampingFraction: 0.8) : nil, value: isArtworkExpanded)
        .animation(showAnimations ? .smooth(duration: 0.125) : nil, value: isLoadingMediaInfo)
    }

    @ViewBuilder
    private func compactEmbeddedDisplayCore() -> some View {
        if isLoadingMediaInfo || mediaInfo.title.isEmpty {
            embeddedMediaControlsSkeleton()
        } else {
            VStack(alignment: .center, spacing: 6) {
                HStack(alignment: .center, spacing: Layout.artworkTextSpacing) {
                    artworkView(
                        size: CGSize(width: Layout.embeddedArtworkSize, height: Layout.embeddedArtworkSize),
                        cornerRadius: Layout.artworkCornerRadius
                    )
                    .onTapGesture {
                        withAnimation(showAnimations ? .spring(response: 0.45, dampingFraction: 0.8) : nil) {
                            isArtworkExpanded = true
                        }
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        MarqueeText(
                            text: mediaInfo.title,
                            fontSize: 16,
                            startDelay: 1,
                            maxWidth: 165
                        )
                        .font(.callout)
                        .fontWeight(.medium)
                        .id("compact-title-\(mediaInfo.title)")
                        .matchedGeometryEffect(id: "mediaTitle", in: artworkExpansionNamespace)

                        if !mediaInfo.artist.isEmpty {
                            MarqueeText(
                                text: mediaInfo.artist,
                                fontSize: 12,
                                startDelay: 1,
                                maxWidth: 150
                            )
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .id("compact-artist-\(mediaInfo.artist)")
                            .matchedGeometryEffect(id: "mediaArtist", in: artworkExpansionNamespace)
                        }
                    }
                    Spacer(minLength: 0)
                }

                HStack(spacing: Layout.embeddedMediaButtonsSpacing) {
                    MediaControlButton(systemName: "backward.fill", isTitle: false, action: { mediaInfo.previousTrack() }, buttonDimension: 24)

                    MediaControlButton(systemName: mediaInfo.isPlaying ? "pause.fill" : "play.fill", isTitle: true,
                                       action: {
                                           withAnimation(showAnimations ? .easeInOut(duration: 0.2) : nil) {
                                               mediaInfo.isPlaying.toggle()
                                           }
                                           mediaInfo.playPause()
                                       }, buttonDimension: 28)
                        .animation(showAnimations ? .easeInOut(duration: 0.15) : nil, value: mediaInfo.isPlaying)

                    MediaControlButton(systemName: "forward.fill", isTitle: false, action: { mediaInfo.nextTrack() }, buttonDimension: 24)
                }
            }
            .padding(12)
            .animation(showAnimations ? .smooth(duration: 0.2) : nil, value: "\(mediaInfo.title)\(mediaInfo.artist)")
        }
    }

    @ViewBuilder
    private func expandedEmbeddedDisplayCore() -> some View {
        VStack(alignment: .center, spacing: 15) {
            artworkView(
                size: CGSize(width: Layout.expandedArtworkSize, height: Layout.expandedArtworkSize),
                cornerRadius: Layout.expandedArtworkCornerRadius
            )
            .shadow(color: .black.opacity(0.2), radius: 5, y: 3)
            .onTapGesture {
                withAnimation(showAnimations ? .spring(response: 0.45, dampingFraction: 0.8) : nil) {
                    isArtworkExpanded = false
                }
            }

            VStack(spacing: 2) {
                MarqueeText(
                    text: mediaInfo.title,
                    fontSize: 18,
                    startDelay: 1,
                    maxWidth: 240
                )
                .fontWeight(.bold)
                .id("expanded-title-\(mediaInfo.title)")
                .matchedGeometryEffect(id: "mediaTitle", in: artworkExpansionNamespace)

                if !mediaInfo.artist.isEmpty {
                    MarqueeText(
                        text: mediaInfo.artist,
                        fontSize: 15,
                        startDelay: 1,
                        maxWidth: 220
                    )
                    .foregroundColor(.secondary)
                    .id("expanded-artist-\(mediaInfo.artist)")
                    .matchedGeometryEffect(id: "mediaArtist", in: artworkExpansionNamespace)
                }
            }

            HStack(alignment: .center, spacing: 8) {
                Text(formatTime(mediaInfo.currentTime))
                    .font(.caption)
                SimpleProgressBar(
                    value: Binding(
                        get: { mediaInfo.currentTime },
                        set: { newValue in mediaInfo.seek(to: newValue) }
                    ),
                    range: 0 ... max(mediaInfo.duration, 1),
                    barColor: dominantArtworkColor ?? .primary.opacity(0.8),
                    backgroundColor: (dominantArtworkColor ?? .secondary).opacity(0.3)
                )
                .frame(height: Layout.embeddedProgressBarHeight - 2)
                Text("-\(formatTime(max(0, mediaInfo.duration - mediaInfo.currentTime)))")
                    .font(.caption)
            }
            .monospacedDigit()
            .padding(.horizontal, 5)

            HStack(spacing: Layout.expandedMediaButtonsSpacing) {
                MediaControlButton(systemName: "backward.fill", isTitle: false, action: { mediaInfo.previousTrack() }, buttonDimension: Layout.expandedOtherButtonDimension)
                MediaControlButton(
                    systemName: mediaInfo.isPlaying ? "pause.fill" : "play.fill", isTitle: true,
                    action: {
                        withAnimation(showAnimations ? .easeInOut(duration: 0.2) : nil) { mediaInfo.isPlaying.toggle() }
                        mediaInfo.playPause()
                    },
                    buttonDimension: Layout.expandedPlayButtonDimension
                )
                .animation(showAnimations ? .easeInOut(duration: 0.15) : nil, value: mediaInfo.isPlaying)
                MediaControlButton(systemName: "forward.fill", isTitle: false, action: { mediaInfo.nextTrack() }, buttonDimension: Layout.expandedOtherButtonDimension)
            }
        }
        .animation(showAnimations ? .smooth(duration: 0.2) : nil, value: "\(mediaInfo.title)\(mediaInfo.artist)")
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
        if isPinnedMode {
            pinnedContent()
        } else {
            regularContent()
        }
    }

    @ViewBuilder
    private func regularContent() -> some View {
        BaseHoverContainer(
            bestGuessMonitor: bestGuessMonitor,
            mockPreviewActive: false,
            content: {
                VStack(spacing: 0) {
                    mediaControlsContent()
                        .globalPadding(20)
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
        .pinnable(appName: appName, bundleIdentifier: bundleIdentifier, type: .media)
    }

    @ViewBuilder
    private func pinnedContent() -> some View {
        VStack(spacing: 0) {
            mediaControlsContent()
                .globalPadding(20)
        }
        .padding(.top, (appNameStyle == .default && showAppTitleData) ? 25 : 0)
        .overlay(alignment: .topLeading) {
            hoverTitleBaseView(labelSize: measureString(appName, fontSize: 14))
                .onHover { isHovered in
                    withAnimation(.snappy) { hoveringWindowTitle = isHovered }
                }
        }
        .padding(.top, (appNameStyle == .popover && showAppTitleData) ? 30 : 0)
        .dockStyle(cornerRadius: 16, highlightColor: dominantArtworkColor)
    }

    @ViewBuilder
    private func mediaControlsContent() -> some View {
        Group {
            if isLoadingMediaInfo || mediaInfo.title.isEmpty {
                mediaControlsSkeleton()
            } else {
                if isArtworkExpandedFull {
                    expandedMediaControlsCore()
                } else {
                    compactMediaControlsCore()
                }
            }
        }
        .animation(showAnimations ? .spring(response: 0.45, dampingFraction: 0.8) : nil, value: isArtworkExpandedFull)
    }

    @ViewBuilder
    private func compactMediaControlsCore() -> some View {
        VStack(alignment: .center, spacing: Layout.containerSpacing) {
            HStack(alignment: .center, spacing: Layout.artworkTextSpacing) {
                artworkView(
                    size: CGSize(width: Layout.artworkSize, height: Layout.artworkSize),
                    cornerRadius: Layout.artworkCornerRadius
                )
                .onTapGesture {
                    withAnimation(showAnimations ? .smooth(duration: 0.125) : nil) {
                        isArtworkExpandedFull = true
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    MarqueeText(
                        text: mediaInfo.title,
                        fontSize: 16,
                        startDelay: 1,
                        maxWidth: 180
                    )
                    .fontWeight(.semibold)
                    .animation(showAnimations ? .easeInOut(duration: 0.2) : nil, value: mediaInfo.title)
                    .id("compact-full-title-\(mediaInfo.title)")

                    if !mediaInfo.artist.isEmpty {
                        MarqueeText(
                            text: mediaInfo.artist,
                            fontSize: 14,
                            startDelay: 1,
                            maxWidth: 180
                        )
                        .animation(showAnimations ? .easeInOut(duration: 0.2) : nil, value: mediaInfo.artist)
                        .id("compact-full-artist-\(mediaInfo.artist)")
                    }
                }
                Spacer(minLength: 0)
            }

            standardMediaPlaybackControls()
        }
        .animation(showAnimations ? .smooth(duration: 0.2) : nil, value: "\(mediaInfo.title)\(mediaInfo.artist)")
    }

    @ViewBuilder
    private func expandedMediaControlsCore() -> some View {
        VStack(alignment: .center, spacing: Layout.fullExpandedContainerSpacing) {
            artworkView(
                size: CGSize(width: Layout.fullExpandedArtworkSize, height: Layout.fullExpandedArtworkSize),
                cornerRadius: Layout.fullExpandedArtworkCornerRadius
            )
            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            .onTapGesture {
                withAnimation(showAnimations ? .smooth(duration: 0.125) : nil) {
                    isArtworkExpandedFull = false
                }
            }

            VStack(spacing: 3) {
                MarqueeText(
                    text: mediaInfo.title,
                    fontSize: Layout.fullExpandedTitleFontSize,
                    startDelay: 1,
                    maxWidth: Layout.fullExpandedArtworkSize + 20
                )
                .fontWeight(.bold)
                .id("expanded-full-title-\(mediaInfo.title)")

                if !mediaInfo.artist.isEmpty {
                    MarqueeText(
                        text: mediaInfo.artist,
                        fontSize: Layout.fullExpandedArtistFontSize,
                        startDelay: 1,
                        maxWidth: Layout.fullExpandedArtworkSize
                    )
                    .foregroundColor(.secondary)
                    .id("expanded-full-artist-\(mediaInfo.artist)")
                }
            }

            standardMediaPlaybackControls()
        }
        .animation(showAnimations ? .smooth(duration: 0.2) : nil, value: "\(mediaInfo.title)\(mediaInfo.artist)")
    }

    @ViewBuilder
    private func standardMediaPlaybackControls() -> some View {
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

        HStack(spacing: Layout.mediaButtonsSpacing) { // Standard spacing
            MediaControlButton(systemName: "backward.fill", isTitle: false, action: { mediaInfo.previousTrack() })
            MediaControlButton(systemName: "gobackward.15", isTitle: true, action: {
                let newTime = max(0, mediaInfo.currentTime - 15)
                mediaInfo.seek(to: newTime)
            })

            MediaControlButton(systemName: mediaInfo.isPlaying ? "pause.fill" : "play.fill", isTitle: true,
                               action: {
                                   withAnimation(showAnimations ? .easeInOut(duration: 0.2) : nil) {
                                       mediaInfo.isPlaying.toggle()
                                   }
                                   mediaInfo.playPause()
                               })
                               .animation(showAnimations ? .easeInOut(duration: 0.15) : nil, value: mediaInfo.isPlaying)

            MediaControlButton(systemName: "goforward.15", isTitle: true, action: {
                let newTime = min(mediaInfo.duration, mediaInfo.currentTime + 15)
                mediaInfo.seek(to: newTime)
            })
            MediaControlButton(systemName: "forward.fill", isTitle: false, action: { mediaInfo.nextTrack() })
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
    private func artworkView(size: CGSize, cornerRadius: CGFloat) -> some View {
        ZStack {
            if let artwork = mediaInfo.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
            } else {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: size.width, height: size.height)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.title2)
                    )
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .rotation3DEffect(.degrees(artworkRotation), axis: (x: 0, y: 1, z: 0))
        .animation(showAnimations ? .smooth(duration: 0.35) : nil, value: mediaInfo.artwork?.tiffRepresentation)
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
                        hoverTitleLabelView(labelSize: labelSize)
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
                            hoverTitleLabelView(labelSize: labelSize)
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
            .onHover { hover in
                withAnimation(showAnimations ? .snappy : nil) { hoveringAppIcon = hover } // Assuming .snappy is a valid Animation or should be .defaultAnimation
                // If .snappy is custom, ensure it's handled or replaced with a standard one.
                // For safety, let's use .default or a specific curve. .smooth is often used.
                // Rechecking .snappy in Apple docs. It is a valid animation type.
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

    @Default(.showAnimations) var showAnimations
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .symbolRenderingMode(.hierarchical)
                .font(isTitle ? .title : .body)
                .fontWeight(.semibold)
                .frame(width: buttonDimension, height: buttonDimension)
                .contentShape(Circle())
                .symbolReplaceTransition()
        }
        .buttonStyle(.plain)
        .background(
            Circle()
                .fill(Color.primary.opacity(isHovering ? 0.12 : 0))
                .frame(width: buttonDimension + 8, height: buttonDimension + 8)
        )
        .onHover { hovering in
            withAnimation(showAnimations ? .easeInOut(duration: 0.10) : nil) { isHovering = hovering }
        }
    }
}
