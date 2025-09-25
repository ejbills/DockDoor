import SwiftUI

struct KeyHintRow: View {
    let keys: [String]
    let description: String
    let titleColor: Color
    let textColor: Color

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                ForEach(keys, id: \.self) { key in
                    KeyCap(label: key, titleColor: titleColor)
                }
            }
            Text(description)
                .font(.body)
                .foregroundStyle(textColor)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(keys.joined()) — \(description)"))
    }
}

struct HintRow: View {
    let symbol: String
    let description: String
    let titleColor: Color
    let textColor: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(titleColor)
            Text(description)
                .font(.body)
                .foregroundStyle(textColor)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(description)"))
    }
}

struct KeyCap: View {
    let label: String
    let titleColor: Color

    var body: some View {
        Text(label)
            .font(.headline)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(titleColor.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(titleColor.opacity(0.35), lineWidth: 1)
            )
            .foregroundStyle(titleColor)
    }
}
