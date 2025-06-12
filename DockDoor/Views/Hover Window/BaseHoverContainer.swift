import SwiftUI

struct BaseHoverContainer<Content: View>: View {
    let content: Content
    let bestGuessMonitor: NSScreen
    let mockPreviewActive: Bool
    let highlightColor: Color?

    init(bestGuessMonitor: NSScreen, mockPreviewActive: Bool = false, @ViewBuilder content: () -> Content, highlightColor: Color? = nil) {
        self.bestGuessMonitor = bestGuessMonitor
        self.mockPreviewActive = mockPreviewActive
        self.content = content()
        self.highlightColor = highlightColor
    }

    var body: some View {
        content
            .dockStyle(cornerRadius: 16, highlightColor: highlightColor)
            .padding(.all, mockPreviewActive ? 0 : 24)
            .frame(maxWidth: bestGuessMonitor.visibleFrame.width, maxHeight: bestGuessMonitor.visibleFrame.height)
    }
}
