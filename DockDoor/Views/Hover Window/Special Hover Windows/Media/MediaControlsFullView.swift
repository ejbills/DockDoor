import Defaults
import SwiftUI

struct MediaControlsFullView: View {
    @ObservedObject var mediaInfo: MediaInfo
    let appName: String
    let bundleIdentifier: String
    let dockPosition: DockPosition
    let bestGuessMonitor: NSScreen
    let isPinnedMode: Bool
    @Binding var isArtworkExpandedFull: Bool
    @Binding var showingLyricsInFull: Bool
    @Binding var lyricsMode: Bool
    let artworkExpansionFullNamespace: Namespace.ID
    let dominantArtworkColor: Color?
    let artworkRotation: Double
    let isLoadingMediaInfo: Bool
    let appIcon: NSImage?
    let hoveringAppIcon: Bool
    let hoveringWindowTitle: Bool

    @Default(.showAppName) var showAppTitleData
    @Default(.showAppIconOnly) var showAppIconOnly
    @Default(.appNameStyle) var appNameStyle
    @Default(.showAnimations) var showAnimations

    @State private var initialContentSize: CGSize = .zero
    @State private var hasSetInitialSize: Bool = false

    var body: some View {
        Group {
            if isPinnedMode {
                pinnedContent()
            } else {
                regularContent()
            }
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
                }
                .padding(.top, (appNameStyle == .default && showAppTitleData) ? 25 : 0)
                .overlay(alignment: .topLeading) {
                    SharedHoverAppTitle(
                        appName: appName,
                        appIcon: appIcon,
                        hoveringAppIcon: hoveringAppIcon
                    )
                    .padding([.top, .leading], 4)
                }
                .dockStyle()
                .padding(.top, (appNameStyle == .popover && showAppTitleData) ? 30 : 0)
                .overlay {
                    WindowDismissalContainer(appName: appName,
                                             bestGuessMonitor: bestGuessMonitor,
                                             dockPosition: dockPosition,
                                             minimizeAllWindowsCallback: { _ in })
                        .allowsHitTesting(false)
                }
            },
            highlightColor: dominantArtworkColor,
            preventDockStyling: true
        )
        .pinnable(appName: appName, bundleIdentifier: bundleIdentifier, type: .media)
    }

    @ViewBuilder
    private func pinnedContent() -> some View {
        VStack(spacing: 0) {
            mediaControlsContent()
        }
        .padding(.top, (appNameStyle == .default && showAppTitleData) ? 25 : 0)
        .overlay(alignment: .topLeading) {
            SharedHoverAppTitle(
                appName: appName,
                appIcon: appIcon,
                hoveringAppIcon: hoveringAppIcon
            )
            .padding([.top, .leading], 4)
        }
        .dockStyle()
        .padding(.top, (appNameStyle == .popover && showAppTitleData) ? 30 : 0)
    }

    @ViewBuilder
    private func mediaControlsContent() -> some View {
        Group {
            if isLoadingMediaInfo || mediaInfo.title.isEmpty {
                MediaControlsSkeleton(isEmbedded: false)
            } else {
                if isArtworkExpandedFull {
                    expandedMediaControlsCore()
                } else {
                    compactMediaControlsCore()
                }
            }
        }
        .animation(showAnimations ? .spring(response: 0.45, dampingFraction: 0.8) : nil, value: isArtworkExpandedFull)
        .animation(showAnimations ? .spring(response: 0.45, dampingFraction: 0.8) : nil, value: showingLyricsInFull)
        .globalPadding(20)
    }

    @ViewBuilder
    private func compactMediaControlsCore() -> some View {
        VStack(alignment: .center, spacing: MediaControlsLayout.containerSpacing) {
            HStack(alignment: .center, spacing: MediaControlsLayout.artworkTextSpacing) {
                MediaArtworkView(
                    artwork: mediaInfo.artwork,
                    size: CGSize(width: MediaControlsLayout.artworkSize, height: MediaControlsLayout.artworkSize),
                    cornerRadius: MediaControlsLayout.artworkCornerRadius,
                    artworkRotation: artworkRotation
                )
                .matchedGeometryEffect(id: "artworkForFullView", in: artworkExpansionFullNamespace)
                .onTapGesture {
                    withAnimation(showAnimations ? .smooth(duration: 0.125) : nil) {
                        isArtworkExpandedFull = true
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    MarqueeText(
                        text: mediaInfo.title,
                        startDelay: 1
                    )
                    .fontWeight(.semibold)
                    .animation(showAnimations ? .easeInOut(duration: 0.2) : nil, value: mediaInfo.title)
                    .id("compact-full-title-\(mediaInfo.title)")

                    if !mediaInfo.artist.isEmpty {
                        MarqueeText(
                            text: mediaInfo.artist,
                            startDelay: 1
                        )
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .animation(showAnimations ? .easeInOut(duration: 0.2) : nil, value: mediaInfo.artist)
                        .id("compact-full-artist-\(mediaInfo.artist)")
                    }
                }
                Spacer(minLength: 0)
            }

            MediaPlaybackControls(
                mediaInfo: mediaInfo,
                isExpanded: false,
                showingLyrics: false
            )
        }
        .animation(showAnimations ? .smooth(duration: 0.2) : nil, value: "\(mediaInfo.title)\(mediaInfo.artist)")
    }

    @ViewBuilder
    private func expandedMediaControlsCore() -> some View {
        HStack(spacing: showingLyricsInFull ? 20 : 0) {
            // Left side - Artwork and controls
            VStack(alignment: .center, spacing: MediaControlsLayout.fullExpandedContainerSpacing) {
                MediaArtworkView(
                    artwork: mediaInfo.artwork,
                    size: CGSize(width: MediaControlsLayout.fullExpandedArtworkSize, height: MediaControlsLayout.fullExpandedArtworkSize),
                    cornerRadius: MediaControlsLayout.fullExpandedArtworkCornerRadius,
                    artworkRotation: artworkRotation
                )
                .matchedGeometryEffect(id: "artworkForFullView", in: artworkExpansionFullNamespace)
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                .onTapGesture {
                    withAnimation(showAnimations ? .smooth(duration: 0.125) : nil) {
                        isArtworkExpandedFull = false
                        showingLyricsInFull = false
                    }
                }

                VStack(spacing: 3) {
                    MarqueeText(
                        text: mediaInfo.title,
                        startDelay: 1
                    )
                    .font(.title3)
                    .fontWeight(.bold)
                    .id("expanded-full-title-\(mediaInfo.title)")

                    if !mediaInfo.artist.isEmpty {
                        MarqueeText(
                            text: mediaInfo.artist,
                            startDelay: 1
                        )
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .id("expanded-full-artist-\(mediaInfo.artist)")
                    }
                }

                MediaPlaybackControls(
                    mediaInfo: mediaInfo,
                    isExpanded: true,
                    showingLyrics: showingLyricsInFull,
                    lyricsMode: $lyricsMode,
                    showingLyricsInFull: $showingLyricsInFull
                )
            }
            .if(!hasSetInitialSize) { view in
                view.measure($initialContentSize)
                    .onPreferenceChange(ViewSizeKey.self) { size in
                        if !hasSetInitialSize {
                            initialContentSize = size
                            hasSetInitialSize = true
                        }
                    }
            }
            .if(isPinnedMode && !showingLyricsInFull && hasSetInitialSize && lyricsMode) { view in
                view.frame(width: initialContentSize.width)
            }

            // Right side - Lyrics view
            if showingLyricsInFull {
                MediaLyricsView(
                    mediaInfo: mediaInfo,
                    width: MediaControlsLayout.fullLyricsViewWidth + 80,
                    maxHeight: 300,
                    isFullMode: true
                )
            }
        }
        .animation(showAnimations ? .smooth(duration: 0.2) : nil, value: "\(mediaInfo.title)\(mediaInfo.artist)")
    }
}
