import SwiftUI

struct BugReportingView: View {
    var body: some View {
        UniformCardView(
            title: "Found a Bug?",
            description: "Help us improve DockDoor by reporting any issues you encounter.",
            buttonTitle: "Report a Bug",
            buttonLink: "https://github.com/ejbills/DockDoor/issues/new?assignees=&labels=bug&projects=&template=bug_report.md&title=%5BBUG%5D"
        )
    }
}

struct FeatureRequestView: View {
    var body: some View {
        UniformCardView(
            title: "Have an Idea?",
            description: "Suggest new features to make DockDoor even better.",
            buttonTitle: "Request a Feature",
            buttonLink: "https://github.com/ejbills/DockDoor/issues/new?assignees=&labels=enhancement&projects=&template=feature_request.md&title=%5BFR%5D"
        )
    }
}
