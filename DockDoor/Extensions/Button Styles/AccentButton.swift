import Kroma
import SwiftUI

struct AccentButtonStyle: ButtonStyle {
    var color: Color = .accentColor
    var small = false
    @State private var hovering = false
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .padding(.horizontal, small ? 12 : 16)
            .padding(.vertical, small ? 6 : 8)
            .background(
                color.lighter(by: hovering && !configuration.isPressed ? 0.05 : 0),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .contentShape(Rectangle())
            .onHover { newHovering in
                hovering = newHovering
            }
            .foregroundStyle(.white)
            .font(.system(size: small ? 13 : 14, weight: .medium))
    }
}
