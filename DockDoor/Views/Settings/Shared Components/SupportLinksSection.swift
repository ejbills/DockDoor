import SwiftUI

struct SupportLinksSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SettingsLinkRow(
                title: "Support DockDoor",
                description: "Help keep the project going with a small donation",
                icon: "heart.fill",
                destination: URL(string: "https://dockdoor.net/donate")!,
                iconColor: .pink
            )

            Divider().padding(.leading, 40)

            SettingsLinkRow(
                title: "Join our Discord",
                description: "Discuss features and get help from the community",
                icon: "bubble.left.and.bubble.right.fill",
                destination: URL(string: "https://discord.gg/TZeRs73hFb")!,
                iconColor: .indigo
            )

            Divider().padding(.leading, 40)

            SettingsLinkRow(
                title: "Report a Bug",
                description: "Help us improve by reporting issues",
                icon: "ladybug.fill",
                destination: URL(string: "https://github.com/ejbills/DockDoor/issues/new?assignees=&labels=bug&projects=&template=bug_report.md&title=%5BBUG%5D")!,
                iconColor: .red
            )

            Divider().padding(.leading, 40)

            SettingsLinkRow(
                title: "Request a Feature",
                description: "Suggest new features to make DockDoor better",
                icon: "lightbulb.fill",
                destination: URL(string: "https://github.com/ejbills/DockDoor/issues/new?assignees=&labels=enhancement&projects=&template=feature_request.md&title=%5BFR%5D")!,
                iconColor: .yellow
            )

            Divider().padding(.leading, 40)

            SettingsLinkRow(
                title: "Contribute Translation",
                description: "Help make DockDoor available in your language",
                icon: "globe",
                destination: URL(string: "https://crowdin.com/project/dockdoor/invite?h=895e3c085646d3c07fa36a97044668e02149115")!,
                iconColor: .blue
            )

            Divider().padding(.leading, 40)

            SettingsLinkRow(
                title: "View Source Code",
                description: "DockDoor is open source on GitHub",
                icon: "chevron.left.forwardslash.chevron.right",
                destination: URL(string: "https://github.com/ejbills/DockDoor")!,
                iconColor: .purple
            )
        }
    }
}
