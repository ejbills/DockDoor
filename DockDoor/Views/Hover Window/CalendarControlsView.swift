import EventKit
import SwiftUI

// TODO: Future calendar view using BaseHoverContainer
struct CalendarControlsView: View {
    let appName: String
    let bundleIdentifier: String
    let bestGuessMonitor: NSScreen
    let mockPreviewActive: Bool
    let onTap: (() -> Void)?

    init(appName: String, bundleIdentifier: String, bestGuessMonitor: NSScreen, mockPreviewActive: Bool = false, onTap: (() -> Void)? = nil) {
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.bestGuessMonitor = bestGuessMonitor
        self.mockPreviewActive = mockPreviewActive
        self.onTap = onTap
    }

    var body: some View {
        BaseHoverContainer(bestGuessMonitor: bestGuessMonitor, mockPreviewActive: mockPreviewActive) {
            VStack(spacing: 20) {
                HStack {
                    Text(appName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                // TODO: Add calendar events display
                Text("Calendar events will appear here")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(20)
            .onTapGesture {
                onTap?()
            }
        }
    }
}
