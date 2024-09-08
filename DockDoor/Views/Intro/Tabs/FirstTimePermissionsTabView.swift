import SwiftUI

struct FirstTimePermissionsTabView: View {
    var nextTab: () -> Void
    var body: some View {
        ZStack {
            PermissionsView()
                .padding(32)
        }
    }
}

#Preview {
    FirstTimePermissionsTabView(nextTab: {})
}
