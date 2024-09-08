
import SwiftUI

struct FirstTimeView: View {
    static let transition: AnyTransition = .offset(y: 24).combined(with: .opacity)
    @State private var phrasesSteps = 0
    @State private var lightsOn = false
    @State private var timers = [Timer]()

    var body: some View {
        NavigationStack {
            ZStack {
                HStack {
                    VStack(spacing: 24) {
                        FirstTimeViewAppIcon(lightsOn: lightsOn, action: toggleAnimation)
                        VStack(spacing: 8) {
                            if phrasesSteps >= 1 {
                                Text("Welcome to DockDoor!")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .transition(Self.transition)
                            }
                            if phrasesSteps >= 2 {
                                Text("Enhance your dock experience!")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                                    .transition(Self.transition)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .scaleEffect(1)
                        if phrasesSteps >= 3 {
                            NavigationLink(destination: PermissionsSettingsView(), label: {
                                Text("Get Started")
                            })
                            .buttonStyle(AccentButtonStyle())
                            .transition(Self.transition)
                        }
                    }
                    .padding()
                }
            }
            .padding(.bottom, 51) // To compensate navbar
            .frame(width: 600, height: 320)
            .background {
                FluidGradientView().opacity(lightsOn ? 0.125 : 0)
                    .ignoresSafeArea(.all)
            }
            .background {
                BlurView()
                    .ignoresSafeArea(.all)
            }
        }
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        FirstTimeView()
    }
}
