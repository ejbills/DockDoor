import SwiftUI

struct DockStyleModifier: ViewModifier {
    let cornerRadius: Double

    func body(content: Content) -> some View {
        content
            .background {
                BlurView()
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(.dockInnerDarkBorder.opacity(0.39), lineWidth: 1)
                            .blendMode(.plusLighter)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                    }
            }
            .padding(2)
    }
}

extension View {
    func dockStyle(cornerRadius: Double = 19) -> some View {
        modifier(DockStyleModifier(cornerRadius: cornerRadius))
    }
}
