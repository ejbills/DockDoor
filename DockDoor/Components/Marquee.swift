import SmoothGradient
import SwiftUI

struct MarqueeText: View {
    var text: String
    var fontSize: CGFloat
    var startDelay: Double
    let maxWidth: Double
    @State private var textWidth: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            TheMarquee(
                width: maxWidth,
                secsBeforeLooping: startDelay,
                speedPtsPerSec: 30,
                marqueeAlignment: .leading,
                nonMovingAlignment: .leading,
                spacingBetweenElements: 8,
                horizontalPadding: 8,
                fadeLength: 8
            ) {
                Text(text)
                    .font(.system(size: fontSize))
                    .lineLimit(1)
                    .background(
                        GeometryReader { textGeometry in
                            Color.clear.onAppear {
                                textWidth = textGeometry.size.width
                            }
                        }
                    )
            }
        }
        .frame(width: textWidth > maxWidth ? maxWidth : textWidth, height: fontSize + 4)
    }
}

struct TheMarquee<C: View>: View {
    var width: Double
    var secsBeforeLooping: Double = 0
    var speedPtsPerSec: Double = 30
    var marqueeAlignment: Alignment = .leading
    var nonMovingAlignment: Alignment = .center
    var spacingBetweenElements: Double = 8
    var horizontalPadding: Double = 8
    var fadeLength: Double = 8
    @ViewBuilder var content: () -> C
    @State private var contentSize: CGSize = .zero
    @State private var containerSize: CGSize = .zero
    @State private var offset: Double = 0
    @State private var animating = false

    var measured: Bool { contentSize != .zero && containerSize != .zero }
    var shouldMove: Bool { measured && contentSize.width > containerSize.width }

    func startAnimation() {
        if !measured || !shouldMove || animating { return }
        animating = true
        doAfter(secsBeforeLooping) {
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

        // Simulate the completion handler taht only available on macOS 14.0+
        doAfter(duration) {
            offset = 0
            doAfter(secsBeforeLooping) {
                if animating {
                    animLoop()
                }
            }
        }
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: spacingBetweenElements) {
                content()
                    .measure($contentSize)

                if measured, shouldMove {
                    content()
                }
            }
            .padding(.leading, shouldMove ? max(fadeLength, horizontalPadding) : 0)
            .frame(minWidth: width, alignment: nonMovingAlignment)
            .offset(x: offset)
        }
        .scrollDisabled(true)
        .frame(width: width)
        .fadeOnEdges(axis: .horizontal, fadeLength: fadeLength, disable: !shouldMove || fadeLength == 0)
        .measure($containerSize)
        .compositingGroup()
        .opacity(measured ? 1 : 0)
        .onChange(of: containerSize) { _ in startAnimation() }
        .onChange(of: contentSize) { _ in startAnimation() }
        .onAppear { startAnimation() }
        .onDisappear { animating = false }
    }
}

extension View {
    func fadeOnEdges(axis: Axis, fadeLength: Double, disable: Bool = false) -> some View {
        mask {
            if !disable {
                GeometryReader { geo in
                    DynStack(direction: axis, spacing: 0) {
                        if #available(macOS 14.0, *) {
                            SmoothLinearGradient(
                                from: .black.opacity(0),
                                to: .black.opacity(1),
                                startPoint: axis == .horizontal ? .leading : .top,
                                endPoint: axis == .horizontal ? .trailing : .bottom,
                                curve: .easeInOut
                            )
                            .frame(width: axis == .horizontal ? fadeLength : nil, height: axis == .vertical ? fadeLength : nil)
                            Color.black.frame(maxWidth: .infinity)
                            SmoothLinearGradient(
                                from: .black.opacity(0),
                                to: .black.opacity(1),
                                startPoint: axis == .horizontal ? .trailing : .bottom,
                                endPoint: axis == .horizontal ? .leading : .top,
                                curve: .easeInOut
                            )
                            .frame(width: axis == .horizontal ? fadeLength : nil, height: axis == .vertical ? fadeLength : nil)
                        }
                    }
                }
            } else {
                Color.black
            }
        }
    }
}

struct ViewSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = value + nextValue()
    }
}

func doAfter(_ seconds: Double = 0, action: @escaping () -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: action)
}

func timer(_ seconds: Double = 0, action: @escaping (Timer) -> Void) -> Timer {
    Timer.scheduledTimer(withTimeInterval: seconds, repeats: false, block: action)
}
