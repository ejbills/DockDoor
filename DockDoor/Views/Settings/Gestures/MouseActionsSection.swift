import Defaults
import SwiftUI

struct MouseActionsSection: View {
    @Default(.middleClickAction) var middleClickAction

    var body: some View {
        SettingsGroup(header: "Mouse Actions") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "computermouse.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                        Text("Middle Click")
                            .frame(width: 80, alignment: .leading)
                    }

                    Picker("", selection: $middleClickAction) {
                        ForEach(WindowAction.gestureActions, id: \.self) { windowAction in
                            HStack(spacing: 6) {
                                Image(systemName: windowAction.iconName)
                                Text(windowAction.localizedName)
                            }
                            .tag(windowAction)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                Text("Action performed when middle-clicking on a window preview.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
