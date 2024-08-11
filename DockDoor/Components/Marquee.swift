//
//  Marquee.swift
//  NotchNook
//
//  Created by Igor Marcossi on 16/06/24.
//

import SmoothGradient
import SwiftUI

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
        withAnimation(.linear(duration: duration)) {
            offset = -offsetAmount
        } completion: {
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
        .onChange(of: containerSize) { _, _ in startAnimation() }
        .onChange(of: contentSize) { _, _ in startAnimation() }
        .onAppear { startAnimation() }
        .onDisappear { animating = false }
    }
}

extension View {
    func fadeOnEdges(axis: Axis, fadeLength: Double, disable: Bool = false) -> some View {
        mask {
            if !disable {
                GeometryReader { _ in
                    DynStack(direction: axis, spacing: 0) {
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
            } else {
                Color.black
            }
        }
    }
}

extension View {
    func measure(_ sizeBinding: Binding<CGSize>) -> some View {
        background {
            Color.clear
                .background(
                    GeometryReader { geometry in
                        Color.clear
                            .preference(key: ViewSizeKey.self, value: geometry.size)
                    }
                )
                .onPreferenceChange(ViewSizeKey.self) { size in
                    sizeBinding.wrappedValue = size
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

func doAfter(_ seconds: Double, action: @escaping () -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: action)
}

extension CGSize {
    static func + (lhs: CGSize, rhs: CGSize) -> CGSize {
        CGSize(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
    }
}
