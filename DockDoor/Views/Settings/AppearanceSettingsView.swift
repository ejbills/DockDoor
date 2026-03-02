import Defaults
import SwiftUI

struct AppearanceSettingsView: View {
    @Default(.disableImagePreview) var disableImagePreview

    @StateObject private var permissionsChecker = PermissionsChecker()

    var body: some View {
        BaseSettingsView {
            VStack(alignment: .leading, spacing: 16) {
                if !permissionsChecker.screenRecordingPermission {
                    CompactModeWarningBanner(
                        hasScreenRecordingPermission: permissionsChecker.screenRecordingPermission,
                        disableImagePreview: disableImagePreview
                    )
                }

                WindowSizeSettingsSection()

                GeneralAppearanceSection()

                CompactModeSection(hasScreenRecordingPermission: permissionsChecker.screenRecordingPermission)

                AdvancedAppearanceSection()
            }
        }
    }
}
