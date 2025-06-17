
import SwiftUI

struct MediaProgressBar: View {
    @ObservedObject var mediaInfo: MediaInfo
    let dominantColor: Color?
    let showingLyrics: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(formatTime(mediaInfo.currentTime))
                .font(.caption)
            SimpleProgressBar(
                value: Binding(
                    get: { mediaInfo.currentTime },
                    set: { newValue in mediaInfo.seek(to: newValue) }
                ),
                range: 0 ... max(mediaInfo.duration, 1),
                barColor: dominantColor ?? .primary.opacity(0.8),
                backgroundColor: (dominantColor ?? .secondary).opacity(0.3)
            )
            .frame(height: MediaControlsLayout.embeddedProgressBarHeight - 2)
            Text("-\(formatTime(max(0, mediaInfo.duration - mediaInfo.currentTime)))")
                .font(.caption)
        }
        .monospacedDigit()
        .padding(.horizontal, showingLyrics ? 2 : 5)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let seconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, abs(seconds))
    }
}
