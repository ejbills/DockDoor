import SwiftUI

struct PermissionRowView: View {
    var title: String
    var description: String
    var isGranted: Bool
    var iconName: String
    var disableShine = false
    var action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 24))
                .foregroundColor(.accentColor)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                HStack {
                    Text(isGranted ? "Granted" : "Not granted")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isGranted ? .green : .red)
                        .font(.system(size: 20))
                }
            }
        }
        .padding(EdgeInsets(top: 12, leading: 16, bottom: 14, trailing: 16))
        .background(FluidGradientView().opacity(isGranted && !disableShine ? 0.125 : 0))
        .background((isGranted ? Color.green : .primary).opacity(isGranted ? 0.15 : 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            Button(action: action) {
                Text("Open Settings")
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.trailing, 16)
            .offset(y: 9)
            .buttonStyle(AccentButtonStyle(color: .accentColor, small: true))
        }
    }
}
