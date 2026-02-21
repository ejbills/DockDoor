import Cocoa
import Defaults

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
        if Defaults[.allowDynamicImageSizing] {
            // Use the old dynamic sizing logic based on actual window aspect ratios
            let thickness = isMockPreviewActive ? 200 : sharedPanelWindowSize.height
            var maxWidth: CGFloat = 300 // Default/min
            var maxHeight: CGFloat = 300 // Default/min

            let orientationIsHorizontal = isWindowSwitcherActive || (dockPosition == .bottom || dockPosition == .cmdTab)
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
        } else {
            // Use fixed sizing from user settings
            let width = Defaults[.previewWidth]
            let height = Defaults[.previewHeight]
            return CGPoint(x: width, y: height)
        }
    }

    static func precomputeWindowDimensions(
        windows: [WindowInfo],
        overallMaxDimensions: CGPoint,
        bestGuessMonitor: NSScreen,
        dockPosition: DockPosition,
        isWindowSwitcherActive: Bool
    ) -> [Int: WindowDimensions] {
        var dimensionsMap: [Int: WindowDimensions] = [:]

        if Defaults[.allowDynamicImageSizing] {
            let orientationIsHorizontal = isWindowSwitcherActive || (dockPosition == .bottom || dockPosition == .cmdTab)
            let maxDims = CGSize(width: overallMaxDimensions.x, height: overallMaxDimensions.y)

            for (index, window) in windows.enumerated() {
                if window.image != nil {
                    let windowSize = if orientationIsHorizontal {
                        CGSize(width: 0, height: max(overallMaxDimensions.y, 50))
                    } else {
                        CGSize(width: max(overallMaxDimensions.x, 50), height: 0)
                    }
                    dimensionsMap[index] = WindowDimensions(size: windowSize, maxDimensions: maxDims)
                } else {
                    let fallbackSize = CGSize(width: min(300, overallMaxDimensions.x),
                                              height: min(300, overallMaxDimensions.y))
                    dimensionsMap[index] = WindowDimensions(size: fallbackSize, maxDimensions: maxDims)
                }
            }
        } else {
            let width = Defaults[.previewWidth]
            let height = Defaults[.previewHeight]
            let fixedBoxSize = CGSize(width: width, height: height)
            let maxDims = CGSize(width: width, height: height)

            for (index, _) in windows.enumerated() {
                dimensionsMap[index] = WindowDimensions(size: fixedBoxSize, maxDimensions: maxDims)
            }
        }
        return dimensionsMap
    }

    static func calculateSingleWindowDimensions(
        windowInfo: WindowInfo,
        overallMaxDimensions: CGPoint,
        bestGuessMonitor: NSScreen
    ) -> WindowDimensions {
        let width = Defaults[.previewWidth]
        let height = Defaults[.previewHeight]
        let maxDims = CGSize(width: overallMaxDimensions.x, height: overallMaxDimensions.y)
        return WindowDimensions(size: CGSize(width: width, height: height), maxDimensions: maxDims)
    }

    func getDimensions(for index: Int, dimensionsMap: [Int: WindowDimensions]) -> WindowDimensions {
        let fallback = WindowDimensions(
            size: CGSize(width: 100, height: 100),
            maxDimensions: CGSize(width: 100, height: 100)
        )
        guard index >= 0, index < previewStateCoordinator.windows.count else {
            return fallback
        }
        return dimensionsMap[index] ?? fallback
    }
}
