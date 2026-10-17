import SwiftUI

/// Draws past the content by `negativePadding`. Selection hugs the card edge and the
/// active indicator sits inside it, so the two never cover each other.
struct PreviewCardChrome: View {
    let cornerRadius: Double
    let backgroundAppearance: BackgroundAppearance
    let isSelected: Bool
    let isActiveWindow: Bool
    let selectionTint: Color
    let selectionFillOpacity: Double
    let activeIndicatorColor: Color
    let showsBackground: Bool
    let negativePadding: CGFloat
    var paddedEdges: Edge.Set = .all

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        ZStack {
            if showsBackground {
                backgroundLayer
                rim
            }
            if isSelected {
                shape
                    .strokeBorder(selectionTint, lineWidth: 2.5)
            }
            if isActiveWindow {
                shape
                    .strokeBorder(activeIndicatorColor, lineWidth: 2)
                    .padding(3)
            }
        }
        .padding(paddedEdges, -negativePadding)
    }

    private var backgroundLayer: some View {
        BlurView(cornerRadius: cornerRadius, appearance: backgroundAppearance)
            .clipShape(shape)
            .overlay {
                if isSelected {
                    shape
                        .fill(selectionTint.opacity(selectionFillOpacity))
                }
            }
    }

    @ViewBuilder
    private var rim: some View {
        if #available(macOS 26.0, *), backgroundAppearance.usesModernGlass,
           let borderGlass = LiquidGlass.borderGlass(activeAppearance: backgroundAppearance.glassRefraction)
        {
            Color.clear
                .glassEffect(borderGlass, in: shape)
                .opacity(0.5)
                .allowsHitTesting(false)
        } else {
            shape
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1.75)
        }
    }
}
