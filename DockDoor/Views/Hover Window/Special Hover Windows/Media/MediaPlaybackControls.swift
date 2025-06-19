import Defaults
import SwiftUI

struct MediaPlaybackControls: View {
    @ObservedObject var mediaInfo: MediaInfo
    let isExpanded: Bool
    let showingLyrics: Bool
    @Binding var lyricsMode: Bool
    @Binding var showingLyricsInFull: Bool

    @Default(.showAnimations) var showAnimations

    init(mediaInfo: MediaInfo,
         isExpanded: Bool,
         showingLyrics: Bool,
         lyricsMode: Binding<Bool> = .constant(false),
         showingLyricsInFull: Binding<Bool> = .constant(false))
    {
        self.mediaInfo = mediaInfo
        self.isExpanded = isExpanded
        self.showingLyrics = showingLyrics
        _lyricsMode = lyricsMode
        _showingLyricsInFull = showingLyricsInFull
    }

    var body: some View {
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
            .frame(height: MediaControlsLayout.progressBarHeight)

            Text("-\(formatTime(max(0, mediaInfo.duration - mediaInfo.currentTime)))")
        }
        .font(.caption)
        .monospacedDigit()

        if isExpanded {
            VStack(spacing: 12) {
                HStack(spacing: showingLyrics ? MediaControlsLayout.mediaButtonsSpacing - 5 : MediaControlsLayout.mediaButtonsSpacing) {
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

                HStack {
                    AudioDevicePickerView()

                    Spacer()

                    MediaLyricsButton(
                        mediaInfo: mediaInfo,
                        lyricsMode: $lyricsMode,
                        showingLyrics: $showingLyricsInFull,
                        isFullMode: true
                    )
                }
            }
        } else {
            HStack(spacing: showingLyrics ? MediaControlsLayout.mediaButtonsSpacing - 5 : MediaControlsLayout.mediaButtonsSpacing) {
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
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let seconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, abs(seconds))
    }
}
