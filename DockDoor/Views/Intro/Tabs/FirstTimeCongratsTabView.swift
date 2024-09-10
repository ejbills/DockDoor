import ConfettiSwiftUI
import SwiftUI

struct FirstTimeCongratsTabView: View {
    var nextTab: () -> Void
    @State private var counter: Int = 0

    var body: some View {
        VStack(alignment: .center, spacing: 24) {
            Text("Everything is now set up!")
                .font(.title2)
                .fontWeight(.semibold)

            CustomizableFluidGradientView()
                .mask(
                    Image(nsImage: NSImage(named: .logo) ?? NSImage())
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                )
                .frame(width: 64, height: 64)

            Text("When you click the button below, DockDoor will restart and move to the menu bar to run in the background.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .center, spacing: 12) {
                SquiggleDivider()
                Text("The changes to permissions will take effect after restarting.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button(action: {
                    let appDelegate = NSApplication.shared.delegate as! AppDelegate
                    appDelegate.restartApp()
                }) {
                    Text("Restart app")
                }
                .buttonStyle(AccentButtonStyle())
            }
        }
        .padding(32)
        .onAppear { counter += 1 }
        .confettiCannon(counter: $counter, num: 50, radius: 400)
    }
}

#Preview {
    FirstTimeCongratsTabView(nextTab: {})
}
