import Defaults
import SwiftUI

enum HoverContainerPadding {
    static let container: CGFloat = 24
    static let dockStyleOuter: CGFloat = 2
    static let scrollOuter: CGFloat = 2
    static let contentInner: CGFloat = 20
    static let itemSpacing: CGFloat = 24

    static func totalPerSide(paddingMultiplier: CGFloat = Defaults[.globalPaddingMultiplier]) -> CGFloat {
        container + dockStyleOuter + scrollOuter + (contentInner * paddingMultiplier)
    }
}

struct BaseHoverContainer<Content: View>: View {
    @Default(.dockPreviewBackgroundOpacity) var dockPreviewBackgroundOpacity
    @Default(.hideHoverContainerBackground) var hideHoverContainerBackground
    @Default(.hideWidgetContainerBackground) var hideWidgetContainerBackground

    let content: Content
    let bestGuessMonitor: NSScreen
    let mockPreviewActive: Bool
    let highlightColor: Color?
    let preventDockStyling: Bool
    let isWidget: Bool
    let backgroundAppearance: BackgroundAppearance

    init(bestGuessMonitor: NSScreen,
         mockPreviewActive: Bool = false,
         @ViewBuilder content: () -> Content,
         highlightColor: Color? = nil,
         preventDockStyling: Bool = false,
         isWidget: Bool = false,
         backgroundAppearance: BackgroundAppearance)
    {
        self.bestGuessMonitor = bestGuessMonitor
        self.mockPreviewActive = mockPreviewActive
        self.content = content()
        self.highlightColor = highlightColor
        self.preventDockStyling = preventDockStyling
        self.isWidget = isWidget
        self.backgroundAppearance = backgroundAppearance
    }

    private var shouldHideBackground: Bool {
        isWidget ? hideWidgetContainerBackground : hideHoverContainerBackground
    }

    var body: some View {
        content
            .if(!preventDockStyling) { view in
                view.dockStyle(
                    backgroundAppearance: backgroundAppearance,
                    highlightColor: highlightColor,
                    backgroundOpacity: shouldHideBackground ? 0 : dockPreviewBackgroundOpacity
                )
            }
            .padding(.all, mockPreviewActive ? 0 : HoverContainerPadding.container)
            .frame(maxWidth: bestGuessMonitor.visibleFrame.width, maxHeight: bestGuessMonitor.visibleFrame.height, alignment: .topLeading)
    }
}
