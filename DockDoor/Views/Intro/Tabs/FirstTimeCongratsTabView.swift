import SwiftUI

struct FirstTimeCongratsTabView: View {
    var nextTab: () -> Void
    var body: some View {
        Text("Hello, World!")
    }
}

#Preview {
    FirstTimeCongratsTabView(nextTab: {})
}
