import SwiftUI

struct FirstTimePermissionsTabView: View {
    var nextTab: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Text("Let's set things up")
                .font(.largeTitle)
                .fontWeight(.bold)
            PermissionsView(disableShine: true)
        }
        .padding(32)
    }
}

#Preview {
    FirstTimePermissionsTabView(nextTab: {})
}
