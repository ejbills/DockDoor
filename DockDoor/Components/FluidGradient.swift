import Defaults
import FluidGradient
import SwiftUI

func fluidGradient() -> some View {
    let gradientColorPalette = Defaults[.gradientColorPalette]
    return FluidGradient(
        blobs: gradientColorPalette.colors.map { Color(hex: $0) }.shuffled(),
        highlights: gradientColorPalette.colors.map { Color(hex: $0) }.shuffled(),
        speed: gradientColorPalette.speed,
        blur: gradientColorPalette.blur
    )
}

struct FluidGradientBorder: ViewModifier {
    let cornerRadius: CGFloat
    let lineWidth: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay(
                fluidGradient()
                    .mask(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(lineWidth: lineWidth)
                    )
            )
    }
}
