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
            self.contentTransition(.symbolEffect(.replace))
        } else {
            self
        }
    }
}
