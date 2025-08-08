import SwiftUI

struct MaterialPillStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(BlurView(variant: 18))
            .clipShape(Capsule(style: .continuous))
            .borderedBackground(.primary.opacity(0.1), lineWidth: 1.5, shape: Capsule(style: .continuous))
    }
}

extension View {
    func materialPill() -> some View {
        modifier(MaterialPillStyle())
    }
}
