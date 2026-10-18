import Defaults
import SwiftUI

struct MouseActionsSection: View {
    @Default(.middleClickAction) var middleClickAction

    var body: some View {
        SettingsSection("Mouse actions") {
            Picker("Middle click", selection: $middleClickAction) {
                ForEach(WindowAction.middleClickActions, id: \.self) { windowAction in
                    Label(windowAction.localizedName, systemImage: windowAction.iconName)
                        .tag(windowAction)
                }
            }
            .settingsSearchTarget("gestures.middleClick")
            .settingsAnnotation("Action performed when middle-clicking on a window preview.")
        }
    }
}
