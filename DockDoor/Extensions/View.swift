import SmoothGradient
import SwiftUI

extension View {
    @ViewBuilder
    func `if`(_ condition: Bool, transform: (Self) -> some View) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    func borderedBackground(_ content: some ShapeStyle, lineWidth: CGFloat = 1.0, shape: some InsettableShape) -> some View {
        padding(lineWidth * 0.75)
            .background {
                shape
                    .strokeBorder(content, lineWidth: lineWidth)
            }
            .clipShape(shape)
    }

    func borderedBackground(_ content: some ShapeStyle, lineWidth: CGFloat = 1.0, cornerRadius: CGFloat = 0) -> some View {
        borderedBackground(content, lineWidth: lineWidth, shape: RoundedRectangle(cornerRadius: cornerRadius + 1, style: .continuous))
    }

    func fadeOnEdges(axis: Axis, fadeLength: Double, disable: Bool = false, disableLeading: Bool = false, disableTrailing: Bool = false) -> some View {
        mask {
            if !disable {
                GeometryReader { geo in
                    let containerSize = axis == .horizontal ? geo.size.width : geo.size.height
                    let fadeLength = min(fadeLength, containerSize * 0.05)
                    DynStack(direction: axis, spacing: 0) {
                        if #available(macOS 14.0, *) {
                            if disableLeading {
                                Color.black
                                    .frame(width: axis == .horizontal ? fadeLength : nil, height: axis == .vertical ? fadeLength : nil)
                            } else {
                                SmoothLinearGradient(
                                    from: .black.opacity(0),
                                    to: .black.opacity(1),
                                    startPoint: axis == .horizontal ? .leading : .top,
                                    endPoint: axis == .horizontal ? .trailing : .bottom,
                                    curve: .easeInOut
                                )
                                .frame(width: axis == .horizontal ? fadeLength : nil, height: axis == .vertical ? fadeLength : nil)
                            }
                            Color.black.frame(maxWidth: .infinity)
                            if disableTrailing {
                                Color.black
                                    .frame(width: axis == .horizontal ? fadeLength : nil, height: axis == .vertical ? fadeLength : nil)
                            } else {
                                SmoothLinearGradient(
                                    from: .black.opacity(0),
                                    to: .black.opacity(1),
                                    startPoint: axis == .horizontal ? .trailing : .bottom,
                                    endPoint: axis == .horizontal ? .leading : .top,
                                    curve: .easeInOut
                                )
                                .frame(width: axis == .horizontal ? fadeLength : nil, height: axis == .vertical ? fadeLength : nil)
                            }
                        } else {
                            if disableLeading {
                                Color.black
                                    .frame(width: axis == .horizontal ? fadeLength : nil, height: axis == .vertical ? fadeLength : nil)
                            } else {
                                LinearGradient(
                                    gradient: Gradient(colors: [.black.opacity(0), .black]),
                                    startPoint: axis == .horizontal ? .leading : .top,
                                    endPoint: axis == .horizontal ? .trailing : .bottom
                                )
                                .frame(width: axis == .horizontal ? fadeLength : nil, height: axis == .vertical ? fadeLength : nil)
                            }
                            Color.black.frame(maxWidth: .infinity)
                            if disableTrailing {
                                Color.black
                                    .frame(width: axis == .horizontal ? fadeLength : nil, height: axis == .vertical ? fadeLength : nil)
                            } else {
                                LinearGradient(
                                    gradient: Gradient(colors: [.black.opacity(0), .black]),
                                    startPoint: axis == .horizontal ? .trailing : .bottom,
                                    endPoint: axis == .horizontal ? .leading : .top
                                )
                                .frame(width: axis == .horizontal ? fadeLength : nil, height: axis == .vertical ? fadeLength : nil)
                            }
                        }
                    }
                }
            } else {
                Color.black
            }
        }
    }
}

extension View {
    @ViewBuilder
    func trackScrollOffset(axis: Axis.Set, scrolledFromStart: Binding<Bool>) -> some View {
        if #available(macOS 15.0, *) {
            self.onScrollGeometryChange(for: Bool.self) { geo in
                let offset = axis == .vertical ? geo.contentOffset.y : geo.contentOffset.x
                return offset > 1
            } action: { _, isScrolled in
                scrolledFromStart.wrappedValue = isScrolled
            }
        } else {
            self
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

    @ViewBuilder
    func symbolReplaceTransition() -> some View {
        if #available(macOS 14.0, *) {
            contentTransition(.symbolEffect(.replace))
        } else {
            self
        }
    }
}
