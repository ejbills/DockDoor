import Sparkle
import SwiftUI

struct SupportSettingsView: View {
    private var updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
    }

    var body: some View {
        BaseSettingsView {
            VStack(alignment: .leading, spacing: 20) {
                StyledGroupBox(label: "Permissions") {
                    PermissionsView(disableShine: true)
                        .padding(.top, 5)
                }

                StyledGroupBox(label: "Updates") {
                    UpdateSettingsView(updater: updater)
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
