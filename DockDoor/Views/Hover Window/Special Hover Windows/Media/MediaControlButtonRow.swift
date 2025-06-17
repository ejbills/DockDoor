
import Defaults
import SwiftUI

struct MediaControlButtonRow: View {
    @ObservedObject var mediaInfo: MediaInfo
    let spacing: CGFloat
    var isEmbedded: Bool = false
    var isExpanded: Bool = false
    var showingLyrics: Bool = false

    @Default(.showAnimations) var showAnimations

    var body: some View {
        HStack(spacing: spacing) {
            MediaControlButton(
                systemName: "backward.fill",
                isTitle: false,
                action: { mediaInfo.previousTrack() },
                buttonDimension: buttonDimension(isMain: false)
            )

            MediaControlButton(
                systemName: mediaInfo.isPlaying ? "pause.fill" : "play.fill",
                isTitle: true,
                action: {
                    withAnimation(showAnimations ? .easeInOut(duration: 0.2) : nil) {
                        mediaInfo.isPlaying.toggle()
                    }
                    mediaInfo.playPause()
                },
                buttonDimension: buttonDimension(isMain: true)
            )
            .animation(showAnimations ? .easeInOut(duration: 0.15) : nil, value: mediaInfo.isPlaying)

            MediaControlButton(
                systemName: "forward.fill",
                isTitle: false,
                action: { mediaInfo.nextTrack() },
                buttonDimension: buttonDimension(isMain: false)
            )
        }
    }

    private func buttonDimension(isMain: Bool) -> CGFloat {
        if isEmbedded {
            isMain ? 28 : 24
        } else if isExpanded {
            if showingLyrics {
                isMain ? MediaControlsLayout.expandedPlayButtonDimension - 2 : MediaControlsLayout.expandedOtherButtonDimension - 2
            } else {
                isMain ? MediaControlsLayout.expandedPlayButtonDimension : MediaControlsLayout.expandedOtherButtonDimension
            }
        } else {
            28
        }
    }
}
