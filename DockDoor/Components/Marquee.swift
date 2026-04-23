import SwiftUI

struct MarqueeText: View {
    var text: String
    var startDelay: Double
    var maxWidth: Double?
    var truncationMode: Text.TruncationMode
    var enableScrolling: Bool

    @State private var textSize: CGSize = .zero
    @State private var containerWidth: CGFloat = 0

    init(text: String, startDelay: Double = 3.0, maxWidth: Double? = nil, truncationMode: Text.TruncationMode = .tail, enableScrolling: Bool = true) {
        self.text = text
        self.startDelay = startDelay
        self.maxWidth = maxWidth
        self.truncationMode = truncationMode
        self.enableScrolling = enableScrolling
    }

    private var measured: Bool { textSize != .zero }

    private var available: CGFloat {
        if let maxWidth { return CGFloat(maxWidth) }
        return containerWidth
    }

    private var shouldScroll: Bool {
        enableScrolling && measured && available > 0 && textSize.width > available
    }

    private var outerWidth: CGFloat? {
        if let maxWidth { return CGFloat(maxWidth) }
        guard measured, containerWidth > 0 else { return nil }
        if shouldScroll { return containerWidth }
        return min(textSize.width, containerWidth)
    }

    var body: some View {
        GeometryReader { geo in
            Group {
                if shouldScroll {
                    MarqueeScrollEffect(
                        text: text,
                        textWidth: textSize.width,
                        containerWidth: available,
                        delay: startDelay
                    )
                } else {
                    Text(text)
                        .lineLimit(1)
                        .truncationMode(truncationMode)
                }
            }
            .onAppear { containerWidth = geo.size.width }
            .onChange(of: geo.size.width) { newWidth in
                containerWidth = newWidth
            }
        }
        .frame(width: outerWidth, height: measured ? textSize.height : nil)
        .background {
            Text(text)
                .lineLimit(1)
                .fixedSize()
                .hidden()
                .measure($textSize)
        }
    }
}

private struct MarqueeScrollEffect: View {
    let text: String
    let textWidth: CGFloat
    let containerWidth: CGFloat
    let delay: Double

    @State private var startDate = Date()

    private let speed: CGFloat = 15
    private let spacing: CGFloat = 8
    private let fadeLength: CGFloat = 4

    private var dist: CGFloat { textWidth + spacing }
    private var scrollDuration: Double { Double(dist / speed) }
    private var totalCycle: Double { delay + scrollDuration }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
            let elapsed = context.date.timeIntervalSince(startDate)
                .truncatingRemainder(dividingBy: totalCycle)
            let offset: CGFloat = elapsed < delay
                ? 0
                : -dist * CGFloat((elapsed - delay) / scrollDuration)

            HStack(spacing: spacing) {
                Text(text).lineLimit(1).fixedSize()
                Text(text).lineLimit(1).fixedSize()
            }
            .offset(x: offset)
        }
        .frame(width: containerWidth, alignment: .leading)
        .clipped()
        .mask {
            let r = fadeLength / containerWidth
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: r),
                    .init(color: .black, location: 1 - r),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        .onChange(of: text) { _ in
            startDate = .now
        }
    }
}
