import SwiftUI

struct SpaceNumberBadge: View {
    let number: Int
    let font: Font
    let backgroundAppearance: BackgroundAppearance

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "rectangle.on.rectangle")
                .imageScale(.small)
                .foregroundStyle(.secondary)
            Text(number, format: .number)
                .monospacedDigit()
        }
        .font(font)
        .fixedSize()
        .materialPill(backgroundAppearance: backgroundAppearance)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Desktop \(number)", comment: "Accessibility label for the badge showing which Space a window is on"))
    }
}
