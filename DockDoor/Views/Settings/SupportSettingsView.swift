import SwiftUI

struct SupportSettingsView: View {
    @ObservedObject var updaterState: UpdaterState

    init(updaterState: UpdaterState) {
        self.updaterState = updaterState
    }

    var body: some View {
        BaseSettingsView {
            VStack(alignment: .leading, spacing: 20) {
                StyledGroupBox(label: "Permissions") {
                    PermissionsView(disableShine: true)
                        .padding(.top, 5)
                }

                StyledGroupBox(label: "Updates") {
                    UpdateSettingsView(updaterState: updaterState)
                        .padding(.top, 5)
                }

                StyledGroupBox(label: "Help & Support") {
                    HelpSettingsView()
                        .padding(.top, 5)
                }

                StyledGroupBox(label: "Acknowledgments") {
                    AcknowledgmentsView()
                        .padding(.top, 5)
                }
            }
        }
    }
}

struct AcknowledgmentsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Community Contributors")
                    .font(.headline)
                    .foregroundColor(.primary)

                VStack(spacing: 0) {
                    // Table header
                    HStack {
                        Text("Name")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("Contributions")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                    .background(Color.primary.opacity(0.1))

                    Divider()

                    // Table rows
                    communityContributorRow(name: "illavoluntas", contributions: "Website and portal documentation, Discord moderation")
                }
                .background(Color.primary.opacity(0.05))
                .cornerRadius(8)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Translation Contributors")
                    .font(.headline)
                    .foregroundColor(.primary)

                VStack(spacing: 0) {
                    // Table header
                    HStack {
                        Text("Name")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("Language")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("Profile")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .frame(width: 100, alignment: .center)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                    .background(Color.primary.opacity(0.1))

                    Divider()

                    // Table rows
                    contributorTableRow(name: "Rocco 'Roccobot' Casadei", language: "Italian", profile: "Roccobot")
                    contributorTableRow(name: "favorsjewelry5", language: "Chinese Traditional", profile: "favorsjewelry5")
                    contributorTableRow(name: "Денис Єгоров", language: "Ukrainian", profile: "makedonsky47")
                    contributorTableRow(name: "HuangxinDong", language: "Chinese Simplified", profile: "HuangxinDong")
                    contributorTableRow(name: "don.julien.7", language: "German", profile: "JuGro1332")
                    contributorTableRow(name: "awaustin", language: "Chinese Simplified", profile: "awaustin")
                    contributorTableRow(name: "illavoluntas", language: "French", profile: "illavoluntas")
                }
                .background(Color.primary.opacity(0.05))
                .cornerRadius(8)
            }
        }
    }

    private func contributorTableRow(name: String, language: String, profile: String) -> some View {
        HStack {
            Text(name)
                .font(.body)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(language)
                .font(.body)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Link("View", destination: URL(string: "https://crowdin.com/profile/\(profile)")!)
                .font(.body)
                .foregroundColor(.accentColor)
                .frame(width: 100, alignment: .center)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.clear)
    }

    private func communityContributorRow(name: String, contributions: String) -> some View {
        HStack {
            Text(name)
                .font(.body)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(contributions)
                .font(.body)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.clear)
    }
}
