import SwiftUI

struct BugReportingView: View {
    var body: some View {
        UniformCardView(
            title: "Found a Bug?",
            description: "Help us improve DockDoor by reporting any issues you encounter.",
            buttonTitle: "Report a Bug",
            buttonLink: Links.bugReport.absoluteString
        )
    }
}

struct FeatureRequestView: View {
    var body: some View {
        UniformCardView(
            title: "Have an Idea?",
            description: "Suggest new features to make DockDoor even better.",
            buttonTitle: "Request a Feature",
            buttonLink: Links.featureRequest.absoluteString
        )
    }
}
