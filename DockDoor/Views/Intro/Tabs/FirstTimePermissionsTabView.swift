import SwiftUI

struct FirstTimePermissionsTabView: View {
    var nextTab: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Text("May I have some permissions?")
                .font(.largeTitle)
                .fontWeight(.bold)
            PermissionsView()
        }
        .padding(32)
    }
}

#Preview {
    FirstTimePermissionsTabView(nextTab: {})
}
