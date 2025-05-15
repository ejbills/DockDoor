import SwiftUI

struct HelpSettingsView: View {
    var body: some View {
        HStack {
            ScreenRecordingWarningView()

            Spacer()

            VStack(spacing: 12) {
                DonationView()
                SquiggleDivider()
                BugReportingView()
                SquiggleDivider()
                FeatureRequestView()
            }
        }
    }
}
