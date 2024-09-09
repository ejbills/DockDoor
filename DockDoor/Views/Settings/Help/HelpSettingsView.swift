import SwiftUI

struct HelpSettingsView: View {
    var body: some View {
        VStack {
            if #available(macOS 15.0, *) { ScreenRecordingWarningView() }
        }
        .padding(20)
        .frame(minWidth: 650)
    }
}
