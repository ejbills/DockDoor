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
    let backgroundAppearance: BackgroundAppearance
    let cornerRadius: Double
    let highlightColor: Color?
    let backgroundOpacity: CGFloat
    let outerPadding: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    BlurView(cornerRadius: cornerRadius, appearance: backgroundAppearance)
                        .borderedBackground(
                            .white.opacity(backgroundAppearance.borderOpacity),
                            lineWidth: backgroundAppearance.borderWidth,
                            shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        )
                        .opacity(backgroundOpacity)
                    if let hc = highlightColor {
                        FluidGradient(blobs: hc.generateShades(count: 3), highlights: hc.generateShades(count: 3), speed: 0.5, blur: 0.75)
                            .opacity(0.2 * backgroundOpacity)
                    }
                }
            }
            .padding(outerPadding)
    }
}

extension View {
    func dockStyle(
        backgroundAppearance: BackgroundAppearance,
        cornerRadius: Double = CardRadius.container,
        highlightColor: Color? = nil,
        backgroundOpacity: CGFloat = 1.0,
        outerPadding: CGFloat = HoverContainerPadding.dockStyleOuter
    ) -> some View {
        modifier(DockStyleModifier(
            backgroundAppearance: backgroundAppearance,
            cornerRadius: cornerRadius,
            highlightColor: highlightColor,
            backgroundOpacity: backgroundOpacity,
            outerPadding: outerPadding
        ))
    }
}
