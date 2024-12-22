import SwiftUI

struct FirstTimePermissionsTabView: View {
    var nextTab: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Text("Let's set things up")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Navigate to Settings → Privacy & Security")
                .font(.body)
                .foregroundColor(.secondary)

            PermissionsView(nextTab: nextTab)
        }
        .padding(32)
    }
}

#Preview {
    FirstTimePermissionsTabView(nextTab: {})
}
