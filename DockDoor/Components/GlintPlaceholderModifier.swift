import SwiftUI

private struct GlintPlaceholderModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .redacted(reason: .placeholder)
            .overlay(
                CustomizableFluidGradientView()
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
