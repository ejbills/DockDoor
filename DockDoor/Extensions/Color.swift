import SwiftUI

extension Color {
    /// Generates a range of lighter and darker variations of the base color.
    /// - Parameters:
    ///   - count: Total number of color variations to generate.
    /// - Returns: An array of `Color` from darker to lighter.
    func generateShades(count: Int) -> [Color] {
        guard count > 1 else { return [self] }

        var shades: [Color] = []
        let uiColor = NSColor(self)

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        // Adjust brightness from 80% to 120% of original value
        let minBrightness = max(0, brightness * 0.6)
        let maxBrightness = min(1, brightness * 1.4)

        for i in 0 ..< count {
            let factor = CGFloat(i) / CGFloat(count - 1)
            let adjustedBrightness = minBrightness + (maxBrightness - minBrightness) * factor
            let shade = Color(hue: hue, saturation: saturation, brightness: adjustedBrightness, opacity: Double(alpha))
            shades.append(shade)
        }

        return shades
    }
}
