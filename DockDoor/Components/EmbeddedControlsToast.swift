import SwiftUI

struct EmbeddedControlsToast: View {
    let appType: String
    let onDismiss: () -> Void

    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.accentColor)
                .font(.caption)

            Text("Hide or minimize all application windows to access full \(appType)")
                .font(.caption)
                .fontWeight(.medium)

            Button("OK") {
                onDismiss()
            }
            .buttonStyle(AccentButtonStyle(small: true))
        }
        .materialPill()
        .scaleEffect(isVisible ? 1 : 0.8)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isVisible = true
            }
        }
    }
}
