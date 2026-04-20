import SwiftUI

struct BaseSettingsView<Content: View>: View {
    @Environment(\.settingsScrollTarget) private var scrollTarget
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                content
                    .padding(20)
            }
            .frame(minWidth: 650, idealWidth: 700, minHeight: 650)
            .onChange(of: scrollTarget) { target in
                guard let target else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(target, anchor: .center)
                    }
                }
            }
            .onAppear {
                guard let target = scrollTarget else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(target, anchor: .center)
                    }
                }
            }
        }
    }
}
