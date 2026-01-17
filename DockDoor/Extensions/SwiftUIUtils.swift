import AppKit
import Defaults
import SwiftUI

struct ViewSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = value + nextValue()
    }
}

func doAfter(_ seconds: Double = 0, action: @escaping () -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: action)
}

func timer(_ seconds: Double = 0, action: @escaping (Timer) -> Void) -> Timer {
    Timer.scheduledTimer(withTimeInterval: seconds, repeats: false, block: action)
}

/// Runs an animation block respecting the user's showAnimations preference.
/// If animations are disabled, executes the block immediately without animation.
func animateWithUserPreference(
    duration: TimeInterval = 0.2,
    timingFunction: CAMediaTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut),
    changes: @escaping () -> Void,
    completion: (() -> Void)? = nil
) {
    if Defaults[.showAnimations] {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = timingFunction
            changes()
        } completionHandler: {
            completion?()
        }
    } else {
        changes()
        completion?()
    }
}
