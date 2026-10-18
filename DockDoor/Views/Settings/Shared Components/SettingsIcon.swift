import SwiftUI

struct SettingsIcon: View {
    let systemName: String
    var color: Color = .secondary

    var body: some View {
        Image(systemName: systemName)
            .foregroundStyle(color)
            .frame(width: 18)
    }
}
