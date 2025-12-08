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
        borderedBackground(content, lineWidth: lineWidth, shape: RoundedRectangle(cornerRadius: cornerRadius))
    }

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
                        } else {
                            LinearGradient(
                                gradient: Gradient(colors: [.black.opacity(0), .black]),
                                startPoint: axis == .horizontal ? .leading : .top,
                                endPoint: axis == .horizontal ? .trailing : .bottom
                            )
                            .frame(width: axis == .horizontal ? fadeLength : nil, height: axis == .vertical ? fadeLength : nil)
                            Color.black.frame(maxWidth: .infinity)
                            LinearGradient(
                                gradient: Gradient(colors: [.black.opacity(0), .black]),
                                startPoint: axis == .horizontal ? .trailing : .bottom,
                                endPoint: axis == .horizontal ? .leading : .top
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
