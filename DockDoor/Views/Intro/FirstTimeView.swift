import SwiftUI

struct FirstTimeView: View {
    static let transition: AnyTransition = .offset(y: 24).combined(with: .opacity)
    @State private var tabIndex = 0

    var body: some View {
        ZStack {
            Group {
                switch tabIndex {
                case 0: FirstTimeIntroTabView(nextTab: nextTab)
                case 1: FirstTimePermissionsTabView(nextTab: nextTab)
                case 2: FirstTimeCongratsTabView(nextTab: nextTab)
                default: EmptyView()
                }
            }
            .transition(.asymmetric(insertion: .offset(x: 600), removal: .offset(x: -600)).combined(with: .opacity))
        }
        .padding(.bottom, 51) // To compensate navbar
        .frame(width: 600, height: 320)
        .background {
            CustomizableFluidGradientView()
                .opacity(tabIndex == 0 ? 0.15 : 0)
                .animation(.easeInOut(duration: 0.4), value: tabIndex)
                .ignoresSafeArea(.all)
        }
        .background {
            BlurView()
                .ignoresSafeArea(.all)
        }
    }

    func nextTab() {
        let tabsCount = 3
        if tabIndex < (tabsCount - 1) {
            withAnimation(.smooth(extraBounce: 0.15)) {
                tabIndex += 1
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        FirstTimeView()
    }
}
