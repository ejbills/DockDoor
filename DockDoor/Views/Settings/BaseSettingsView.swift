import SwiftUI

struct BaseSettingsView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            content
                .padding(20) // Apply padding to the content itself inside the ScrollView
        }
        // This frame makes the content area of each tab uniform.
        // It allows the width to expand if the window is wider, but fixes the max height.
        .frame(minWidth: 650, idealWidth: 700, maxWidth: .infinity,
               minHeight: 500, idealHeight: 550, maxHeight: 550)
    }
}
