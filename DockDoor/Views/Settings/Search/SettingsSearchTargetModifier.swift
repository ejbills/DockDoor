import SwiftUI

private struct SettingsScrollTargetKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    var settingsScrollTarget: String? {
        get { self[SettingsScrollTargetKey.self] }
        set { self[SettingsScrollTargetKey.self] = newValue }
    }
}

struct SettingsSearchTargetModifier: ViewModifier {
    let targetId: String
    @Environment(\.settingsScrollTarget) private var scrollTarget
    @State private var isHighlighted = false

    func body(content: Content) -> some View {
        content
            .id(targetId)
            .background {
                if isHighlighted {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.accentColor.opacity(0.25))
                        .padding(-6)
                        .transition(.opacity)
                }
            }
            .onChange(of: scrollTarget) { newTarget in flash(if: newTarget) }
            .onAppear { flash(if: scrollTarget) }
    }

    private func flash(if target: String?) {
        guard target == targetId else {
            if isHighlighted {
                withAnimation(.easeOut(duration: 0.3)) { isHighlighted = false }
            }
            return
        }
        withAnimation(.easeIn(duration: 0.2)) { isHighlighted = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.5)) { isHighlighted = false }
        }
    }
}

extension View {
    func settingsSearchTarget(_ id: String) -> some View {
        modifier(SettingsSearchTargetModifier(targetId: id))
    }
}
