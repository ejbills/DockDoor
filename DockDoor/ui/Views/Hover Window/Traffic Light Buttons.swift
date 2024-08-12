import SwiftUI

struct TrafficLightButtons: View {
    let window: Window
    let displayMode: TrafficLightButtonsVisibility
    let hoveringOverParentWindow: Bool
    let onAction: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6) {
            buttonFor(action: .quit, symbol: "power", color: Color(hex: "290133"), fillColor: .purple)
            buttonFor(action: .close, symbol: "xmark", color: Color(hex: "7e0609"), fillColor: .red)
            buttonFor(action: .minimize, symbol: "minus", color: Color(hex: "985712"), fillColor: .yellow)
            buttonFor(action: .toggleFullScreen, symbol: "arrow.up.left.and.arrow.down.right", color: Color(hex: "0d650d"), fillColor: .green)
        }
        .padding(4)
        .opacity(opacity)
        .allowsHitTesting(opacity != 0)
        .onHover { over in
            withAnimation(.snappy(duration: 0.175)) {
                isHovering = over
            }
        }
    }

    private var opacity: Double {
        switch displayMode {
        case .dimmedOnPreviewHover:
            return (hoveringOverParentWindow && isHovering) ? 1.0 : 0.25
        case .fullOpacityOnPreviewHover:
            return hoveringOverParentWindow ? 1 : 0
        case .alwaysVisible:
            return 1
        case .never:
            return 0
        }
    }

    private func buttonFor(action: WindowAction, symbol: String, color: Color, fillColor: Color) -> some View {
        Button(action: {
            performAction(action)
            onAction()
        }) {
            ZStack {
                Image(systemName: "circle.fill")
                    .foregroundStyle(.secondary)
                Image(systemName: "\(symbol).circle.fill")
            }
        }
        .buttonBorderShape(.roundedRectangle)
        .foregroundStyle(color, fillColor)
        .buttonStyle(.plain)
        .font(.system(size: 13))
    }

    private func performAction(_ action: WindowAction) {
        switch action {
        case .quit:
            window.quitApp(force: NSEvent.modifierFlags.contains(.option))
        case .close:
            window.close()
        case .minimize:
            window.toggleMinimize()
        case .toggleFullScreen:
            window.toggleFullScreen()
        }
    }

    private enum WindowAction {
        case quit, close, minimize, toggleFullScreen
    }
}
