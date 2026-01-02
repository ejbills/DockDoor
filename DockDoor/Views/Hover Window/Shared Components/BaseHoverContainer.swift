import Defaults
import SwiftUI

struct BaseHoverContainer<Content: View>: View {
    @Default(.dockPreviewBackgroundOpacity) var dockPreviewBackgroundOpacity
    @Default(.hideHoverContainerBackground) var hideHoverContainerBackground

    let content: Content
    let bestGuessMonitor: NSScreen
    let mockPreviewActive: Bool
    let highlightColor: Color?
    let preventDockStyling: Bool

    init(bestGuessMonitor: NSScreen, mockPreviewActive: Bool = false, @ViewBuilder content: () -> Content, highlightColor: Color? = nil, preventDockStyling: Bool = false) {
        self.bestGuessMonitor = bestGuessMonitor
        self.mockPreviewActive = mockPreviewActive
        self.content = content()
        self.highlightColor = highlightColor
        self.preventDockStyling = preventDockStyling
    }

    var body: some View {
        content
            .if(!preventDockStyling) { view in
                view.dockStyle(highlightColor: highlightColor, backgroundOpacity: hideHoverContainerBackground ? 0 : dockPreviewBackgroundOpacity, frostedTranslucentLayer: true)
            }
            .padding(.all, mockPreviewActive ? 0 : 24)
            .frame(maxWidth: bestGuessMonitor.visibleFrame.width, maxHeight: bestGuessMonitor.visibleFrame.height, alignment: .topLeading)
    }
}
