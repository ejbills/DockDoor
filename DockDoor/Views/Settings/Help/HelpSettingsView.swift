import SwiftUI

struct HelpSettingsView: View {
    var body: some View {
        HStack(spacing: 8) {
            ScreenRecordingWarningView()

            VStack(spacing: 8) {
                DonationView()
                SquiggleDivider()
                BugReportingView()
                SquiggleDivider()
                FeatureRequestView()
            }
        }
        .frame(alignment: .leading)
        .padding(20)
        .frame(minWidth: 650)
    }
}
