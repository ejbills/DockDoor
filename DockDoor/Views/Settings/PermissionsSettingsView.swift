import AppKit
import Combine
import SwiftUI

struct PermissionsSettingsView: View {
    var body: some View {
        PermissionsView(disableShine: true)
            .padding(32)
    }
}
