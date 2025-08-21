import SwiftUI

struct DynamicWindowFrameModifier: ViewModifier {
    let allowDynamicSizing: Bool
    let dimensions: WindowPreviewHoverContainer.WindowDimensions
    let dockPosition: DockPosition
    let windowSwitcherActive: Bool

    func body(content: Content) -> some View {
        if allowDynamicSizing {
            // Dynamic sizing: use calculated dimensions with scaledToFit for natural scaling
            let isHorizontalFlow = dockPosition.isHorizontalFlow || windowSwitcherActive

            if isHorizontalFlow {
                // Horizontal flow: fixed height, let width scale naturally
                content
                    .frame(height: dimensions.size.height > 0 ? dimensions.size.height : nil)
                    .scaledToFit()
                    .frame(maxWidth: dimensions.maxDimensions.width,
                           maxHeight: dimensions.maxDimensions.height)
                    .clipped(antialiased: true)
            } else {
                // Vertical flow: fixed width, let height scale naturally
                content
                    .frame(width: dimensions.size.width > 0 ? dimensions.size.width : nil)
                    .scaledToFit()
                    .frame(maxWidth: dimensions.maxDimensions.width,
                           maxHeight: dimensions.maxDimensions.height)
                    .clipped(antialiased: true)
            }
        } else {
            // Fixed sizing: use the computed dimensions exactly
            content
                .frame(width: max(dimensions.size.width, 50),
                       height: dimensions.size.height,
                       alignment: .center)
                .frame(maxWidth: dimensions.maxDimensions.width,
                       maxHeight: dimensions.maxDimensions.height)
                .aspectRatio(dimensions.size.width / dimensions.size.height, contentMode: .fit)
                .clipped(antialiased: true)
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
