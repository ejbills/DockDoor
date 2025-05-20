import AVFoundation
import Pow
import SwiftUI

struct FirstTimeViewAppIcon: View {
    var lightsOn: Bool
    var action: () -> Void = {}

    @State private var clicking = false
    @State private var rotating: Bool? = nil
    @State private var rotating2: Bool? = nil
    @State private var rotatingTimer: Timer? = nil
    @State private var hovering = false
    @State private var clickDownSoundPlayer = try! AVAudioPlayer(contentsOf: Bundle.main.url(forResource: "mouse-down", withExtension: "mp3")!)
    @State private var clickUpSoundPlayer = try! AVAudioPlayer(contentsOf: Bundle.main.url(forResource: "mouse-up", withExtension: "mp3")!)

    var body: some View {
        let rotationDegrees: Double = 7
        Button(action: action) {
            TimelineView(.animation(minimumInterval: 0.15)) { ctx in
                let zzz = lightsOn ? "1" : ctx.date.description
                Image(systemName: lightsOn ? "face.dashed.fill" : "faceid")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 140, height: 140)
                    .brightness(hovering ? lightsOn ? 0.05 : 0.125 : 0)
                    .shadow(color: .black.opacity(hovering ? 0.5 : 0.25), radius: hovering ? 32 : 16, y: hovering ? 24 : 12)
                    .contentTransition(.identity)
                    .overlay {
                        CustomizableFluidGradientView().opacity(hovering ? lightsOn ? 0 : 0.75 : 0)
                            .blendMode(.overlay).clipShape(RoundedRectangle(cornerRadius: 31))
                    }
                    .scaleEffect(iconScale)
                    .rotation3DEffect(
                        .degrees(rotating == nil ? 0 : rotating! ? rotationDegrees : -rotationDegrees),
                        axis: (x: 1, y: 0, z: 0)
                    )
                    .rotation3DEffect(
                        .degrees(rotating2 == nil ? 0 : rotating2! ? rotationDegrees / 2 : -rotationDegrees / 2),
                        axis: (x: 0, y: 0, z: 1)
                    )
                    .changeEffect(
                        .rise(origin: UnitPoint(x: 0.5, y: 0.2)) {
                            Text("Z")
                        },
                        value: zzz
                    )
                    .onHover(perform: onHover)
            }
        }
        .onLongPressGesture(minimumDuration: 300, maximumDistance: 10, perform: {}) { newClicking in
            withAnimation(.smooth(extraBounce: 0.25)) {
                clicking = newClicking
            }
        }
        .foregroundStyle(.white)
        .buttonStyle(NoBtnStyle())
        .zIndex(1)
        .onChange(of: clicking) { new in
            doAfter(new ? 0 : 0.1) {
                if new {
                    clickDownSoundPlayer.play()
                } else {
                    clickUpSoundPlayer.play()
                }
            }
        }
        .onAppear {
            clickDownSoundPlayer.volume = 0.25
            clickUpSoundPlayer.volume = 0.25
            clickDownSoundPlayer.prepareToPlay()
            clickUpSoundPlayer.prepareToPlay()
        }
    }

    var iconScale: Double {
        if clicking {
            if lightsOn {
                0.935
            } else {
                0.8
            }
        } else {
            if hovering {
                if lightsOn {
                    1
                } else {
                    0.85
                }
            } else {
                if lightsOn {
                    0.9
                } else {
                    0.8
                }
            }
        }
    }

    func onHover(_ newHovering: Bool) {
        rotatingTimer?.invalidate()
        if newHovering {
            withAnimation(.easeInOut(duration: 1)) {
                rotating = false
                rotating2 = false
            }
            rotatingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    rotating = true
                }
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true).delay(1)) {
                    rotating2 = true
                }
            }
        } else {
            withAnimation(.spring) {
                rotating = nil
            }
            withAnimation(.spring) {
                rotating2 = nil
            }
        }
        withAnimation(.smooth(extraBounce: 0.1)) {
            hovering = newHovering
        }
    }
}

#Preview {
    FirstTimeViewAppIcon(lightsOn: true)
}
