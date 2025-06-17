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
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            HStack(spacing: 8) {
                if !hideStatus {
                    if let customStatusView {
                        customStatusView
                    } else {
                        HStack(spacing: 4) {
                            Text(isGranted ? statusText : String(localized: "Not \(statusText.lowercased())"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(isGranted ? .green : .red)
                                .font(.callout)
                        }
                    }
                }

                if let action {
                    Button(action: action) {
                        Text(buttonText)
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(AccentButtonStyle(color: .accentColor, small: true))
                }
            }
        }
        .padding(12)
        .background(
            Color(NSColor.controlBackgroundColor).opacity(0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
