import SwiftUI

struct MaterialPillStyle: ViewModifier {
    let backgroundAppearance: BackgroundAppearance

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(BlurView(appearance: backgroundAppearance))
            .clipShape(Capsule(style: .continuous))
            .borderedBackground(.primary.opacity(0.1), lineWidth: 1.5, shape: Capsule(style: .continuous))
    }
}

extension View {
    func materialPill(backgroundAppearance: BackgroundAppearance) -> some View {
        modifier(MaterialPillStyle(backgroundAppearance: backgroundAppearance))
    }
}
