import Defaults
import SwiftUI

enum CardRadius {
    static let base: Double = 20
    static let innerPadding: Double = 6
    static let outerPadding: Double = 20
    static let fallback: Double = 8

    static func outer(for padding: Double) -> Double {
        Defaults[.uniformCardRadius] ? base + (padding * Defaults[.globalPaddingMultiplier]) : fallback
    }

    static var inner: Double { outer(for: innerPadding) }
    static var container: Double { outer(for: outerPadding) }
    static var image: Double { max(fallback, inner - innerPadding) }
}

struct DockStyleModifier: ViewModifier {
    let cornerRadius: Double
    let highlightColor: Color?
    let backgroundOpacity: CGFloat
    let frostedTranslucentLayer: Bool
    let variant: Int?
    let outerPadding: CGFloat

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
                .borderedBackground(.primary.opacity(0.19 * backgroundOpacity), lineWidth: 1.75, cornerRadius: cornerRadius)
            }
            .padding(outerPadding)
    }
}

extension View {
    func dockStyle(cornerRadius: Double = CardRadius.container, highlightColor: Color? = nil, backgroundOpacity: CGFloat = 1.0, frostedTranslucentLayer: Bool = false, variant: Int? = 19, outerPadding: CGFloat = 2) -> some View {
        modifier(DockStyleModifier(cornerRadius: cornerRadius, highlightColor: highlightColor, backgroundOpacity: backgroundOpacity, frostedTranslucentLayer: frostedTranslucentLayer, variant: variant, outerPadding: outerPadding))
    }
}
