
import Defaults
import SwiftUI

struct MediaControlButton: View {
    let systemName: String
    let isTitle: Bool
    let action: () -> Void
    var buttonDimension: CGFloat = 28

    @Default(.showAnimations) var showAnimations
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .symbolRenderingMode(.hierarchical)
                .font(isTitle ? .title : .body)
                .fontWeight(.semibold)
                .frame(width: buttonDimension, height: buttonDimension)
                .contentShape(Circle())
                .symbolReplaceTransition()
        }
        .buttonStyle(.plain)
        .background(
            Circle()
                .fill(Color.primary.opacity(isHovering ? 0.12 : 0))
                .frame(width: buttonDimension + 8, height: buttonDimension + 8)
        )
        .onHover { hovering in
            withAnimation(showAnimations ? .easeInOut(duration: 0.10) : nil) { isHovering = hovering }
        }
    }
}
