import SwiftUI

struct FirstTimeViewAppIcon: View {
    var body: some View {
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 120, height: 120)
            .shadow(color: .black.opacity(0.25), radius: 16, y: 10)
    }
}

#Preview {
    FirstTimeViewAppIcon()
}
