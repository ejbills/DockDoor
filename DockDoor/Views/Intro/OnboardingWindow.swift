import AppKit
import AVFoundation
import SwiftUI

/// Fullscreen cinematic overlay that fades in/out cleanly
final class CinematicOverlay: NSPanel {
    private var onComplete: (() -> Void)?

    init(screen: NSScreen, onComplete: @escaping () -> Void) {
        self.onComplete = onComplete

        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .screenSaver
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        alphaValue = 0

        setupContent()
    }

    private func setupContent() {
        let view = CinematicView { [weak self] in
            self?.fadeOutAndComplete()
        }

        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = contentRect(forFrameRect: frame)
        hostingView.autoresizingMask = [.width, .height]
        contentView = hostingView
    }

    func fadeIn() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.5
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1
        }
    }

    private func fadeOutAndComplete() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.4
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 0
        } completionHandler: { [weak self] in
            self?.onComplete?()
            self?.close()
        }
    }
}

// MARK: - Cinematic View

private struct CinematicView: View {
    let onComplete: () -> Void

    @State private var backgroundOpacity: CGFloat = 0
    @State private var ambientOpacity: CGFloat = 0
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: CGFloat = 0
    @State private var titleOpacity: CGFloat = 0
    @State private var taglineOpacity: CGFloat = 0
    @State private var audioPlayer: AVAudioPlayer?

    var body: some View {
        ZStack {
            ZStack {
                Color.black.opacity(0.75)
                CustomizableFluidGradientView()
                    .opacity(0.2)
            }
            .opacity(backgroundOpacity)

            ZStack {
                ambientGlow
                    .opacity(ambientOpacity)

                VStack(spacing: 2) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 140, height: 140)
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                        .shadow(color: .black.opacity(0.4), radius: 24, y: 8)

                    Text("DockDoor")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
                        .opacity(titleOpacity)

                    Text("Window previews, supercharged.")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .opacity(taglineOpacity)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            startRevealSequence()
        }
    }

    private var ambientGlow: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.02),
                            Color.clear,
                        ],
                        center: .center,
                        startRadius: 40,
                        endRadius: 280
                    )
                )
                .frame(width: 560, height: 560)
                .blur(radius: 60)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color.white.opacity(0.04),
                            Color.clear,
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 160
                    )
                )
                .frame(width: 320, height: 320)
                .blur(radius: 40)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.05),
                            Color.clear,
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)
                .blur(radius: 25)
        }
    }

    private func startRevealSequence() {
        if let url = Bundle.main.url(forResource: "Glow", withExtension: "wav") {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.volume = 0
                audioPlayer?.play()
                fadeAudioIn()
            } catch {
                print("Failed to play intro sound: \(error)")
            }
        }

        withAnimation(.easeOut(duration: 0.5)) {
            backgroundOpacity = 1.0
        }

        doAfter(0.3) {
            withAnimation(.easeOut(duration: 0.8)) {
                ambientOpacity = 1.0
            }
        }

        doAfter(0.5) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
        }

        doAfter(1.0) {
            withAnimation(.easeOut(duration: 0.4)) {
                titleOpacity = 1.0
            }
        }

        doAfter(1.4) {
            withAnimation(.easeOut(duration: 0.4)) {
                taglineOpacity = 1.0
            }
        }

        doAfter(3.5) {
            fadeAudioOut()

            withAnimation(.easeOut(duration: 0.3)) {
                ambientOpacity = 0
                logoOpacity = 0
                titleOpacity = 0
                taglineOpacity = 0
                backgroundOpacity = 0
            }

            doAfter(0.35) {
                onComplete()
            }
        }
    }

    private func fadeAudioIn() {
        let targetVolume: Float = 0.5
        let fadeDuration: TimeInterval = 0.5
        let steps = 20
        let stepDuration = fadeDuration / Double(steps)
        let volumeStep = targetVolume / Float(steps)

        for i in 1 ... steps {
            doAfter(stepDuration * Double(i)) { [weak audioPlayer] in
                audioPlayer?.volume = volumeStep * Float(i)
            }
        }
    }

    private func fadeAudioOut() {
        guard let player = audioPlayer else { return }
        let startVolume = player.volume
        let fadeDuration: TimeInterval = 0.5
        let steps = 20
        let stepDuration = fadeDuration / Double(steps)
        let volumeStep = startVolume / Float(steps)

        for i in 1 ... steps {
            doAfter(stepDuration * Double(i)) { [weak audioPlayer] in
                audioPlayer?.volume = startVolume - (volumeStep * Float(i))
            }
        }

        doAfter(fadeDuration) { [weak audioPlayer] in
            audioPlayer?.stop()
        }
    }
}
