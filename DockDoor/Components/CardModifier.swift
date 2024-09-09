import SwiftUI

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(EdgeInsets(top: 12, leading: 16, bottom: 14, trailing: 16))
            .background(Color.gray.opacity(0.25))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .frame(maxWidth: 450, alignment: .leading)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }
}
