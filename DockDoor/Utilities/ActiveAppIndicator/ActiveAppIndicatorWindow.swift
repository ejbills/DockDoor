import Cocoa
import Defaults
import SwiftUI

struct DockAppDot: Identifiable, Equatable {
    let id: pid_t
    let center: CGPoint
    let size: CGFloat
    let hasWindows: Bool
    let isFrontmost: Bool
}

final class ActiveAppIndicatorModel: ObservableObject {
    @Published var dots: [DockAppDot] = []
}

/// A borderless window that displays the indicator line next to the active dock app.
final class ActiveAppIndicatorWindow: NSPanel {
    private var indicatorView: NSHostingView<ActiveAppIndicatorView>?
    private let model = ActiveAppIndicatorModel()

    init() {
        let styleMask: NSWindow.StyleMask = [
            .nonactivatingPanel, .fullSizeContentView, .borderless,
        ]
        super.init(
            contentRect: .zero,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        setupWindow()
    }

    private func setupWindow() {
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovableByWindowBackground = false
        collectionBehavior = [
            .canJoinAllSpaces, .transient, .fullScreenAuxiliary, .ignoresCycle,
        ]
        hidesOnDeactivate = false
        ignoresMouseEvents = true
        animationBehavior = .none

        let view = ActiveAppIndicatorView(model: model)
        let hostingView = NSHostingView(rootView: view)
        contentView = hostingView
        indicatorView = hostingView
    }

    func updateDots(_ dots: [DockAppDot]) {
        model.dots = dots
    }
}

/// The SwiftUI view that draws the indicator line.
struct ActiveAppIndicatorView: View {
    @ObservedObject var model: ActiveAppIndicatorModel
    @Default(.activeAppIndicatorColor) var indicatorColor
    @Default(.activeAppIndicatorStyle) var indicatorStyle

    var body: some View {
        switch indicatorStyle {
        case .bar:
            Capsule()
                .fill(indicatorColor)
        case .runningAppDots:
            ZStack(alignment: .topLeading) {
                Color.clear
                ForEach(model.dots) { dot in
                    appDot(dot)
                        .position(dot.center)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: model.dots)
        }
    }

    private func appDot(_ dot: DockAppDot) -> some View {
        Circle()
            .fill(dotColor(for: dot))
            .overlay(Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5))
            .frame(width: dot.size, height: dot.size)
    }

    private func dotColor(for dot: DockAppDot) -> Color {
        if dot.isFrontmost {
            indicatorColor
        } else if dot.hasWindows {
            dimmedIndicatorColor
        } else {
            .black
        }
    }

    private var dimmedIndicatorColor: Color {
        guard let blended = NSColor(indicatorColor).usingColorSpace(.sRGB)?
            .blended(withFraction: 0.45, of: .darkGray)
        else { return indicatorColor }
        return Color(nsColor: blended)
    }
}
