
import Defaults
import SwiftUI

struct MediaLyricsButton: View {
    @ObservedObject var lyricProvider: LyricProvider
    @Binding var lyricsMode: Bool
    @Binding var showingLyrics: Bool
    var isFullMode: Bool = false

    @Default(.showAnimations) var showAnimations

    var body: some View {
        MediaControlButton(
            systemName: lyricsMode ? (showingLyrics ? "quote.bubble.fill" : "quote.bubble") : "quote.bubble",
            isTitle: false,
            action: {
                if !lyricsMode {
                    lyricsMode = true
                    Task {
                        await lyricProvider.fetchLyrics()
                    }
                    withAnimation(showAnimations ? .spring(response: 0.6, dampingFraction: 0.8) : nil) {
                        showingLyrics = true
                    }
                } else {
                    withAnimation(showAnimations ? .spring(response: 0.6, dampingFraction: 0.8) : nil) {
                        showingLyrics.toggle()
                    }
                }
            }
        )
        .opacity(lyricProvider.isLoadingLyrics ? 0.5 : 1.0)
        .disabled(lyricProvider.isLoadingLyrics)
    }
}
