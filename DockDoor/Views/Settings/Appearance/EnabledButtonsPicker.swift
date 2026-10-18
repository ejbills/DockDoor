import SwiftUI

struct EnabledButtonsPicker: View {
    @Binding var enabledButtons: Set<WindowAction>
    var onAllRemoved: () -> Void

    private static let actions: [(WindowAction, String)] = [
        (.quit, String(localized: "Quit")),
        (.close, String(localized: "Close")),
        (.minimize, String(localized: "Minimize")),
        (.toggleFullScreen, String(localized: "Fullscreen")),
        (.maximize, String(localized: "Maximize")),
        (.bringToCurrentSpace, String(localized: "Bring to Current Space")),
        (.openNewWindow, String(localized: "New Window")),
    ]

    private var summary: String {
        let names = Self.actions.filter { enabledButtons.contains($0.0) }.map(\.1)
        if names.count <= 3 {
            return names.formatted(.list(type: .and, width: .narrow))
        }
        return String(localized: "\(names.count) of \(Self.actions.count)", comment: "Number of enabled traffic light buttons, e.g. 4 of 7")
    }

    var body: some View {
        LabeledContent("Enabled buttons") {
            Menu {
                ForEach(Self.actions, id: \.0) { action, label in
                    Toggle(label, isOn: binding(for: action))
                }
            } label: {
                // Drawn like a picker's value so it matches the menus around it.
                Text("\(summary) \(Image(systemName: "chevron.up.chevron.down"))")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    private func binding(for action: WindowAction) -> Binding<Bool> {
        Binding {
            enabledButtons.contains(action)
        } set: { isEnabled in
            if isEnabled {
                enabledButtons.insert(action)
            } else {
                enabledButtons.remove(action)
                if enabledButtons.isEmpty {
                    onAllRemoved()
                }
            }
        }
    }
}
