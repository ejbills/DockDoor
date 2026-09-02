import SwiftUI

extension Color {
    /// Returns a lighter version of the color by blending with white
    func lighter(by amount: CGFloat = 0.2) -> Color {
        let nsColor = NSColor(self)
        guard let blended = nsColor.blended(withFraction: amount, of: .white) else {
            return self
        }
        return Color(nsColor: blended)
    }

    /// Returns a darker version of the color by blending with black
    func darker(by amount: CGFloat = 0.2) -> Color {
        let nsColor = NSColor(self)
        guard let blended = nsColor.blended(withFraction: amount, of: .black) else {
            return self
        }
        return Color(nsColor: blended)
    }

    func shaded(by delta: Double) -> Color {
        guard let resolved = NSColor(self).usingColorSpace(.sRGB) else { return self }
        let red = Double(resolved.redComponent)
        let green = Double(resolved.greenComponent)
        let blue = Double(resolved.blueComponent)
        let highest = max(red, green, blue)

        func shift(_ channel: Double) -> Double {
            min(1, max(0, channel + (highest - channel) * delta))
        }

        return Color(.sRGB, red: shift(red), green: shift(green), blue: shift(blue), opacity: Double(resolved.alphaComponent))
    }

    /// Generates a range of lighter and darker variations of the base color
    func generateShades(count: Int) -> [Color] {
        guard count > 1 else { return [self] }

        var shades: [Color] = []
        for i in 0 ..< count {
            let factor = CGFloat(i) / CGFloat(count - 1)
            let adjustment = (factor - 0.5) * 1.2
            if adjustment < 0 {
                shades.append(darker(by: -adjustment))
            } else {
                shades.append(lighter(by: adjustment))
            }
        }
        return shades
    }
}
