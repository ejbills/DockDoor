import Kroma
import SwiftUI

struct AccentButtonStyle: ButtonStyle {
    @State private var hovering = false
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                .blue.lighter(by: hovering && !configuration.isPressed ? 0.05 : 0),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .contentShape(Rectangle())
            .onHover { newHovering in
                hovering = newHovering
            }
            .foregroundStyle(.white)
            .font(.system(size: 14, weight: .medium))
    }
}
