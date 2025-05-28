import SwiftUI

struct SupportSettingsView: View {
    @ObservedObject var updaterState: UpdaterState

    init(updaterState: UpdaterState) {
        self.updaterState = updaterState
    }

    var body: some View {
        BaseSettingsView {
            VStack(alignment: .leading, spacing: 20) {
                StyledGroupBox(label: "Permissions") {
                    PermissionsView(disableShine: true)
                        .padding(.top, 5)
                }

                StyledGroupBox(label: "Updates") {
                    UpdateSettingsView(updaterState: updaterState)
                        .padding(.top, 5)
                }

                StyledGroupBox(label: "Help & Support") {
                    HelpSettingsView()
                        .padding(.top, 5)
                }
            }
        }
    }
}
