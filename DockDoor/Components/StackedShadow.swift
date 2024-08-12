import SwiftUI

struct StackedShadow: ViewModifier {
    var count: Int
    var radius: CGFloat
    var x: CGFloat
    var y: CGFloat
    var color: Color

    init(stacked count: Int, radius: CGFloat = 10, x: CGFloat = 0, y: CGFloat = 0, color: Color = .black) {
        self.count = count
        self.radius = radius
        self.x = x
        self.y = y
        self.color = color
    }

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(Double(1) / Double(count)), radius: radius, x: x, y: y)
            .modifier(RecursiveShadow(count: count - 1, radius: radius, x: x, y: y, color: color))
    }

    private struct RecursiveShadow: ViewModifier {
        var count: Int
        var radius: CGFloat
        var x: CGFloat
        var y: CGFloat
        var color: Color

        func body(content: Content) -> some View {
            if count > 0 {
                content
                    .shadow(color: color.opacity(Double(1) / Double(count)), radius: radius, x: x, y: y)
                    .modifier(RecursiveShadow(count: count - 1, radius: radius, x: x, y: y, color: color))
            } else {
                content
            }
        }
    }
}

extension View {
    func shadow(stacked count: Int, radius: CGFloat = 10, x: CGFloat = 0, y: CGFloat = 0, color: Color = .black) -> some View {
        modifier(StackedShadow(stacked: count, radius: radius, x: x, y: y, color: color))
    }
}
