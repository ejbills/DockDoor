import SwiftUI

struct SettingsNote: View {
    let icon: String
    let text: LocalizedStringKey

    var body: some View {
        SettingsCallout(tone: .info, icon: icon, message: Text(text))
    }
}
