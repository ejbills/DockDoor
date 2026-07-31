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

    static func switcherToolbarHorizontalPadding(uniformCardRadius: Bool) -> CGFloat {
        guard uniformCardRadius else { return 0 }
        return CGFloat(innerPadding / 2)
    }
}

struct DockStyleModifier: ViewModifier {
    let backgroundAppearance: BackgroundAppearance
    let cornerRadius: Double
    let highlightColor: Color?
    let backgroundOpacity: CGFloat
    let outerPadding: CGFloat

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    glassBackground
                    if let hc = highlightColor {
                        FluidGradient(blobs: hc.generateShades(count: 3), highlights: hc.generateShades(count: 3), speed: 0.5, blur: 0.75)
                            .opacity(0.2 * backgroundOpacity)
                    }
                }
                .clipShape(shape)
            }
            .padding(outerPadding)
    }

    /// The synthetic blur variant relies on the glass shader's own edge
    /// refraction as its border, so it skips `borderedBackground` (which
    /// insets the content and leaves an un-blurred gap) and uses an overlay
    /// stroke instead.
    @ViewBuilder
    private var glassBackground: some View {
        if backgroundAppearance.usesSyntheticBlur {
            BlurView(cornerRadius: cornerRadius, appearance: backgroundAppearance)
                .overlay {
                    shape.strokeBorder(
                        glassBorderGradient(opacity: backgroundAppearance.borderOpacity),
                        lineWidth: backgroundAppearance.borderWidth
                    )
                }
                .opacity(backgroundOpacity)
        } else {
            BlurView(cornerRadius: cornerRadius, appearance: backgroundAppearance)
                .borderedBackground(
                    glassBorderGradient(opacity: backgroundAppearance.borderOpacity),
                    lineWidth: backgroundAppearance.borderWidth,
                    shape: shape
                )
                .opacity(backgroundOpacity)
        }
    }
}

// Directional rim-light stroke that reads as lit glass rather than a flat
// outline. Stops match Docky's dock chrome at the default border opacity and
// scale together as the user's borderOpacity knob changes.
private func glassBorderGradient(opacity: CGFloat) -> LinearGradient {
    let scale = opacity / 0.15
    return LinearGradient(
        colors: [
            .white.opacity(0.35 * scale),
            .white.opacity(0.12 * scale),
            .white.opacity(0.05 * scale),
            .white.opacity(0.12 * scale),
            .white.opacity(0.28 * scale),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
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
