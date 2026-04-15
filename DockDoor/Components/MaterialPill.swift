import SwiftUI

struct MaterialPillStyle: ViewModifier {
    let backgroundColor: Color?
    let borderColor: Color?

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background {
                ZStack {
                    BlurView(variant: 18)

                    if let backgroundColor {
                        Capsule(style: .continuous)
                            .fill(backgroundColor.opacity(0.82))
                    }
                }
            }
            .clipShape(Capsule(style: .continuous))
            .borderedBackground(borderColor ?? .primary.opacity(0.1), lineWidth: 1.5, shape: Capsule(style: .continuous))
    }
}

extension View {
    func materialPill(backgroundColor: Color? = nil, borderColor: Color? = nil) -> some View {
        modifier(MaterialPillStyle(backgroundColor: backgroundColor, borderColor: borderColor))
    }
}
