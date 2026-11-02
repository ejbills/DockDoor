import SwiftUI

struct SupportLinksSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SettingsLinkRow(
                title: "Get DockDoor Pro",
                description: "Replace the Dock entirely with the paid app from the same developer",
                icon: "sparkles",
                destination: Links.dockDoorPro,
                iconColor: .mint
            )
            .settingsSearchTarget("general.dockDoorPro")

            Divider().padding(.leading, 40)

            SettingsLinkRow(
                title: "Support DockDoor",
                description: "Help keep the project going with a small donation",
                icon: "heart.fill",
                destination: Links.donate,
                iconColor: .pink
            )

            Divider().padding(.leading, 40)

            SettingsLinkRow(
                title: "Leave a Review",
                description: "Share your experience on Product Hunt",
                icon: "star.bubble.fill",
                destination: Links.review,
                iconColor: .orange
            )
            .settingsSearchTarget("general.leaveReview")

            Divider().padding(.leading, 40)

            SettingsLinkRow(
                title: "Join our Discord",
                description: "Discuss features and get help from the community",
                icon: "bubble.left.and.bubble.right.fill",
                destination: Links.discord,
                iconColor: .indigo
            )

            Divider().padding(.leading, 40)

            SettingsLinkRow(
                title: "Report a Bug",
                description: "Help us improve by reporting issues",
                icon: "ladybug.fill",
                destination: Links.bugReport,
                iconColor: .red
            )

            Divider().padding(.leading, 40)

            SettingsLinkRow(
                title: "Request a Feature",
                description: "Suggest new features to make DockDoor better",
                icon: "lightbulb.fill",
                destination: Links.featureRequest,
                iconColor: .yellow
            )

            Divider().padding(.leading, 40)

            SettingsLinkRow(
                title: "Contribute Translation",
                description: "Help make DockDoor available in your language",
                icon: "globe",
                destination: Links.translations,
                iconColor: .blue
            )

            Divider().padding(.leading, 40)

            SettingsLinkRow(
                title: "View Source Code",
                description: "DockDoor is open source on GitHub",
                icon: "chevron.left.forwardslash.chevron.right",
                destination: Links.repository,
                iconColor: .purple
            )
        }
    }
}
