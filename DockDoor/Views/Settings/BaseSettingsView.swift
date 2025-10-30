import SwiftUI

struct BaseSettingsView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            content
                .padding(20)
        }
        .frame(minWidth: 650, idealWidth: 700, maxWidth: .infinity,
               minHeight: 500, idealHeight: 550, maxHeight: .infinity)
    }
}
