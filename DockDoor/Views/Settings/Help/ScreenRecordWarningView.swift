import SwiftUI

struct ScreenRecordingWarningView: View {
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Image("ScreenRecordWarning")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Screen Recording Permission")
                        .font(.subheadline)
                    Text("DockDoor requires screen recording access. In macOS Sequoia, you'll see this prompt weekly and after reboots for security. It's not a bug, but a system-wide policy for all apps using screen capture.")
                        .font(.caption)
                }
            }
        }
        .cardStyle()
    }
}
