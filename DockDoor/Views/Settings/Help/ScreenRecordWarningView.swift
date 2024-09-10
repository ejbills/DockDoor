import Glur
import SwiftUI

struct ScreenRecordingWarningView: View {
    @State private var displayExplanation: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .bottom) {
                Image("ScreenRecordWarning")
                    .resizable()
                    .scaledToFit()
                    .glur(radius: displayExplanation ? 10.0 : 2.0,
                          direction: .down)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 8) {
                    Text("DockDoor needs screen recording access. In macOS Sequoia, you'll see this prompt every week or month and after reboots. This is a new system-wide security policy for all screen capture apps.")

                    if displayExplanation {
                        Text("DockDoor does not record your screen or audio. It only captures static window previews. No information is stored or shared; all processing occurs privately on your device.")

                        Text("Want to see for yourself? Review our source code")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .onTapGesture {
                                if let url = URL(string: "https://github.com/ejbills/DockDoor/blob/main/DockDoor/Utilities/WindowUtil.swift#L71-L147") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                    } else {
                        Text("See more...")
                            .font(.caption)
                            .italic()
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
                .dockStyle(cornerRadius: 16)
                .padding(.bottom, 2)
                .frame(maxWidth: .infinity)
                .onTapGesture {
                    withAnimation(.spring(duration: 0.2)) { displayExplanation.toggle() }
                }
            }
            .frame(maxWidth: 300)
        }
        .dockStyle(cornerRadius: 18)
    }
}
