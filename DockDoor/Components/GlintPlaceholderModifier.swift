import SwiftUI

private struct GlintPlaceholderModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .redacted(reason: .placeholder)
            .overlay(
                CustomizableFluidGradientView()
                    .opacity(0.45)
                    .mask(content)
            )
    }
}

extension View {
    /// Applies a shimmering / glint placeholder effect that matches the view’s shape.
    func glintPlaceholder() -> some View {
        modifier(GlintPlaceholderModifier())
    }
}
