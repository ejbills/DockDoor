import SwiftUI

struct SupportLinksSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SettingsLinkRow(
                title: "Get DockDoor Pro",
                description: "Replace the Dock entirely with the paid app from the same developer",
                icon: "sparkles",
                iconColor: .mint,
                destination: Links.dockDoorPro
            )
            .settingsSearchTarget("general.dockDoorPro")

            Divider().padding(.leading, 40)

            SettingsLinkRow(
                title: "Support DockDoor",
                description: "Help keep the project going with a small donation",
                icon: "heart.fill",
                iconColor: .pink,
                destination: Links.donate
            )

            Divider().padding(.leading, 40)

            SettingsLinkRow(
                title: "Leave a Review",
                description: "Share your experience on Product Hunt",
                icon: "star.bubble.fill",
                iconColor: .orange,
                destination: Links.review
            )
            .settingsSearchTarget("general.leaveReview")

            Divider().padding(.leading, 40)

            SettingsLinkRow(
                title: "Join our Discord",
                description: "Discuss features and get help from the community",
                icon: "bubble.left.and.bubble.right.fill",
                iconColor: .indigo,
                destination: Links.discord
            )

            Divider().padding(.leading, 40)

            SettingsLinkRow(
                title: "Report a Bug",
                description: "Help us improve by reporting issues",
                icon: "ladybug.fill",
                iconColor: .red,
                destination: Links.bugReport
            )

            Divider().padding(.leading, 40)

            SettingsLinkRow(
                title: "Request a Feature",
                description: "Suggest new features to make DockDoor better",
                icon: "lightbulb.fill",
                iconColor: .yellow,
                destination: Links.featureRequest
            )

            Divider().padding(.leading, 40)

            SettingsLinkRow(
                title: "Contribute Translation",
                description: "Help make DockDoor available in your language",
                icon: "globe",
                iconColor: .blue,
                destination: Links.translations
            )

            Divider().padding(.leading, 40)

            SettingsLinkRow(
                title: "View Source Code",
                description: "DockDoor is open source on GitHub",
                icon: "chevron.left.forwardslash.chevron.right",
                iconColor: .purple,
                destination: Links.repository
            )
        }
    }
}
