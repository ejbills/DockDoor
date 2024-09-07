import SwiftUI

struct FirstTimeView: View {
    @State private var showPermissions = false

    var body: some View {
        ZStack {
            HStack {
                VStack(spacing: 20) {
                    Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)

                    Text("Welcome to DockDoor!")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Enhance your dock experience!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Button("Get Started") {
                        openPermissionsWindow()
                    }
                    .buttonStyle(LinkButtonStyle())
                }
                .padding()

                Divider()
            }

            fluidGradient().opacity(0.125)
        }
        .edgesIgnoringSafeArea(.all)
    }

    private func openPermissionsWindow() {
        let contentView = PermissionsSettingsView()

        // Create the hosting controller with the PermView
        let hostingController = NSHostingController(rootView: contentView)

        // Create the settings window
        let permissionsWindow = NSWindow(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 200, height: 200)),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered, defer: false
        )
        permissionsWindow.center()
        permissionsWindow.setFrameAutosaveName("DockDoor Permissions")
        permissionsWindow.contentView = hostingController.view
        permissionsWindow.title = "DockDoor Permissions"
        permissionsWindow.makeKeyAndOrderFront(nil)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        FirstTimeView()
    }
}
