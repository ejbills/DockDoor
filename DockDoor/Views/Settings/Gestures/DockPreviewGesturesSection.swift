import Defaults
import SwiftUI

struct DockPreviewGesturesSection: View {
    @Default(.enableDockPreviewGestures) var enableDockPreviewGestures
    @Default(.dockSwipeTowardsDockAction) var dockSwipeTowardsDockAction
    @Default(.dockSwipeAwayFromDockAction) var dockSwipeAwayFromDockAction
    @Default(.aeroShakeAction) var aeroShakeAction

    var body: some View {
        SettingsSection("Dock Preview Gestures") {
            Toggle(isOn: $enableDockPreviewGestures) {
                Text("Enable gestures on dock window previews")
            }
            .settingsSearchTarget("gestures.dockPreview")
            .settingsAnnotation("Swipe on window previews in the dock popup. Direction is relative to dock position — swipe towards the dock (e.g., down when dock is at bottom, left when dock is on left).")

            if enableDockPreviewGestures {
                GestureDirectionRow(
                    direction: "Towards Dock",
                    icon: "arrow.down.to.line",
                    description: "Swipe toward the dock edge",
                    action: $dockSwipeTowardsDockAction
                )
                .settingsSearchTarget("gestures.swipeTowardsDock")

                GestureDirectionRow(
                    direction: "Away from Dock",
                    icon: "arrow.up.to.line",
                    description: "Swipe away from the dock edge",
                    action: $dockSwipeAwayFromDockAction
                )
                .settingsSearchTarget("gestures.swipeAwayFromDock")

                Picker("Aero Shake", selection: $aeroShakeAction) {
                    ForEach(AeroShakeAction.allCases, id: \.self) { action in
                        Text(action.localizedName).tag(action)
                    }
                }
                .settingsAnnotation("Shake a window preview rapidly")
                .settingsSearchTarget("gestures.aeroShake")

                HStack {
                    Spacer()
                    Button("Reset to Defaults") {
                        dockSwipeTowardsDockAction = Defaults.Keys.dockSwipeTowardsDockAction.defaultValue
                        dockSwipeAwayFromDockAction = Defaults.Keys.dockSwipeAwayFromDockAction.defaultValue
                        aeroShakeAction = Defaults.Keys.aeroShakeAction.defaultValue
                    }
                    .buttonStyle(.settings)
                }
            }
        }
    }
}

// MARK: - Gesture Direction Row

struct GestureDirectionRow: View {
    let direction: String
    let icon: String
    let description: String?
    @Binding var action: WindowAction

    var body: some View {
        let picker = Picker(LocalizedStringKey(direction), selection: $action) {
            ForEach(WindowAction.gestureActions, id: \.self) { windowAction in
                Label(windowAction.localizedName, systemImage: windowAction.iconName)
                    .tag(windowAction)
            }
        }
        if let description {
            picker.settingsAnnotation(LocalizedStringKey(description))
        } else {
            picker
        }
    }
}
