import Defaults
import SwiftUI

struct MediaControlsEmbeddedView: View {
    @ObservedObject var mediaInfo: MediaInfo
    let appName: String
    let bundleIdentifier: String
    let dominantArtworkColor: Color?
    let artworkRotation: Double
    let isLoadingMediaInfo: Bool
    let idealWidth: CGFloat?
    let backgroundAppearance: BackgroundAppearance

    @Default(.uniformCardRadius) var uniformCardRadius
    @Default(.showAnimations) var showAnimations

    var body: some View {
        compactEmbeddedDisplayCore()
            .animation(showAnimations ? .smooth(duration: 0.125) : nil, value: isLoadingMediaInfo)
            .padding(12)
            .frame(minWidth: idealWidth ?? (MediaControlsLayout.embeddedArtworkSize + MediaControlsLayout.artworkTextSpacing + 165), alignment: .center)
            .dockStyle(backgroundAppearance: backgroundAppearance, cornerRadius: CardRadius.inner, outerPadding: 0)
            .if(isMediaApp(bundleIdentifier)) { view in
                view.mediaScrollable(bundleIdentifier: bundleIdentifier, mediaInfo: mediaInfo)
            }
    }

    @ViewBuilder
    private func compactEmbeddedDisplayCore() -> some View {
        if isLoadingMediaInfo || mediaInfo.title.isEmpty {
            MediaControlsSkeleton(isEmbedded: true)
        } else {
            VStack(alignment: .center, spacing: 6) {
                HStack(alignment: .center, spacing: MediaControlsLayout.artworkTextSpacing) {
                    let artworkSize = CGSize(width: MediaControlsLayout.embeddedArtworkSize, height: MediaControlsLayout.embeddedArtworkSize)
                    MediaArtworkView(
                        artwork: mediaInfo.artwork,
                        size: artworkSize,
                        cornerRadius: MediaControlsLayout.artworkCornerRadius,
                        artworkRotation: artworkRotation
                    )

                    VStack(alignment: .leading, spacing: 1) {
                        MarqueeText(
                            text: mediaInfo.title,
                            startDelay: 1
                        )
                        .font(.callout)
                        .fontWeight(.medium)
                        .id("compact-title-\(mediaInfo.title)")

                        if !mediaInfo.artist.isEmpty {
                            MarqueeText(
                                text: mediaInfo.artist,
                                startDelay: 1
                            )
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .id("compact-artist-\(mediaInfo.artist)")
                        }
                    }

                    Spacer(minLength: 0)
                }

                TimelineView(.periodic(from: .now, by: mediaInfo.isPlaying ? 0.25 : 1.0)) { _ in
                    SimpleProgressBar(
                        value: Binding(
                            get: { mediaInfo.displayTime },
                            set: { newValue in mediaInfo.seek(to: newValue) }
                        ),
                        range: 0 ... max(mediaInfo.duration, 1),
                        barColor: .primary.opacity(0.5),
                        backgroundColor: .primary.opacity(0.1)
                    )
                    .frame(height: 10)
                }

                MediaControlButtonRow(
                    mediaInfo: mediaInfo,
                    spacing: MediaControlsLayout.embeddedMediaButtonsSpacing,
                    isEmbedded: true
                )
            }
            .animation(showAnimations ? .smooth(duration: 0.2) : nil, value: "\(mediaInfo.title)\(mediaInfo.artist)")
        }
    }
}
