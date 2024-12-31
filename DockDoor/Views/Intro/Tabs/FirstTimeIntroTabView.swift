import SwiftUI

struct FirstTimeIntroTabView: View {
    var nextTab: () -> Void
    @Binding var lightsOn: Bool
    @State private var phrasesSteps = 0
    @State private var timers = [Timer]()
    var body: some View {
        VStack(spacing: 24) {
            FirstTimeViewAppIcon(lightsOn: lightsOn, action: toggleAnimation)
            FirstTimeViewInstructionsView(nextTab: nextTab, step: phrasesSteps)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func toggleAnimation() {
        timers.forEach { $0.invalidate() }
        timers.removeAll()
        if !lightsOn {
            timers.append(timer(0.25) { _ in
                withAnimation(.smooth(extraBounce: 0.25)) { phrasesSteps = 1 }
                timers.append(timer(0.25) { _ in
                    withAnimation(.smooth(extraBounce: 0.25)) { phrasesSteps = 2 }
                    timers.append(timer(0.25) { _ in
                        withAnimation(.smooth(extraBounce: 0.25)) { phrasesSteps = 3 }
                    })
                })
            })
        } else {
            withAnimation(.smooth(extraBounce: 0.25)) { phrasesSteps = 0 }
        }
        withAnimation {
            lightsOn.toggle()
        }
    }
}
