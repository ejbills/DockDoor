
import Defaults
import SwiftUI

struct MediaControlButton: View {
    let systemName: String
    let isTitle: Bool
    let action: () -> Void
    var buttonDimension: CGFloat = 28

    @AnimationsEnabled var showAnimations
    @State private var isHovering = false
    @State private var isPressed = false

    private var backgroundRadius: CGFloat { buttonDimension * 0.3 }

    private var label: String {
        switch systemName {
        case "play.fill": String(localized: "Play", comment: "Media control")
        case "pause.fill": String(localized: "Pause", comment: "Media control")
        case "backward.fill": String(localized: "Previous track", comment: "Media control")
        case "forward.fill": String(localized: "Next track", comment: "Media control")
        case "gobackward.15": String(localized: "Back 15 seconds", comment: "Media control")
        case "goforward.15": String(localized: "Forward 15 seconds", comment: "Media control")
        case let name where name.hasPrefix("quote.bubble"): String(localized: "Lyrics", comment: "Media control")
        default: ""
        }
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .symbolRenderingMode(.hierarchical)
                .font(isTitle ? .title : .body)
                .fontWeight(.semibold)
                .frame(width: buttonDimension, height: buttonDimension)
                .contentShape(RoundedRectangle(cornerRadius: backgroundRadius, style: .continuous))
                .symbolReplaceTransition()
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
        .background(
            RoundedRectangle(cornerRadius: backgroundRadius, style: .continuous)
                .fill(Color.primary.opacity(isHovering ? 0.06 : 0))
                .padding(-3)
        )
        .scaleEffect(isPressed ? 0.88 : 1.0)
        .opacity(isPressed ? 0.7 : 1.0)
        .onHover { hovering in
            withAnimation(showAnimations ? .easeOut(duration: 0.15) : nil) { isHovering = hovering }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        withAnimation(showAnimations ? .easeOut(duration: 0.08) : nil) { isPressed = true }
                    }
                }
                .onEnded { _ in
                    withAnimation(showAnimations ? .spring(response: 0.3, dampingFraction: 0.6) : nil) { isPressed = false }
                }
        )
    }
}
