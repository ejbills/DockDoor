import AppKit

enum DockDoorPro {
    static let url = URL(string: "https://pro.dockdoor.net")!
    static let iconURL = URL(string: "https://pro.dockdoor.net/apple-touch-icon.png")!

    static func open() {
        NSWorkspace.shared.open(url)
    }
}
