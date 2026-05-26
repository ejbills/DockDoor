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
        (.bringToCurrentSpace, String(localized: "Bring to Current Space")),
        (.openNewWindow, String(localized: "New Window")),
    ]

    private var buttonRows: [[(WindowAction, String)]] {
        stride(from: 0, to: buttonDescriptions.count, by: 3).map { start in
            Array(buttonDescriptions[start ..< min(start + 3, buttonDescriptions.count)])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(buttonRows.indices, id: \.self) { rowIndex in
                HStack(spacing: 12) {
                    ForEach(buttonRows[rowIndex], id: \.0) { action, label in
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
}
