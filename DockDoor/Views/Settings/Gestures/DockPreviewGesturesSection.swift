import Defaults
import SwiftUI

struct DockPreviewGesturesSection: View {
    @Default(.enableDockPreviewGestures) var enableDockPreviewGestures
    @Default(.dockSwipeTowardsDockAction) var dockSwipeTowardsDockAction
    @Default(.dockSwipeAwayFromDockAction) var dockSwipeAwayFromDockAction
    @Default(.aeroShakeAction) var aeroShakeAction

    var body: some View {
        SettingsGroup(header: "Dock Preview Gestures") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $enableDockPreviewGestures) {
                    HStack(spacing: 8) {
                        Image(systemName: "dock.rectangle")
                            .foregroundColor(.accentColor)
                        Text("Enable gestures on dock window previews")
                    }
                }

                if enableDockPreviewGestures {
                    Text("Swipe on window previews in the dock popup. Direction is relative to dock position — swipe towards the dock (e.g., down when dock is at bottom, left when dock is on left).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)

                    Divider()

                    GestureDirectionRow(
                        direction: "Towards Dock",
                        icon: "arrow.down.to.line",
                        description: "Swipe toward the dock edge",
                        action: $dockSwipeTowardsDockAction
                    )

                    GestureDirectionRow(
                        direction: "Away from Dock",
                        icon: "arrow.up.to.line",
                        description: "Swipe away from the dock edge",
                        action: $dockSwipeAwayFromDockAction
                    )

                    Divider()

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Image(systemName: "hand.point.up.left.and.text")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .frame(width: 20)
                                Text("Aero Shake")
                            }
                            Text("Shake a window preview rapidly")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.leading, 26)
                        }
                        .frame(minWidth: 140, alignment: .leading)

                        Picker("", selection: $aeroShakeAction) {
                            ForEach(AeroShakeAction.allCases, id: \.self) { action in
                                Text(action.localizedName).tag(action)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }

                    Button("Reset to Defaults") {
                        dockSwipeTowardsDockAction = Defaults.Keys.dockSwipeTowardsDockAction.defaultValue
                        dockSwipeAwayFromDockAction = Defaults.Keys.dockSwipeAwayFromDockAction.defaultValue
                        aeroShakeAction = Defaults.Keys.aeroShakeAction.defaultValue
                    }
                    .buttonStyle(AccentButtonStyle(small: true))
                    .padding(.top, 4)
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
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    Text(direction)
                }
                if let description {
                    Text(description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.leading, 26)
                }
            }
            .frame(minWidth: 140, alignment: .leading)

            Picker("", selection: $action) {
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
    }
}
