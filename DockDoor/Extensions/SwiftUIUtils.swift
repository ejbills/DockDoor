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
