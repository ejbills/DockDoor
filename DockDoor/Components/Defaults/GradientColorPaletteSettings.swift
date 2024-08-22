import SwiftUI

struct GradientColorPaletteSettings: Preferences {
    var blobs: [Color] = [.purple, .blue, .green, .yellow, .red, .purple]
    var highlights: [Color] = [.red, .orange, .pink, .blue, .purple]
    var speed = 0.45
    var blur = 0.75
}
