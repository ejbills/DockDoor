import SwiftUI

struct MaterialPillStyle: ViewModifier {
    let backgroundAppearance: BackgroundAppearance?
    let backgroundColor: Color?
    let borderColor: Color?

    init(backgroundAppearance: BackgroundAppearance) {
        self.backgroundAppearance = backgroundAppearance
        self.backgroundColor = nil
        self.borderColor = nil
    }

    init(backgroundColor: Color? = nil, borderColor: Color? = nil) {
        self.backgroundAppearance = nil
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
    }

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background {
                if let appearance = backgroundAppearance {
                    BlurView(appearance: appearance)
                } else {
                    ZStack {
                        BlurView(appearance: BackgroundAppearance.resolve())

                        if let backgroundColor = backgroundColor {
                            Capsule(style: .continuous)
                                .fill(backgroundColor.opacity(0.82))
                        }
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

    func materialPill(backgroundAppearance: BackgroundAppearance) -> some View {
        modifier(MaterialPillStyle(backgroundAppearance: backgroundAppearance))
    }
}
