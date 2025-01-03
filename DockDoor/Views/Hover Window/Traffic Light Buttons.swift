import SwiftUI

struct TrafficLightButtons: View {
    let windowInfo: WindowInfo
    let displayMode: TrafficLightButtonsVisibility
    let hoveringOverParentWindow: Bool
    let onWindowAction: (WindowAction) -> Void
    let pillStyling: Bool
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
        .simultaneousGesture(TapGesture())
        .onHover { isHovering in
            withAnimation(.snappy(duration: 0.175)) {
                self.isHovering = isHovering
            }
        }
        .if(pillStyling && opacity > 0) { view in
            view.materialPill()
        }
    }

    private var opacity: Double {
        switch displayMode {
        case .dimmedOnPreviewHover:
            (hoveringOverParentWindow && isHovering) ? 1.0 : 0.25
        case .fullOpacityOnPreviewHover:
            hoveringOverParentWindow ? 1 : 0
        case .alwaysVisible:
            1
        case .never:
            0
        }
    }

    private func buttonFor(action: WindowAction, symbol: String, color: Color, fillColor: Color) -> some View {
        ZStack {
            Image(systemName: "circle.fill")
                .foregroundStyle(.secondary)
            Image(systemName: "\(symbol).circle.fill")
        }
        .foregroundStyle(color, fillColor)
        .font(.system(size: 13))
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: 10, perform: {}, onPressingChanged: { pressing in
            if pressing {
                onWindowAction(action)
            }
        })
    }
}
