import SwiftUI

struct DonationView: View {
    var body: some View {
        UniformCardView(
            title: "Support DockDoor",
            description: "If you find DockDoor useful, consider donating. Your support helps keep the project going!",
            buttonTitle: "Support DockDoor",
            buttonLink: "https://buymeacoffee.com/keplercafe"
        )
    }
}
