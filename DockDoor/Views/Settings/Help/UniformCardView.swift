import SwiftUI

struct UniformCardView: View {
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    let buttonTitle: LocalizedStringKey
    let buttonLink: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button(action: {
                    if let url = URL(string: buttonLink) {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Text(buttonTitle)
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(AccentButtonStyle(color: .accentColor, small: true))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .dockStyle(cornerRadius: 16)
        .modifier(FluidGradientBorder(cornerRadius: 18, lineWidth: 2))
    }
}
