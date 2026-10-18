import Defaults
import SwiftUI

struct AppearanceSettingsView: View {
    @Default(.disableImagePreview) var disableImagePreview

    @StateObject private var permissionsChecker = PermissionsChecker()

    var body: some View {
        SettingsFormView {
            if !permissionsChecker.screenRecordingPermission {
                Section {
                    CompactModeWarningBanner(
                        hasScreenRecordingPermission: permissionsChecker.screenRecordingPermission,
                        disableImagePreview: disableImagePreview
                    )
                }
            }

            WindowSizeSettingsSection()

            BackgroundAppearanceSection()

            GeneralAppearanceSection()

            CompactModeSection(hasScreenRecordingPermission: permissionsChecker.screenRecordingPermission)

            AdvancedAppearanceSection()
        }
    }
}
