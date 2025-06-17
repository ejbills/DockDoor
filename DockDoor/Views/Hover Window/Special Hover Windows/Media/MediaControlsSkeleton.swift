import Defaults
import SwiftUI

struct MediaControlsSkeleton: View {
    let isEmbedded: Bool

    @Default(.uniformCardRadius) var uniformCardRadius
    @Default(.showAnimations) var showAnimations

    var body: some View {
        if isEmbedded {
            embeddedSkeleton()
        } else {
            fullSkeleton()
        }
    }

    @ViewBuilder
    private func embeddedSkeleton() -> some View {
        VStack(spacing: 6) {
            HStack(alignment: .center, spacing: MediaControlsLayout.artworkTextSpacing) {
                RoundedRectangle(cornerRadius: MediaControlsLayout.artworkCornerRadius, style: .continuous)
                    .fill(Color.primary.opacity(MediaControlsLayout.skeletonOpacity))
                    .frame(width: MediaControlsLayout.embeddedArtworkSize, height: MediaControlsLayout.embeddedArtworkSize)

                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(MediaControlsLayout.skeletonOpacity))
                        .frame(width: 100, height: 13)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(MediaControlsLayout.skeletonOpacity))
                        .frame(width: 70, height: 11)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: MediaControlsLayout.embeddedMediaButtonsSpacing) {
                ForEach(0 ..< 3, id: \.self) { index in
                    Circle()
                        .fill(Color.primary.opacity(MediaControlsLayout.skeletonOpacity))
                        .frame(width: index == 1 ? 28 : 24, height: index == 1 ? 28 : 24)
                }
            }
        }
        .glintPlaceholder()
    }

    @ViewBuilder
    private func fullSkeleton() -> some View {
        VStack(spacing: MediaControlsLayout.containerSpacing) {
            HStack(alignment: .center, spacing: MediaControlsLayout.artworkTextSpacing) {
                RoundedRectangle(cornerRadius: MediaControlsLayout.artworkCornerRadius, style: .continuous)
                    .fill(Color.primary.opacity(MediaControlsLayout.skeletonOpacity))
                    .frame(width: MediaControlsLayout.artworkSize, height: MediaControlsLayout.artworkSize)

                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(MediaControlsLayout.skeletonOpacity))
                        .frame(width: 120, height: 16)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(MediaControlsLayout.skeletonOpacity))
                        .frame(width: 80, height: 14)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.primary.opacity(MediaControlsLayout.skeletonOpacity))
                    .frame(width: 35, height: 12)

                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.primary.opacity(MediaControlsLayout.skeletonOpacity))
                    .frame(height: MediaControlsLayout.progressBarHeight)
                    .frame(maxWidth: .infinity)

                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.primary.opacity(MediaControlsLayout.skeletonOpacity))
                    .frame(width: 35, height: 12)
            }
            .font(.caption)

            HStack(spacing: MediaControlsLayout.mediaButtonsSpacing) {
                Spacer()
                ForEach(0 ..< 5, id: \.self) { _ in
                    Circle()
                        .fill(Color.primary.opacity(MediaControlsLayout.skeletonOpacity))
                        .frame(width: 28, height: 28)
                }
                Spacer()
            }
        }
        .glintPlaceholder()
    }
}
