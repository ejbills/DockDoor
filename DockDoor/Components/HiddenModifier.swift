import SwiftUI

struct HiddenModifier: ViewModifier {
    let isHidden: Bool
    func body(content: Content) -> some View {
        content
            .opacity(isHidden ? 0.55 : 1)
    }
}

extension View {
    func markHidden(isHidden: Bool) -> some View {
        modifier(HiddenModifier(isHidden: isHidden))
    }
}
