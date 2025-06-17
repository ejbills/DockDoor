import AVKit
import Defaults
import SwiftUI

enum MediaControlsLayout {
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

    // MARK: - Enhanced Lyrics Layout

    static let expandedViewHeight: CGFloat = 380
    static let lyricsLineHeight: CGFloat = 24
    static let lyricsMaxVisibleLines: Int = 12
    static let fullLyricsViewWidth: CGFloat = 100
    static let lyricsVerticalSpacing: CGFloat = 8
    static let lyricsHorizontalPadding: CGFloat = 8
    static let lyricsCurrentLineScale: CGFloat = 1.15
    static let lyricsInactiveOpacity: Double = 0.4
    static let lyricsCurrentOpacity: Double = 1.0
    static let lyricsBackgroundOpacity: Double = 0.12
}

struct MediaControlsView: View {
    @StateObject private var mediaInfo = MediaInfo()
    let appName: String
    let bundleIdentifier: String
    let dockPosition: DockPosition
    let bestGuessMonitor: NSScreen
    let isEmbeddedMode: Bool
    let isPinnedMode: Bool
    let idealWidth: CGFloat?

    @Default(.uniformCardRadius) var uniformCardRadius
    @Default(.showAppName) var showAppTitleData
    @Default(.showAppIconOnly) var showAppIconOnly
    @Default(.appNameStyle) var appNameStyle
    @Default(.showAnimations) var showAnimations

    @State private var appIcon: NSImage? = nil
    @State private var hoveringAppIcon: Bool = false
    @State private var hoveringWindowTitle: Bool = false
    @State private var isLoadingMediaInfo: Bool = true
    @State private var dominantArtworkColor: Color? = nil
    @State private var hasAppeared: Bool = false

    @State private var isArtworkExpanded: Bool = false
    @Namespace private var artworkExpansionNamespace

    @State private var isArtworkExpandedFull: Bool = false
    @Namespace private var artworkExpansionFullNamespace

    // MARK: - Lyrics State

    @State private var showingLyrics: Bool = false
    @State private var showingLyricsInFull: Bool = false
    @State private var lyricsMode: Bool = false
    @Namespace private var lyricsExpansionNamespace

    @State private var artworkRotation: Double = 0.0

    init(appName: String,
         bundleIdentifier: String,
         dockPosition: DockPosition,
         bestGuessMonitor: NSScreen,
         isEmbeddedMode: Bool = false,
         isPinnedMode: Bool = false,
         idealWidth: CGFloat? = nil)
    {
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.dockPosition = dockPosition
        self.bestGuessMonitor = bestGuessMonitor
        self.isEmbeddedMode = isEmbeddedMode
        self.isPinnedMode = isPinnedMode
        self.idealWidth = idealWidth
    }

    var body: some View {
        Group {
            coreContent()
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
            hasAppeared = false
        }
        .onChange(of: mediaInfo.artwork) { newArtwork in
            if let artwork = newArtwork {
                dominantArtworkColor = artwork.averageColor()
            } else {
                dominantArtworkColor = nil
            }
        }
        .onChange(of: mediaInfo.title) { newTitle in
            if !mediaInfo.title.isEmpty, hasAppeared {
                withAnimation(showAnimations ? .smooth(duration: 0.3) : nil) {
                    artworkRotation += 360
                }

                if lyricsMode {
                    Task {
                        await mediaInfo.fetchLyricsIfNeeded(lyricsMode: lyricsMode)
                    }
                }
            }
            if !hasAppeared { hasAppeared = true }
        }
        .onChange(of: isArtworkExpandedFull) { expanded in
            if !expanded {
                showingLyricsInFull = false
            }
        }
        .onDisappear {
            mediaInfo.updateTimer?.invalidate()
        }
    }

    @ViewBuilder
    private func coreContent() -> some View {
        if isEmbeddedMode {
            MediaControlsEmbeddedView(
                mediaInfo: mediaInfo,
                appName: appName,
                bundleIdentifier: bundleIdentifier,
                dominantArtworkColor: dominantArtworkColor,
                artworkRotation: artworkRotation,
                isLoadingMediaInfo: isLoadingMediaInfo,
                idealWidth: idealWidth
            )
        } else {
            MediaControlsFullView(
                mediaInfo: mediaInfo,
                appName: appName,
                bundleIdentifier: bundleIdentifier,
                dockPosition: dockPosition,
                bestGuessMonitor: bestGuessMonitor,
                isPinnedMode: isPinnedMode,
                isArtworkExpandedFull: $isArtworkExpandedFull,
                showingLyricsInFull: $showingLyricsInFull,
                lyricsMode: $lyricsMode,
                artworkExpansionFullNamespace: artworkExpansionFullNamespace,
                dominantArtworkColor: dominantArtworkColor,
                artworkRotation: artworkRotation,
                isLoadingMediaInfo: isLoadingMediaInfo,
                appIcon: appIcon,
                hoveringAppIcon: hoveringAppIcon,
                hoveringWindowTitle: hoveringWindowTitle
            )
        }
    }

    private func loadAppIcon() {
        if let icon = SharedHoverUtils.loadAppIcon(for: bundleIdentifier) {
            DispatchQueue.main.async {
                if appIcon != icon { appIcon = icon }
            }
        } else if appIcon != nil {
            DispatchQueue.main.async { appIcon = nil }
        }
    }
}
