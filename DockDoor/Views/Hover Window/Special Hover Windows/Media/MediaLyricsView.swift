import Defaults
import SwiftUI

struct MediaLyricsView: View {
    @ObservedObject var mediaInfo: MediaInfo
    let width: CGFloat
    let maxHeight: CGFloat
    let isFullMode: Bool

    @Default(.showAnimations) var showAnimations

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if mediaInfo.isLoadingLyrics {
                lyricsLoadingView()
            } else if mediaInfo.hasLyrics {
                lyricsScrollView()
            } else {
                lyricsNotFoundView()
            }
        }
        .frame(width: width)
        .frame(maxHeight: maxHeight)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(0.2)
        )
    }

    @ViewBuilder
    private func lyricsLoadingView() -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.0)
                .tint(.secondary)
            Text("Loading lyrics...")
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .opacity(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func lyricsNotFoundView() -> some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.title)
                .fontWeight(.medium)
                .foregroundColor(.secondary.opacity(0.7))
            Text("No lyrics available")
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func lyricsScrollView() -> some View {
        let visibleLyrics = getVisibleLyrics()
        let lyricAnimation: Animation? = showAnimations ? .smooth(duration: 0.45) : nil

        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .center, spacing: MediaControlsLayout.lyricsVerticalSpacing) {
                    ForEach(visibleLyrics, id: \.lyric.id) { lyricItem in
                        let isCurrent = lyricItem.isCurrent
                        Text(lyricItem.lyric.words)
                            .font(.title3)
                            .fontWeight(.bold)
                            .opacity(isCurrent ? MediaControlsLayout.lyricsCurrentOpacity : MediaControlsLayout.lyricsInactiveOpacity)
                            .multilineTextAlignment(.center)
                            .scaleEffect(isCurrent ? MediaControlsLayout.lyricsCurrentLineScale : 1.0)
                            .padding(.horizontal, isCurrent ? MediaControlsLayout.lyricsHorizontalPadding + 4 : MediaControlsLayout.lyricsHorizontalPadding)
                            .padding(4)
                            .id(lyricItem.lyric.id)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .fadeOnEdges(axis: .vertical, fadeLength: 45, disable: visibleLyrics.isEmpty)
            .scrollDisabled(visibleLyrics.isEmpty)
            .onChange(of: mediaInfo.currentLyricIndex) { newIndex in
                guard let currentIndex = newIndex,
                      currentIndex < mediaInfo.lyrics.count
                else {
                    if newIndex == nil, !visibleLyrics.isEmpty {
                        proxy.scrollTo(visibleLyrics.first?.lyric.id, anchor: .top)
                    }
                    return
                }

                // Get the ID of the lyric line to scroll to
                let targetLyricID = mediaInfo.lyrics[currentIndex].id

                DispatchQueue.main.async {
                    withAnimation(lyricAnimation) {
                        proxy.scrollTo(targetLyricID, anchor: .center)
                    }
                }
            }
            .animation(lyricAnimation, value: mediaInfo.currentLyricIndex)
            .animation(lyricAnimation, value: visibleLyrics.map(\.lyric.words))
        }
        .padding(.horizontal, 4)
        .overlay {
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        }

        // Fallback for empty lyrics
        if visibleLyrics.isEmpty {
            VStack(spacing: 8) {
                if mediaInfo.isLoadingLyrics {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.secondary)
                    Text("Loading lyrics...")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                } else {
                    Image(systemName: "music.note")
                        .font(.title3)
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("No lyrics available")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .dockStyle().opacity(0.3)
        }
    }

    private func getVisibleLyrics() -> [LyricDisplayItem] {
        guard !mediaInfo.lyrics.isEmpty else { return [] }

        var visibleItems: [LyricDisplayItem] = []

        if let currentIndex = mediaInfo.currentLyricIndex {
            for i in 0 ..< mediaInfo.lyrics.count {
                let lyric = mediaInfo.lyrics[i]
                let isCurrent = i == currentIndex

                let timeSinceLyricStart = mediaInfo.currentTime - lyric.startTime
                let isInLongBreak = isCurrent && timeSinceLyricStart > 15.0 && mediaInfo.isPlaying

                visibleItems.append(LyricDisplayItem(
                    lyric: lyric,
                    isCurrent: isCurrent && !isInLongBreak,
                    isPrevious: i < currentIndex || (isCurrent && isInLongBreak),
                    isNext: i > currentIndex
                ))
            }
        } else if !mediaInfo.lyrics.isEmpty {
            // No current index, show all lyrics as 'next' or 'upcoming'
            for i in 0 ..< mediaInfo.lyrics.count {
                let lyric = mediaInfo.lyrics[i]
                visibleItems.append(LyricDisplayItem(
                    lyric: lyric,
                    isCurrent: false,
                    isPrevious: false,
                    isNext: true
                ))
            }
        }

        return visibleItems
    }
}

struct LyricDisplayItem: Hashable {
    let lyric: LyricLine
    let isCurrent: Bool
    let isPrevious: Bool
    let isNext: Bool

    func hash(into hasher: inout Hasher) {
        hasher.combine(lyric.id)
        hasher.combine(isCurrent)
        hasher.combine(isPrevious)
        hasher.combine(isNext)
    }

    static func == (lhs: LyricDisplayItem, rhs: LyricDisplayItem) -> Bool {
        lhs.lyric.id == rhs.lyric.id &&
            lhs.isCurrent == rhs.isCurrent &&
            lhs.isPrevious == rhs.isPrevious &&
            lhs.isNext == rhs.isNext
    }
}

extension Collection {
    /// Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
