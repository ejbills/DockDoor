import SwiftUI

struct TrafficLightButtons: View {
    let windowInfo: WindowInfo
    let displayMode: TrafficLightButtonsVisibility
    let hoveringOverParentWindow: Bool
    let onWindowAction: (WindowAction) -> Void

    @State private var isHovering = false
    @State private var hoveredButton: WindowAction? = nil

    private let buttonSize: CGFloat = 12
    private let spacing: CGFloat = 8

    private struct TrafficButton: Identifiable {
        let id: WindowAction
        let color: Color
        let symbol: String
    }

    private let buttons: [TrafficButton] = [
        TrafficButton(id: .close, color: Color(red: 1, green: 0.33, blue: 0.33), symbol: "xmark"),
        TrafficButton(id: .minimize, color: Color(red: 1, green: 0.83, blue: 0.33), symbol: "minus"),
        TrafficButton(id: .toggleFullScreen, color: Color(red: 0.33, green: 0.96, blue: 0.33), symbol: "arrow.up.left.and.arrow.down.right"),
    ]

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(buttons) { button in
                trafficLightButton(
                    action: button.id,
                    baseColor: button.color,
                    symbol: button.symbol
                )
            }
        }
        .padding(6)
        .opacity(opacity)
        .allowsHitTesting(opacity != 0)
        .onHover { isHovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                self.isHovering = isHovering
            }
        }
    }

    private func trafficLightButton(action: WindowAction, baseColor: Color, symbol: String) -> some View {
        let isHovered = hoveredButton == action

        return Button(action: { onWindowAction(action) }) {
            ZStack {
                // Base circle
                Circle()
                    .fill(baseColor.opacity(shouldShowSymbols ? 0.8 : 1))
                    .overlay(
                        Circle()
                            .strokeBorder(.black.opacity(0.2), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 0.5, y: 0.5)

                // Symbol
                if shouldShowSymbols {
                    Image(systemName: symbol)
                        .font(.system(size: buttonSize * 0.6, weight: .bold))
                        .foregroundColor(.black.opacity(0.5))
                        .opacity(isHovered ? 1 : 0)
                        .animation(.easeInOut(duration: 0.2), value: isHovered)
                }
            }
            .frame(width: buttonSize, height: buttonSize)
            .contentShape(Circle())
        }
        .buttonStyle(TrafficLightButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                hoveredButton = hovering ? action : nil
            }
        }
    }

    private var shouldShowSymbols: Bool {
        isHovering && hoveringOverParentWindow
    }

    private var opacity: Double {
        switch displayMode {
        case .dimmedOnPreviewHover:
            (hoveringOverParentWindow && isHovering) ? 1.0 : 0.6
        case .fullOpacityOnPreviewHover:
            hoveringOverParentWindow ? 1.0 : 0.0
        case .alwaysVisible:
            1.0
        case .never:
            0.0
        }
    }
}

struct TrafficLightButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
