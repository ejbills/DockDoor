import SwiftUI

struct BaseSettingsView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            content
                .globalPadding(20)
        }
        .frame(minWidth: 650, idealWidth: 700, maxWidth: .infinity,
               minHeight: 675, idealHeight: 700, maxHeight: 700)
    }
}
