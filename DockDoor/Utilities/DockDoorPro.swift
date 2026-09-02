import AppKit

enum DockDoorPro {
    static let url = URL(string: "https://pro.dockdoor.net")!
    static let iconURL = URL(string: "https://pro.dockdoor.net/_astro/dockdoor-icon.DNTkj7IN_GoFVN.webp")!

    static func open() {
        NSWorkspace.shared.open(url)
    }
}
