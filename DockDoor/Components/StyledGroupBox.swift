import SwiftUI

struct StyledGroupBox<Content: View>: View {
    let label: LocalizedStringKey
    let content: Content

    init(label: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    // Add convenience init for string literals
    init(_ label: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.headline)
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
