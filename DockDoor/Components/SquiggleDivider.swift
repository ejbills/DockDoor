import SwiftUI

struct SquiggleDivider: View {
    var color: Color = .primary
    var body: some View {
        Image(.cuteDivider)
            .resizable()
            .scaledToFit()
            .frame(width: 51, height: 7)
            .foregroundStyle(color)
    }
}

#Preview {
    SquiggleDivider()
}
