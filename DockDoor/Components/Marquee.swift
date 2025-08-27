import Defaults
import SwiftUI

struct MarqueeText: View {
    var text: String
    var startDelay: Double
    var maxWidth: Double?

    @State private var textSize: CGSize = .zero

    init(text: String, startDelay: Double = 1.0, maxWidth: Double? = nil) {
        self.text = text
        self.startDelay = startDelay
        self.maxWidth = maxWidth
    }

    var body: some View {
        TheMarquee(
            forcedWidth: maxWidth,
            secsBeforeLooping: startDelay,
            speedPtsPerSec: 30,
            marqueeAlignment: .leading,
            nonMovingAlignment: .center,
            spacingBetweenElements: 8,
            horizontalPadding: 8,
            fadeLength: 8
        ) {
            Text(text)
                .lineLimit(1)
                .measure($textSize)
        }
    }
}

struct TheMarquee<C: View>: View {
    var forcedWidth: Double?
    var secsBeforeLooping: Double = 0
    var speedPtsPerSec: Double = 30
    var marqueeAlignment: Alignment = .leading
    var nonMovingAlignment: Alignment = .center
    var spacingBetweenElements: Double = 8
    var horizontalPadding: Double = 8
    var fadeLength: Double = 8
    @ViewBuilder var content: () -> C
    @State private var contentSize: CGSize = .zero
    @State private var offset: Double = 0
    @State private var animating = false
    @State private var actualWidth: CGFloat = 0
    @Default(.enableTitleMarquee) private var enableTitleMarquee

    var measured: Bool { contentSize != .zero }

    var internalShouldMove: Bool {
        let displayRegionWidth = forcedWidth ?? actualWidth
        return enableTitleMarquee && (measured && displayRegionWidth > 0 && contentSize.width > displayRegionWidth)
    }

    private func updateAnimationState() {
        if internalShouldMove {
            if !animating {
                offset = 0
                startAnimation()
            }
        } else {
            if animating {
                animating = false
                offset = 0
            }
        }
    }

    func startAnimation() {
        if !internalShouldMove || animating { return }

        animating = true
        doAfter(secsBeforeLooping) {
            if !animating { return }
            animLoop()
        }
    }

    func animLoop() {
        if !animating { return }
        let offsetAmount = contentSize.width + spacingBetweenElements
        let duration = offsetAmount / speedPtsPerSec

        withAnimation(.easeInOut(duration: duration)) {
            offset = -offsetAmount
        }

        doAfter(duration) {
            if animating {
                offset = 0
                doAfter(secsBeforeLooping) {
                    if animating {
                        animLoop()
                    }
                }
            }
        }
    }

    var body: some View {
        GeometryReader { geo in
            let displayRegionWidth = forcedWidth ?? geo.size.width

            ScrollView(.horizontal) {
                HStack(spacing: spacingBetweenElements) {
                    content()
                        .measure($contentSize)

                    if measured, internalShouldMove {
                        content()
                    }
                }
                .padding(.horizontal, internalShouldMove ? horizontalPadding : 0)
                .frame(minWidth: internalShouldMove ? displayRegionWidth : nil, alignment: internalShouldMove ? marqueeAlignment : nonMovingAlignment)
                .frame(maxWidth: !enableTitleMarquee ? displayRegionWidth : nil)
                .offset(x: internalShouldMove ? offset : 0)
            }
            .scrollDisabled(true)
            .frame(width: displayRegionWidth)
            .if(internalShouldMove && fadeLength > 0) { view in
                view.fadeOnEdges(axis: .horizontal, fadeLength: fadeLength, disable: false)
            }
            .compositingGroup()
            .opacity(measured ? 1 : 0)
            .onAppear {
                actualWidth = geo.size.width
                updateAnimationState()
            }
            .onChange(of: geo.size.width) { newGeoWidth in
                actualWidth = newGeoWidth
                updateAnimationState()
            }
            .onChange(of: contentSize) { _ in
                // actualWidth should be current from GeometryReader's geo.size.width
                updateAnimationState()
            }
            .onChange(of: forcedWidth) { _ in
                // actualWidth should be current
                updateAnimationState()
            }
        }
        // Height is based on content once measured.
        .frame(width: marqueeOuterFrameWidth, height: measured ? contentSize.height : nil)
        .onDisappear {
            animating = false
            offset = 0
        }
    }

    private var marqueeOuterFrameWidth: CGFloat? {
        if let fw = forcedWidth {
            return CGFloat(fw)
        }
        if measured {
            if !internalShouldMove {
                return contentSize.width
            } else {
                return actualWidth > 0 ? actualWidth : nil
            }
        }
        return nil
    }
}
