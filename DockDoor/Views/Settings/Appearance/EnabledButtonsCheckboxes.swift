import SwiftUI

struct EnabledButtonsCheckboxes: View {
    @Binding var enabledButtons: Set<WindowAction>
    @Binding var visibilityBinding: TrafficLightButtonsVisibility
    let useMonochrome: Bool

    private let buttonDescriptions: [(WindowAction, String)] = [
        (.quit, String(localized: "Quit")),
        (.close, String(localized: "Close")),
        (.minimize, String(localized: "Minimize")),
        (.toggleFullScreen, String(localized: "Fullscreen")),
        (.maximize, String(localized: "Maximize")),
        (.openNewWindow, String(localized: "New Window")),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ForEach(buttonDescriptions.prefix(3), id: \.0) { action, label in
                    Toggle(isOn: Binding(
                        get: { enabledButtons.contains(action) },
                        set: { isEnabled in
                            if isEnabled {
                                enabledButtons.insert(action)
                            } else {
                                enabledButtons.remove(action)
                                if enabledButtons.isEmpty {
                                    visibilityBinding = .never
                                }
                            }
                        }
                    )) {
                        Text(label)
                    }
                    .toggleStyle(CheckboxToggleStyle())
                }
            }
            HStack(spacing: 12) {
                ForEach(buttonDescriptions.suffix(3), id: \.0) { action, label in
                    Toggle(isOn: Binding(
                        get: { enabledButtons.contains(action) },
                        set: { isEnabled in
                            if isEnabled {
                                enabledButtons.insert(action)
                            } else {
                                enabledButtons.remove(action)
                                if enabledButtons.isEmpty {
                                    visibilityBinding = .never
                                }
                            }
                        }
                    )) {
                        Text(label)
                    }
                    .toggleStyle(CheckboxToggleStyle())
                }
            }
        }
    }
}
