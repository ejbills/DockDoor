import Defaults
import SwiftUI

struct PanelPresentationEffect: ViewModifier {
    let scaleAnchor: UnitPoint
    let animates: Bool

    @State private var presentActive = false
    @State private var opacityActive = false

    private static let duration: TimeInterval = 0.26

    static func shouldAnimate(_ animated: Bool) -> Bool {
        animated && Defaults[.showAnimations] && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(animates && !presentActive ? 0.62 : 1, anchor: scaleAnchor)
            .opacity(animates && !opacityActive ? 0 : 1)
            .onAppear {
                guard animates else { return }
                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: Self.duration * 0.54)) {
                        opacityActive = true
                    }
                    withAnimation(.timingCurve(0.2, 0.9, 0.3, 1.0, duration: Self.duration)) {
                        presentActive = true
                    }
                }
            }
    }
}

extension View {
    func panelPresentationEffect(dockPosition: DockPosition, animates: Bool) -> some View {
        modifier(PanelPresentationEffect(scaleAnchor: dockPosition.presentationAnchor, animates: animates))
    }
}

extension DockPosition {
    var presentationAnchor: UnitPoint {
        switch self {
        case .top: .top
        case .left: .leading
        case .right: .trailing
        default: .bottom
        }
    }
}
