import Cocoa

// Holds logic related to precomputing image thumbnail sizes
extension WindowPreviewHoverContainer {
    struct WindowDimensions {
        let size: CGSize
        let maxDimensions: CGSize
    }

    static func calculateOverallMaxDimensions(
        windows: [WindowInfo],
        dockPosition: DockPosition,
        isWindowSwitcherActive: Bool,
        isMockPreviewActive: Bool,
        sharedPanelWindowSize: CGSize
    ) -> CGPoint {
        let thickness = isMockPreviewActive ? 200 : sharedPanelWindowSize.height
        var maxWidth: CGFloat = 300 // Default/min
        var maxHeight: CGFloat = 300 // Default/min

        let orientationIsHorizontal = dockPosition == .bottom || isWindowSwitcherActive
        let maxAspectRatio: CGFloat = 1.5

        for window in windows {
            if let cgImage = window.image {
                let cgSize = CGSize(width: cgImage.width, height: cgImage.height)
                if orientationIsHorizontal {
                    let rawWidthBasedOnHeight = (cgSize.width * thickness) / cgSize.height
                    let widthBasedOnHeight = min(rawWidthBasedOnHeight, thickness * maxAspectRatio)
                    maxWidth = max(maxWidth, widthBasedOnHeight)
                    maxHeight = thickness
                } else {
                    let rawHeightBasedOnWidth = (cgSize.height * thickness) / cgSize.width
                    let heightBasedOnWidth = min(rawHeightBasedOnWidth, thickness * maxAspectRatio)
                    maxHeight = max(maxHeight, heightBasedOnWidth)
                    maxWidth = thickness
                }
            }
        }
        return CGPoint(x: max(1, maxWidth), y: max(1, maxHeight)) // Ensure positive dimensions
    }

    static func precomputeWindowDimensions(
        windows: [WindowInfo],
        overallMaxDimensions: CGPoint,
        bestGuessMonitor: NSScreen
    ) -> [Int: WindowDimensions] {
        var dimensionsMap: [Int: WindowDimensions] = [:]

        let maxAllowedWidth = overallMaxDimensions.x
        let maxAllowedHeight = overallMaxDimensions.y

        let cardMaxFrameDimensions = CGSize(
            width: bestGuessMonitor.frame.width * 0.75,
            height: bestGuessMonitor.frame.height * 0.75
        )

        for (index, windowInfo) in windows.enumerated() {
            guard let cgImage = windowInfo.image else {
                dimensionsMap[index] = WindowDimensions(size: .zero, maxDimensions: cardMaxFrameDimensions)
                continue
            }

            let cgSize = CGSize(width: cgImage.width, height: cgImage.height)
            // Avoid division by zero if height is 0
            let aspectRatio = cgSize.height > 0 ? cgSize.width / cgSize.height : 1.0

            var targetWidth: CGFloat
            var targetHeight: CGFloat

            // This logic determines how each individual preview image is scaled *within* the bounds
            // defined by overallMaxDimensions.
            // If overallMaxDimensions.x is the width for horizontal items, use that.
            // If overallMaxDimensions.y is the height for horizontal items, use that.

            // If the overall container's orientation is horizontal (dock bottom or switcher mode),
            // then 'overallMaxDimensions.y' (which is 'thickness') dictates the height of each preview,
            // and 'overallMaxDimensions.x' is the max width *one* preview can take if it's very wide.
            // The 'precomputeWindowDimensions' in the previous version used 'maxWindowDimension.x' and 'maxWindowDimension.y'
            // where maxWindowDimension itself was already adjusted for orientation (one side was 'thickness').

            targetWidth = maxAllowedWidth
            targetHeight = targetWidth / aspectRatio

            if targetHeight > maxAllowedHeight {
                targetHeight = maxAllowedHeight
                targetWidth = aspectRatio * targetHeight
            }

            if targetWidth > maxAllowedWidth {
                targetWidth = maxAllowedWidth
                targetHeight = targetWidth / (aspectRatio > 0 ? aspectRatio : 1.0)
            }

            dimensionsMap[index] = WindowDimensions(
                size: CGSize(width: max(1, targetWidth), height: max(1, targetHeight)), // Ensure positive
                maxDimensions: cardMaxFrameDimensions
            )
        }
        return dimensionsMap
    }

    // Helper method to get dimensions for a specific window
    func getDimensions(for index: Int, dimensionsMap: [Int: WindowDimensions]) -> WindowDimensions {
        guard index >= 0, index < previewStateCoordinator.windows.count else {
            return WindowDimensions(
                size: CGSize(width: 100, height: 100),
                maxDimensions: CGSize(
                    width: bestGuessMonitor.frame.width * 0.75,
                    height: bestGuessMonitor.frame.height * 0.75
                )
            )
        }

        return dimensionsMap[index] ?? WindowDimensions(
            size: CGSize(width: 100, height: 100),
            maxDimensions: CGSize(
                width: bestGuessMonitor.frame.width * 0.75,
                height: bestGuessMonitor.frame.height * 0.75
            )
        )
    }
}
