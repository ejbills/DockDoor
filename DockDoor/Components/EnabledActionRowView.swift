import SwiftUI

struct EnabledActionRowView: View {
    var title: String
    var description: String
    var isGranted: Bool
    var iconName: String
    var action: (() -> Void)?
    var disableShine: Bool = false
    var buttonText: String = .init(localized: "Open Settings")
    var statusText: String = .init(localized: "Granted")
    var customStatusView: AnyView?
    var hideStatus: Bool = false

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
            if !hideStatus {
                if let customStatusView {
                    customStatusView
                } else {
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack {
                            Text(isGranted ? statusText : String(localized: "Not \(statusText.lowercased())"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(isGranted ? .green : .red)
                                .font(.system(size: 20))
                        }
                    }
                }
            }
        }
        .padding(EdgeInsets(top: 12, leading: 16, bottom: 14, trailing: 16))
        .background(
            Group {
                if disableShine {
                    Color.gray.opacity(0.25)
                } else {
                    CustomizableFluidGradientView().opacity(0.125)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            if let action {
                Button(action: action) {
                    Text(buttonText)
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.trailing, 16)
                .offset(y: 9)
                .buttonStyle(AccentButtonStyle(color: .accentColor, small: true))
            }
        }
    }
}
