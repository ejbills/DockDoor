import SwiftUI

struct DynamicWindowFrameModifier: ViewModifier {
    let allowDynamicSizing: Bool
    let dimensions: WindowPreviewHoverContainer.WindowDimensions
    let dockPosition: DockPosition
    let windowSwitcherActive: Bool

    func body(content: Content) -> some View {
        if allowDynamicSizing {
            let isHorizontalFlow = dockPosition.isHorizontalFlow || windowSwitcherActive

            if isHorizontalFlow {
                content
                    .frame(height: dimensions.size.height > 0 ? dimensions.size.height : nil)
                    .scaledToFit()
                    .frame(maxWidth: dimensions.maxDimensions.width, maxHeight: dimensions.maxDimensions.height)
            } else {
                content
                    .frame(width: dimensions.size.width > 0 ? dimensions.size.width : nil)
                    .scaledToFit()
                    .frame(maxWidth: dimensions.maxDimensions.width, maxHeight: dimensions.maxDimensions.height)
            }
        } else {
            content
                .frame(width: max(dimensions.size.width, 50),
                       height: dimensions.size.height,
                       alignment: .center)
                .frame(maxWidth: dimensions.maxDimensions.width, maxHeight: dimensions.maxDimensions.height)
        }
    }
}

extension View {
    func dynamicWindowFrame(
        allowDynamicSizing: Bool,
        dimensions: WindowPreviewHoverContainer.WindowDimensions,
        dockPosition: DockPosition,
        windowSwitcherActive: Bool
    ) -> some View {
        modifier(DynamicWindowFrameModifier(
            allowDynamicSizing: allowDynamicSizing,
            dimensions: dimensions,
            dockPosition: dockPosition,
            windowSwitcherActive: windowSwitcherActive
        ))
    }
}
