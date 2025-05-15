import AppKit
import Combine
import SwiftUI

struct PermissionsSettingsView: View {
    var body: some View {
        BaseSettingsView {
            PermissionsView(disableShine: true)
        }
    }
}
