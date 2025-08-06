import SwiftUI
import Defaults

struct HiddenModifier: ViewModifier {
    let isHidden: Bool
    @Default(.unselectedContentOpacity) var unselectedContentOpacity
    
    func body(content: Content) -> some View {
        content
            .opacity(isHidden ? unselectedContentOpacity : 1)
    }
}

extension View {
    func markHidden(isHidden: Bool) -> some View {
        modifier(HiddenModifier(isHidden: isHidden))
    }
}
