import SwiftUI

struct FirstTimeViewInstructionsView: View {
    var step: Int = 0

    var body: some View {
        VStack(spacing: 8) {
            if step >= 1 {
                Text("Welcome to DockDoor!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .transition(FirstTimeView.transition)
            }

            if step >= 2 {
                Text("Enhance your dock experience!")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .transition(FirstTimeView.transition)
            }
        }
        .frame(maxWidth: .infinity)
        .scaleEffect(1)

        if step >= 3 {
            NavigationLink(destination: PermissionsSettingsView(), label: {
                Text("Get Started")
            })
            .buttonStyle(AccentButtonStyle())
            .transition(FirstTimeView.transition)
        }
    }
}

#Preview {
    FirstTimeViewInstructionsView()
}
