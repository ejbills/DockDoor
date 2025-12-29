import SwiftUI

struct FirstTimeIntroTabView: View {
    var nextTab: () -> Void

    var body: some View {
        HStack(spacing: 32) {
            FirstTimeViewAppIcon()

            VStack(alignment: .leading, spacing: 20) {
                Text("Welcome to DockDoor!")
                    .font(.system(size: 28, weight: .bold, design: .default))

                Button("Get Started", action: nextTab)
                    .buttonStyle(AccentButtonStyle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
