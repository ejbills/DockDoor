import Defaults
import SwiftUI

struct DockStyleModifier: ViewModifier {
    let cornerRadius: Double
    let highlightColor: Color?
    let backgroundOpacity: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    BlurView(variant: 19)
                        .opacity(backgroundOpacity)
                    if let hc = highlightColor {
                        FluidGradient(blobs: hc.generateShades(count: 3), highlights: hc.generateShades(count: 3), speed: 0.5, blur: 0.75)
                            .opacity(0.2 * backgroundOpacity)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.gray.opacity(0.19 * backgroundOpacity), lineWidth: 1.5)
                        .blendMode(.plusLighter)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.1 * backgroundOpacity), lineWidth: 0.5)
                }
            }
            .padding(2)
    }
}

extension View {
    func dockStyle(cornerRadius: Double = Defaults[.uniformCardRadius] ? 26 : 8, highlightColor: Color? = nil, backgroundOpacity: CGFloat = 1.0) -> some View {
        modifier(DockStyleModifier(cornerRadius: cornerRadius, highlightColor: highlightColor, backgroundOpacity: backgroundOpacity))
    }
}
