import Defaults
import SwiftUI

struct CustomizableFluidGradientView: View {
    @Default(.gradientColorPalette) private var gradientColorPalette
    var body: some View {
        FluidGradient(
            blobs: gradientColorPalette.colors.map { Color(hex: $0) }.shuffled(),
            highlights: gradientColorPalette.colors.map { Color(hex: $0) }.shuffled(),
            speed: gradientColorPalette.speed,
            blur: gradientColorPalette.blur
        )
    }
}

struct FluidGradientBorder: ViewModifier {
    let cornerRadius: CGFloat
    let lineWidth: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay(
                CustomizableFluidGradientView()
                    .mask(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(lineWidth: lineWidth)
                    )
                    .allowsHitTesting(false)
            )
    }
}
