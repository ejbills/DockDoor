import Defaults
import SwiftUI

struct DockStyleModifier: ViewModifier {
    let cornerRadius: Double
    let highlightColor: Color?
    let backgroundOpacity: CGFloat
    let frostedTranslucentLayer: Bool
    let variant: Int?

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    BlurView(variant: variant, frostedTranslucentLayer: frostedTranslucentLayer)
                        .opacity(backgroundOpacity)
                    if let hc = highlightColor {
                        FluidGradient(blobs: hc.generateShades(count: 3), highlights: hc.generateShades(count: 3), speed: 0.5, blur: 0.75)
                            .opacity(0.2 * backgroundOpacity)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.gray.opacity(0.19 * backgroundOpacity), lineWidth: 1.5)
                        .blendMode(.plusLighter)
                }
            }
            .padding(2)
    }
}

extension View {
    func dockStyle(cornerRadius: Double = Defaults[.uniformCardRadius] ? 26 : 8, highlightColor: Color? = nil, backgroundOpacity: CGFloat = 1.0, frostedTranslucentLayer: Bool = false, variant: Int? = 19) -> some View {
        modifier(DockStyleModifier(cornerRadius: cornerRadius, highlightColor: highlightColor, backgroundOpacity: backgroundOpacity, frostedTranslucentLayer: frostedTranslucentLayer, variant: variant))
    }

    func simpleBlurBackground(variant: Int = 18, cornerRadius: Double = Defaults[.uniformCardRadius] ? 20 : 0, strokeOpacity: Double = 0.1, strokeWidth: Double = 1.5) -> some View {
        background {
            BlurView(variant: variant)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(Color.primary.opacity(strokeOpacity), lineWidth: strokeWidth)
                )
        }
    }
}
