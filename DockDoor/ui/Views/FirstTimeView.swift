import SwiftUI

struct FirstTimeView: View {
    @State private var showPermissions = false

    var body: some View {
        HStack {
            VStack(spacing: 20) {
                Image(systemName: "dock.rectangle")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .foregroundColor(.blue)

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

            VStack(alignment: .leading, spacing: 20) {
                Text("Why we need permissions")
                    .font(.title2)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Accessibility:")
                        .font(.headline)
                    Text("• To detect when you hover over the dock")
                    Text("• Enables real-time interaction with dock items")
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Screen Capturing:")
                        .font(.headline)
                    Text("• To capture previews of images and windows")
                    Text("• Allows for enhanced visual information in the dock")
                }
            }
            .padding()
        }
        .dockStyle(cornerRadius: 0)
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
