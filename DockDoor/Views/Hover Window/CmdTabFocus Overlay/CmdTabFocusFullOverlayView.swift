import Carbon
import Defaults
import SwiftUI

struct CmdTabFocusFullOverlayView: View {
    @Environment(\.colorScheme) private var colorScheme

    private var overlayColor: Color { colorScheme == .dark ? .black.opacity(0.4) : .white.opacity(0.4) }
    private var titleColor: Color { colorScheme == .dark ? .white : .black }
    private var textColor: Color { colorScheme == .dark ? .white.opacity(0.9) : .black.opacity(0.85) }

    var body: some View {
        ZStack {
            overlayColor
            VStack(alignment: .center, spacing: 14) {
                Text("Focus and use previews")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(titleColor)

                KeyHintRow(
                    keys: [
                        "⌘",
                        KeyboardLabel.localizedKey(for: Defaults[.cmdTabCycleKey]),
                    ],
                    description: "Cycle through previews (Shift to reverse)",
                    titleColor: titleColor,
                    textColor: textColor
                )

                Divider()
                    .overlay(titleColor.opacity(0.25))
                    .padding(.horizontal, 24)

                HintRow(symbol: "arrow.left.and.right", description: "Move between windows", titleColor: titleColor, textColor: textColor)
                HintRow(symbol: "arrow.down", description: "Clear focus", titleColor: titleColor, textColor: textColor)
            }
            .shadow(color: .black.opacity(0.2), radius: 2)
            .multilineTextAlignment(.center)
            .padding(.vertical, 20)
            .padding(.horizontal, 24)
        }
    }
}
